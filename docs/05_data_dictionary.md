# Data Dictionary & Metrics Glossary

This document defines every table, column, and measure in the model, so anyone
reading a chart knows exactly what a number means and how it was calculated.

---

## Part 1 — Tables and columns

The model is a star schema: one fact table at order-line grain, surrounded by six
dimension tables. All personally identifiable information (customer name, email,
password, street) was removed during ETL and is not present in any table.

### fact_order_items
One row per order line item. This is the finest grain in the data, so any metric
can be rolled up to order, customer, product, category, or date.

| Column | Meaning | Additive? |
|---|---|---|
| order_item_id | Primary key. One order line. | key |
| order_id | Link to dim_order. | key |
| customer_id | Link to dim_customer. | key |
| product_card_id | Link to dim_product. | key |
| category_id | Link to dim_category. | key |
| department_id | Link to dim_department. | key |
| order_date_key | Link to dim_date (order date). Active relationship. | key |
| shipping_date_key | Link to dim_date (ship date). Inactive relationship. | key |
| payment_type | Payment method: Debit, Transfer, Cash, Payment. | attribute |
| shipping_mode | Standard, Second, First Class, or Same Day. | attribute |
| delivery_status | Late delivery, Advance shipping, On time, Cancelled. | attribute |
| days_shipping_real | Actual days taken to ship. | **average only** |
| days_shipping_scheduled | Promised days to ship. | **average only** |
| late_delivery_risk | 1 if the line was flagged late, else 0. | **average only** |
| order_item_quantity | Units on the line. | additive |
| order_item_product_price | Unit price. | average only |
| order_item_discount | Discount amount in dollars. | additive |
| order_item_discount_rate | Discount as a fraction of price (0–0.25). | **average only** |
| sales | Line sales value. | additive |
| order_item_total | Line total after discount. | additive |
| order_item_profit_ratio | Profit as a fraction of the line. | **average only** |
| order_item_profit | Line profit in dollars. | additive |
| store_latitude / store_longitude | Store origin coordinates. | attribute |

### dim_order
One row per order. Holds destination geography, market, order status, order date.

| Column | Meaning |
|---|---|
| order_id | Primary key. |
| order_city / order_state / order_country / order_region | Destination geography. |
| market | Global market: Europe, LATAM, Pacific Asia, USCA, Africa. |
| order_status | Pipeline state: Complete, Pending Payment, Processing, etc. |
| order_date / order_date_key | Order date and its link to dim_date. |

### dim_customer
One row per customer. PII removed.

| Column | Meaning |
|---|---|
| customer_id | Primary key. |
| customer_segment | Consumer, Corporate, or Home Office. |
| customer_city / customer_state / customer_country | Customer location. |
| customer_zipcode | Postal code (-1 = unknown). |

### dim_product
| Column | Meaning |
|---|---|
| product_card_id | Primary key. |
| product_name | Product name. |
| product_price | List price. |
| product_status | Availability flag. |
| category_id | Link to dim_category. |

### dim_category / dim_department
Lookup tables turning an id into a readable name.

| Column | Meaning |
|---|---|
| category_id / department_id | Primary key. |
| category_name / department_name | Readable name. |

### dim_date
One row per calendar day, covering order and shipping dates. Marked as the
model's date table.

| Column | Meaning |
|---|---|
| date_key | Primary key (yyyymmdd). |
| full_date | The date. |
| year / quarter / month / month_name / day / day_of_week | Calendar parts. |
| is_weekend | True for Saturday and Sunday. |

---

## Part 2 — Measures (DAX)

Every measure lives in a dedicated `_Measures` table. Percentages are stored as
fractions and formatted for display.

| Measure | Definition (plain English) |
|---|---|
| Total Order Lines | Count of order lines. |
| Total Orders | Distinct count of orders. |
| Total Sales | Sum of line sales. |
| Total Profit | Sum of line profit. |
| Net Margin % | Total Profit / Total Sales. |
| Avg Profit per Line | Total Profit / Total Order Lines. |
| Late Deliveries | Count of lines with status "Late delivery". |
| Late Delivery Rate % | Late Deliveries / Total Order Lines. |
| On-Time Delivery Rate % | 1 − Late Delivery Rate %. |
| Avg Promised Days | Average of scheduled shipping days. |
| Avg Actual Days | Average of real shipping days. |
| Delivery Gap (Days) | Avg Actual − Avg Promised. Positive = slower than promised. |
| Revenue at Risk | Sales sitting on late-delivery orders. |
| Total Discount Given | Sum of line discounts. |
| Fraud Orders | Orders flagged "Suspected Fraud" (blank forced to 0). |
| Fraud Rate % | Fraud Orders / Total Orders. |
| Unsettled Order Value | Sales in pending, pending-payment, processing, on-hold, or payment-review states. |
| Lines at Loss | Count of lines with negative profit. |
| % Lines at Loss | Lines at Loss / Total Order Lines. |
| Avg Order Value | Total Sales / Total Orders. |

---

## Part 3 — Additivity rules (why this matters)

A number is only meaningful if it is aggregated correctly.

- **Additive** measures (sales, profit, quantity, discount) can be summed across
  any dimension.
- **Non-additive** measures must never be summed. Rates and ratios
  (late_delivery_risk, discount_rate, profit_ratio) are averaged. A 0/1 flag like
  late_delivery_risk averages to a rate: AVG = the late-delivery rate.
- Order-level and customer-level values were checked during ETL to confirm they
  vary at line grain before being used as additive measures.

Getting this wrong is the most common error in a dashboard. Summing a ratio, or
summing an order-level value repeated across its lines, produces numbers that look
plausible and are completely wrong.
