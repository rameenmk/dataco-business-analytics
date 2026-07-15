# Phase 3 - Power BI Dashboard

This is the build guide. It covers how to load the model, how to wire the
relationships, the measures to create, and the visuals to place. I cannot click
inside Power BI for you, so follow these steps and you will end up with the
dashboard shown in the layout mockup.

## 1. Load the data

Get Data > Text/CSV, and load all seven files from `data/processed`:
`dim_date`, `dim_category`, `dim_department`, `dim_customer`, `dim_product`,
`dim_order`, `fact_order_items`.

The files are UTF-8, so there is no encoding step. The ETL already handled that.

Check these data types after load:
- `dim_date[date_key]`, all the `_id` and `_key` columns: Whole Number.
- `dim_date[full_date]`, `dim_order[order_date]`: Date/Time.
- money columns (`sales`, `order_item_profit`, `order_item_total`, prices): Decimal.
- `late_delivery_risk`, `days_shipping_real`, `days_shipping_scheduled`: Whole Number.

Then mark `dim_date` as a date table: Table tools > Mark as Date Table, using
`full_date`.

## 2. Build the relationships (Model view)

Create these, all one-to-many from dimension to fact, single direction:

| From (dimension) | To (fact) | Active? |
|---|---|---|
| `dim_order[order_id]` | `fact_order_items[order_id]` | yes |
| `dim_customer[customer_id]` | `fact_order_items[customer_id]` | yes |
| `dim_product[product_card_id]` | `fact_order_items[product_card_id]` | yes |
| `dim_category[category_id]` | `fact_order_items[category_id]` | yes |
| `dim_department[department_id]` | `fact_order_items[department_id]` | yes |
| `dim_date[date_key]` | `fact_order_items[order_date_key]` | yes |
| `dim_date[date_key]` | `fact_order_items[shipping_date_key]` | no (inactive) |

Two things to know, because an interviewer may ask:
- Keep this a clean star. Do not also link `dim_product` to `dim_category`. The
  fact already joins to `dim_category` directly, so a second path would make the
  model ambiguous.
- `dim_date` connects to the fact twice (order date and shipping date). Power BI
  only allows one active link between two tables, so order date is active and
  shipping date is inactive. The `Late Deliveries (by ship date)` measure uses
  `USERELATIONSHIP` to switch to the shipping-date link when you need it. This is
  called a role-playing dimension.

## 3. Create the measures

Add an empty table called `_Measures` (Home > Enter Data, leave it blank, load it),
then paste in the measures from `powerbi/measures.dax` one at a time. Keeping every
measure in one table is a small thing that makes the model look organised.

## 4. Metrics dictionary

Define each number once, clearly, so the dashboard cannot be misread. This table is
worth putting in your README too.

| Metric | Definition |
|---|---|
| Total Sales | Sum of line-level sales. |
| Total Profit | Sum of line-level profit (`order_item_profit`). |
| Net Margin % | Total Profit divided by Total Sales. |
| Late Delivery Rate % | Share of order lines with delivery status "Late delivery". |
| On-Time Delivery Rate % | 1 minus the late delivery rate. |
| Avg Promised Days | Average of the scheduled shipping days. |
| Avg Actual Days | Average of the real shipping days. |
| Delivery Gap (Days) | Actual days minus promised days. Positive means slower than promised. |
| Revenue at Risk | Sales that sit on orders flagged as late delivery. |
| % Lines at Loss | Share of order lines where profit is below zero. |
| Avg Profit per Line | Total Profit divided by the number of order lines. |

## 5. Visuals to place (Page 1)

Match the mockup layout.

Top row, six KPI cards:
On-Time Delivery Rate %, Total Sales, Total Profit, Net Margin %, Revenue at Risk,
% Lines at Loss.

Main area:
1. Hero, clustered bar chart: Late Delivery Rate % by `shipping_mode`. This is the
   most important visual. Add `Avg Promised Days` and `Avg Actual Days` as a small
   second visual or tooltip so the promise-versus-reality gap is visible.
2. Line chart: Late Delivery Rate % by month, using `dim_date`. Shows the flat trend.
3. Bar chart: Revenue at Risk by `customer_segment`.
4. Column chart: Avg Profit per Line across discount bands. You will need a small
   calculated column on the fact for the band, or bucket `order_item_discount_rate`
   in the visual.

Slicers (down one side): `dim_date[year]`, `dim_order[market]`,
`dim_customer[customer_segment]`, `fact_order_items[shipping_mode]`,
`dim_category[category_name]`.

Optional Page 2: a map using `dim_order[market]` or `order_country` for late rate by
geography, plus a category-level matrix.

## 6. Formatting

- Title the page something plain like "Delivery reliability and profit".
- Format the late-rate visuals so high numbers read as a problem (a red-to-amber
  scale), and keep everything else neutral.
- Percentages to one decimal, money with a thousands separator.
- Add one short text box near the hero chart stating the finding in a sentence:
  premium shipping tiers miss their promised delivery windows most of the time.

## 7. Publish

Export a PNG of the finished page for the README. If you have a Power BI account,
publish to the Power BI Service and grab the link. If you want a link anyone can
open without an account, rebuild the same visuals in Tableau Public, which is free
and gives a public URL. We will add whichever link you get to the README in the
final phase.
