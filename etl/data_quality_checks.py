"""
Data Quality Checks — DataCo Supply Chain
-----------------------------------------
Validates the modeled star schema. Run after the ETL to confirm the warehouse
is sound before any analysis or dashboard work.

    python etl/data_quality_checks.py

Exit code 0 = all checks passed. Non-zero = at least one check failed.
"""
from pathlib import Path
import sys
import pandas as pd

DATA = Path("data/processed")

PK = {
    "dim_date": "date_key",
    "dim_category": "category_id",
    "dim_department": "department_id",
    "dim_customer": "customer_id",
    "dim_product": "product_card_id",
    "dim_order": "order_id",
    "fact_order_items": "order_item_id",
}

# fact foreign key -> (dimension table, dimension key)
FK = [
    ("customer_id", "dim_customer", "customer_id"),
    ("product_card_id", "dim_product", "product_card_id"),
    ("category_id", "dim_category", "category_id"),
    ("department_id", "dim_department", "department_id"),
    ("order_id", "dim_order", "order_id"),
    ("order_date_key", "dim_date", "date_key"),
    ("shipping_date_key", "dim_date", "date_key"),
]

PII_FORBIDDEN = ["customer_email", "customer_password", "customer_fname",
                 "customer_lname", "customer_street"]


def load(name):
    return pd.read_csv(DATA / f"{name}.csv")


def main():
    tables = {name: load(name) for name in PK}
    fact = tables["fact_order_items"]
    failures = []

    print("=== Data Quality Checks ===\n")

    # 1. primary key uniqueness
    print("[1] Primary key uniqueness")
    for name, key in PK.items():
        dups = tables[name][key].duplicated().sum()
        ok = dups == 0
        print(f"    {name:20s} {key:16s} dups={dups:<4} {'PASS' if ok else 'FAIL'}")
        if not ok:
            failures.append(f"{name}.{key} has {dups} duplicate keys")

    # 2. referential integrity
    print("\n[2] Referential integrity (fact -> dimension)")
    for fk, dim, dk in FK:
        orphans = (~fact[fk].isin(tables[dim][dk])).sum()
        ok = orphans == 0
        print(f"    fact.{fk:18s} -> {dim:14s} orphans={orphans:<4} {'PASS' if ok else 'FAIL'}")
        if not ok:
            failures.append(f"fact.{fk} has {orphans} orphan keys against {dim}")

    # 3. no PII leaked into the warehouse
    print("\n[3] PII removal")
    leaked = [c for t in tables.values() for c in t.columns if c in PII_FORBIDDEN]
    ok = len(leaked) == 0
    print(f"    forbidden PII columns found: {leaked if leaked else 'none'}  {'PASS' if ok else 'FAIL'}")
    if not ok:
        failures.append(f"PII columns present: {leaked}")

    # 4. no negative sales or quantities
    print("\n[4] Value sanity")
    neg_sales = (fact["sales"] < 0).sum()
    neg_qty = (fact["order_item_quantity"] < 0).sum()
    ok = neg_sales == 0 and neg_qty == 0
    print(f"    negative sales={neg_sales}, negative qty={neg_qty}  {'PASS' if ok else 'FAIL'}")
    if not ok:
        failures.append("negative sales or quantity present")

    # 5. rate columns within [0,1]
    print("\n[5] Rate bounds")
    bad_rate = ((fact["order_item_discount_rate"] < 0) |
                (fact["order_item_discount_rate"] > 1)).sum()
    ok = bad_rate == 0
    print(f"    discount_rate outside [0,1]: {bad_rate}  {'PASS' if ok else 'FAIL'}")
    if not ok:
        failures.append("discount_rate outside [0,1]")

    # summary
    print("\n=== Result ===")
    if failures:
        print(f"FAILED — {len(failures)} issue(s):")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print("All checks passed.")
    sys.exit(0)


if __name__ == "__main__":
    main()
