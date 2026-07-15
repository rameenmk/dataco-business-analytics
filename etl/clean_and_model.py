"""
DataCo Supply Chain - ETL & Dimensional Modeling
------------------------------------------------
Reads the raw DataCo export (Latin-1), cleans it, strips PII, and models it
into a star schema (1 fact + 6 dimensions) written as analysis-ready CSVs.

Run:  python etl/clean_and_model.py
"""
from pathlib import Path
import re
import pandas as pd

RAW = Path("/mnt/user-data/uploads/DataCoSupplyChainDataset.csv")
OUT = Path("data/processed"); OUT.mkdir(parents=True, exist_ok=True)

PII_DROP  = ["Customer Email", "Customer Fname", "Customer Lname",
             "Customer Password", "Customer Street"]
DEAD_DROP = ["Product Description",   # 100% null
             "Order Zipcode",         # 86% null
             "Product Image"]         # url, no analytic value
DUP_DROP  = ["Benefit per order",     # == Order Profit Per Order
             "Product Category Id",   # == Category Id
             "Order Customer Id"]     # == Customer Id


def snake(c):
    c = c.strip()
    c = c.replace("(DateOrders)", "").replace("(real)", "real").replace("(scheduled)", "scheduled")
    c = re.sub(r"[^0-9a-zA-Z]+", "_", c).strip("_").lower()
    return c


def date_key(s):  # yyyymmdd int
    return s.dt.year * 10000 + s.dt.month * 100 + s.dt.day


def main():
    df = pd.read_csv(RAW, encoding="latin-1")
    n0 = len(df)

    # sanity: is 'Sales per customer' just a line-level duplicate of 'Sales'?
    spc_is_sales = (df["Sales per customer"].round(2) == df["Sales"].round(2)).mean()
    print(f"[probe] 'Sales per customer' equals line 'Sales' in {spc_is_sales:.1%} of rows")
    if spc_is_sales > 0.99:
        DUP_DROP.append("Sales per customer")

    df = df.drop(columns=[c for c in PII_DROP + DEAD_DROP + DUP_DROP if c in df.columns])
    df.columns = [snake(c) for c in df.columns]

    # parse dates + build integer date keys
    df["order_date"]        = pd.to_datetime(df["order_date"], errors="coerce")
    df["shipping_date"]     = pd.to_datetime(df["shipping_date"], errors="coerce")
    df["order_date_key"]    = date_key(df["order_date"])
    df["shipping_date_key"] = date_key(df["shipping_date"])

    # trivial null fixes
    df["customer_zipcode"] = df["customer_zipcode"].fillna(-1).astype("int64")

    # ---- DIMENSIONS ----
    dim_category = (df[["category_id", "category_name"]]
                    .drop_duplicates().sort_values("category_id"))

    dim_department = (df[["department_id", "department_name"]]
                      .drop_duplicates().sort_values("department_id"))

    dim_customer = (df[["customer_id", "customer_segment", "customer_city",
                        "customer_state", "customer_country", "customer_zipcode"]]
                    .drop_duplicates("customer_id").sort_values("customer_id"))

    dim_product = (df[["product_card_id", "product_name", "product_price",
                       "product_status", "category_id"]]
                   .drop_duplicates("product_card_id").sort_values("product_card_id"))

    dim_order = (df[["order_id", "order_city", "order_state", "order_country",
                     "order_region", "market", "order_status", "order_date", "order_date_key"]]
                 .drop_duplicates("order_id").sort_values("order_id"))

    # date dimension from the union of order + shipping dates
    dser = pd.concat([df["order_date"], df["shipping_date"]]).dropna().dt.normalize().drop_duplicates()
    dim_date = pd.DataFrame({"full_date": sorted(dser)})
    dim_date["date_key"]    = date_key(dim_date["full_date"])
    dim_date["year"]        = dim_date["full_date"].dt.year
    dim_date["quarter"]     = dim_date["full_date"].dt.quarter
    dim_date["month"]       = dim_date["full_date"].dt.month
    dim_date["month_name"]  = dim_date["full_date"].dt.strftime("%B")
    dim_date["day"]         = dim_date["full_date"].dt.day
    dim_date["day_of_week"] = dim_date["full_date"].dt.strftime("%A")
    dim_date["is_weekend"]  = dim_date["full_date"].dt.dayofweek.isin([5, 6])
    dim_date = dim_date[["date_key", "full_date", "year", "quarter", "month",
                         "month_name", "day", "day_of_week", "is_weekend"]]

    # ---- FACT (grain = one order line item) ----
    fact = df[[
        "order_item_id", "order_id", "customer_id", "product_card_id", "category_id",
        "department_id", "order_date_key", "shipping_date_key", "type", "shipping_mode",
        "delivery_status", "days_for_shipping_real", "days_for_shipment_scheduled",
        "late_delivery_risk", "order_item_quantity", "order_item_product_price",
        "order_item_discount", "order_item_discount_rate", "sales", "order_item_total",
        "order_item_profit_ratio", "order_profit_per_order", "latitude", "longitude"
    ]].rename(columns={
        "type": "payment_type",
        "days_for_shipping_real": "days_shipping_real",
        "days_for_shipment_scheduled": "days_shipping_scheduled",
        "order_profit_per_order": "order_item_profit",   # rename to its TRUE meaning
        "latitude": "store_latitude", "longitude": "store_longitude",
    })

    tables = {"dim_date": dim_date, "dim_category": dim_category, "dim_department": dim_department,
              "dim_customer": dim_customer, "dim_product": dim_product, "dim_order": dim_order,
              "fact_order_items": fact}
    for name, t in tables.items():
        t.to_csv(OUT / f"{name}.csv", index=False)

    # ---- VALIDATION ----
    print(f"\n[etl] raw rows: {n0:,}  ->  fact rows: {len(fact):,}")
    print("\n[row counts]")
    for name, t in tables.items():
        print(f"  {name:20s} {len(t):>8,} rows  x {t.shape[1]} cols")

    print("\n[primary-key uniqueness]")
    pk = {"dim_date": "date_key", "dim_category": "category_id", "dim_department": "department_id",
          "dim_customer": "customer_id", "dim_product": "product_card_id", "dim_order": "order_id",
          "fact_order_items": "order_item_id"}
    for name, key in pk.items():
        dup = tables[name][key].duplicated().sum()
        print(f"  {name:20s} PK={key:16s} dups={dup}  {'OK' if dup == 0 else 'FAIL'}")

    print("\n[referential integrity - every fact FK exists in its dimension]")
    checks = [("customer_id", dim_customer, "customer_id"),
              ("product_card_id", dim_product, "product_card_id"),
              ("category_id", dim_category, "category_id"),
              ("department_id", dim_department, "department_id"),
              ("order_id", dim_order, "order_id"),
              ("order_date_key", dim_date, "date_key"),
              ("shipping_date_key", dim_date, "date_key")]
    for fk, dim, dk in checks:
        orphans = (~fact[fk].isin(dim[dk])).sum()
        print(f"  fact.{fk:18s} -> {dk:14s} orphans={orphans}  {'OK' if orphans == 0 else 'FAIL'}")

    print("\n[grain / additivity demo]")
    late = fact["late_delivery_risk"].mean()
    print(f"  late_delivery_risk is 0/1 -> AVG = late-delivery rate = {late:.1%} (never SUM it)")
    print(f"  additive: SUM(sales) = ${fact['sales'].sum():,.0f} | "
          f"SUM(order_item_profit) = ${fact['order_item_profit'].sum():,.0f}")


if __name__ == "__main__":
    main()
