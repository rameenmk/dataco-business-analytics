-- =====================================================================
-- DataCo Supply Chain - Phase 2 Analysis
-- Six business questions on delivery reliability and profitability.
-- Written for PostgreSQL. Runs on the star schema from Phase 1.
-- =====================================================================


-- Q1. How reliable is delivery overall?
-- Cross-check three independent signals so we trust the number.
SELECT
    ROUND(AVG(late_delivery_risk) * 100, 1)                                                   AS risk_flag_pct,
    ROUND(AVG(CASE WHEN delivery_status = 'Late delivery' THEN 1 ELSE 0 END) * 100, 1)        AS status_late_pct,
    ROUND(AVG(CASE WHEN days_shipping_real > days_shipping_scheduled THEN 1 ELSE 0 END) * 100, 1) AS actual_over_promise_pct
FROM fact_order_items;


-- Q2. What drives the lateness? Break it down by shipping mode.
-- This is the root-cause query: compare what was promised vs what happened.
SELECT
    shipping_mode,
    COUNT(*)                                                                             AS lines,
    ROUND(AVG(days_shipping_scheduled), 1)                                               AS promised_days,
    ROUND(AVG(days_shipping_real), 1)                                                    AS actual_days,
    ROUND(AVG(CASE WHEN delivery_status = 'Late delivery' THEN 1 ELSE 0 END) * 100, 1)   AS late_pct
FROM fact_order_items
GROUP BY shipping_mode
ORDER BY late_pct DESC;


-- Q3. Is delivery reliability improving over time?
-- Monthly late rate with the prior month and the change (window function).
WITH monthly AS (
    SELECT
        d.year,
        d.month,
        AVG(CASE WHEN f.delivery_status = 'Late delivery' THEN 1 ELSE 0 END) * 100 AS late_pct
    FROM fact_order_items f
    JOIN dim_order o ON f.order_id = o.order_id
    JOIN dim_date  d ON o.order_date_key = d.date_key
    GROUP BY d.year, d.month
)
SELECT
    year,
    month,
    ROUND(late_pct, 1)                                              AS late_pct,
    ROUND(LAG(late_pct) OVER (ORDER BY year, month), 1)             AS prev_month_late_pct,
    ROUND(late_pct - LAG(late_pct) OVER (ORDER BY year, month), 1)  AS change_pts
FROM monthly
ORDER BY year, month;


-- Q4. How much revenue is exposed to late delivery, by customer segment?
-- Puts a dollar figure on the problem.
SELECT
    c.customer_segment,
    ROUND(SUM(f.sales), 0)                                                              AS total_sales,
    ROUND(SUM(CASE WHEN f.delivery_status = 'Late delivery' THEN f.sales ELSE 0 END), 0) AS sales_on_late_orders,
    ROUND(AVG(CASE WHEN f.delivery_status = 'Late delivery' THEN 1 ELSE 0 END) * 100, 1) AS late_pct
FROM fact_order_items f
JOIN dim_customer c ON f.customer_id = c.customer_id
GROUP BY c.customer_segment
ORDER BY total_sales DESC;


-- Q5. Is the business profitable, and are losses concentrated in a few products?
-- First the headline margin and loss rate, then a check at product grain.
SELECT
    ROUND(SUM(sales), 0)                                                    AS total_sales,
    ROUND(SUM(order_item_profit), 0)                                        AS total_profit,
    ROUND(SUM(order_item_profit) / SUM(sales) * 100, 1)                     AS net_margin_pct,
    ROUND(AVG(CASE WHEN order_item_profit < 0 THEN 1 ELSE 0 END) * 100, 1)  AS pct_lines_at_loss
FROM fact_order_items;

SELECT
    COUNT(*) FILTER (WHERE product_profit < 0) AS loss_making_products,
    COUNT(*)                                   AS total_products
FROM (
    SELECT product_card_id, SUM(order_item_profit) AS product_profit
    FROM fact_order_items
    GROUP BY product_card_id
) p;


-- Q6. Does discounting erode profit?
-- Average profit per line and loss rate across discount bands.
SELECT
    CASE
        WHEN order_item_discount_rate = 0    THEN '0%'
        WHEN order_item_discount_rate <= 0.10 THEN '1-10%'
        WHEN order_item_discount_rate <= 0.20 THEN '11-20%'
        ELSE '21-25%'
    END                                                                     AS discount_band,
    COUNT(*)                                                                AS lines,
    ROUND(AVG(order_item_profit), 2)                                        AS avg_profit_per_line,
    ROUND(AVG(CASE WHEN order_item_profit < 0 THEN 1 ELSE 0 END) * 100, 1)  AS pct_lines_at_loss
FROM fact_order_items
GROUP BY discount_band
ORDER BY discount_band;
