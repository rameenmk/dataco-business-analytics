# Phase 1 — Data Model & ETL

## Source
DataCo Global supply-chain export: **180,519 rows × 53 columns**, Latin-1 encoded,
covering **Jan 2015 – Jan 2018**. One raw row = one order line item.

## Star schema
Grain of the fact table is **one order line item** (finest grain available), so any
metric can be rolled up to order, customer, product, or date without losing detail.

```
                 dim_date
                    |
 dim_customer --- fact_order_items --- dim_product --- dim_category
                 /     |      \
        dim_order  dim_department  (dim_date via shipping_date_key)
```

| Table | Grain / PK | Rows |
|-------|------------|------|
| `fact_order_items` | order line item (`order_item_id`) | 180,519 |
| `dim_order` | order (`order_id`) | 65,752 |
| `dim_customer` | customer (`customer_id`) | 20,652 |
| `dim_product` | product (`product_card_id`) | 118 |
| `dim_category` | category (`category_id`) | 51 |
| `dim_department` | department (`department_id`) | 11 |
| `dim_date` | calendar day (`date_key`) | 1,133 |

## Cleaning decisions (and why)
- **Encoding:** read as Latin-1 — the file is *not* UTF-8 and fails a naive load.
- **PII removed:** `Customer Email`, `Customer Password`, `Customer Fname/Lname`,
  `Customer Street` dropped in ETL. PII never reaches the repo or the warehouse.
- **Dead columns dropped:** `Product Description` (100% null), `Order Zipcode`
  (86% null), `Product Image` (URL only).
- **Duplicate columns dropped:** `Product Category Id` (= `Category Id`),
  `Order Customer Id` (= `Customer Id`), `Benefit per order` (= `Order Profit Per Order`).
- **Renames for honesty:** `Order Profit Per Order` was found to vary line-by-line,
  so it is the *line-level* profit → renamed `order_item_profit`.
- **Column names** standardized to `snake_case`.

## Additivity rules (documented so metrics can't be miscomputed)
- **Additive (safe to SUM):** `sales`, `order_item_total`, `order_item_quantity`,
  `order_item_discount`, `order_item_profit`.
- **Non-additive (AVG / weighted-avg only, never SUM):** `late_delivery_risk`
  (0/1 → AVG = late-delivery rate), `order_item_profit_ratio`,
  `order_item_discount_rate`, `days_shipping_real`, `days_shipping_scheduled`.

## Validation (all passing)
- Primary keys unique on all 7 tables (0 duplicates).
- Referential integrity: 0 orphan foreign keys across all 7 fact→dim relationships.
- Row conservation: 180,519 raw rows → 180,519 fact rows (no silent drops).

## Reproduce
```bash
python etl/clean_and_model.py          # raw CSV -> data/processed/*.csv (+ validation)
./warehouse/load_postgres.sh           # build the PostgreSQL warehouse
```
