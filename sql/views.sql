-- =====================================================================
-- DataCo Supply Chain - Reporting Views (PostgreSQL)
-- A reusable reporting layer on top of the star schema. Each view answers
-- one recurring business question, so dashboards and ad-hoc queries read
-- from a stable, named object instead of re-writing the logic each time.
--
-- Apply after loading the warehouse:  psql -d dataco -f sql/views.sql
-- =====================================================================


-- v_delivery_by_shipping_mode
-- Delivery reliability and the promise-vs-actual gap, per shipping mode.
CREATE OR REPLACE VIEW v_delivery_by_shipping_mode AS
SELECT
    shipping_mode,
    COUNT(*)                                                                            AS order_lines,
    ROUND(AVG(days_shipping_scheduled), 2)                                              AS avg_promised_days,
    ROUND(AVG(days_shipping_real), 2)                                                   AS avg_actual_days,
    ROUND(AVG(days_shipping_real - days_shipping_scheduled), 2)                         AS avg_delivery_gap_days,
    ROUND(AVG(CASE WHEN delivery_status = 'Late delivery' THEN 1 ELSE 0 END) * 100, 1)  AS late_rate_pct
FROM fact_order_items
GROUP BY shipping_mode;


-- v_monthly_delivery_trend
-- Late-delivery rate by month, for the trend line.
CREATE OR REPLACE VIEW v_monthly_delivery_trend AS
SELECT
    d.year,
    d.month,
    COUNT(*)                                                                              AS order_lines,
    ROUND(AVG(CASE WHEN f.delivery_status = 'Late delivery' THEN 1 ELSE 0 END) * 100, 1)  AS late_rate_pct,
    ROUND(SUM(f.sales), 0)                                                                 AS sales
FROM fact_order_items f
JOIN dim_order o ON f.order_id = o.order_id
JOIN dim_date  d ON o.order_date_key = d.date_key
GROUP BY d.year, d.month;


-- v_category_performance
-- Sales, profit, order value, and late rate per category.
CREATE OR REPLACE VIEW v_category_performance AS
SELECT
    c.category_name,
    ROUND(SUM(f.sales), 0)                                                                AS sales,
    ROUND(SUM(f.order_item_profit), 0)                                                    AS profit,
    ROUND(SUM(f.order_item_profit) / NULLIF(SUM(f.sales), 0) * 100, 1)                    AS net_margin_pct,
    ROUND(SUM(f.sales) / NULLIF(COUNT(DISTINCT f.order_id), 0), 0)                        AS avg_order_value,
    ROUND(AVG(CASE WHEN f.delivery_status = 'Late delivery' THEN 1 ELSE 0 END) * 100, 1)  AS late_rate_pct
FROM fact_order_items f
JOIN dim_category c ON f.category_id = c.category_id
GROUP BY c.category_name;


-- v_order_pipeline
-- Order value by status, with a settled / stuck / lost bucket. Powers the
-- unsettled-revenue finding.
CREATE OR REPLACE VIEW v_order_pipeline AS
SELECT
    o.order_status,
    CASE
        WHEN o.order_status IN ('COMPLETE', 'CLOSED')                                              THEN 'Settled'
        WHEN o.order_status IN ('PENDING', 'PENDING_PAYMENT', 'PROCESSING', 'ON_HOLD', 'PAYMENT_REVIEW') THEN 'Stuck in pipeline'
        ELSE 'Lost'
    END                                                                 AS pipeline_bucket,
    COUNT(DISTINCT o.order_id)                                          AS orders,
    ROUND(SUM(f.sales), 0)                                              AS order_value
FROM fact_order_items f
JOIN dim_order o ON f.order_id = o.order_id
GROUP BY o.order_status;


-- v_payment_fraud
-- Fraud-flag rate by payment method. Supports the finding that fraud flags
-- occur only on transfer orders.
CREATE OR REPLACE VIEW v_payment_fraud AS
SELECT
    f.payment_type,
    COUNT(DISTINCT o.order_id)                                                                     AS orders,
    COUNT(DISTINCT CASE WHEN o.order_status = 'SUSPECTED_FRAUD' THEN o.order_id END)               AS fraud_orders,
    ROUND(COUNT(DISTINCT CASE WHEN o.order_status = 'SUSPECTED_FRAUD' THEN o.order_id END) * 100.0
          / NULLIF(COUNT(DISTINCT o.order_id), 0), 2)                                              AS fraud_rate_pct
FROM fact_order_items f
JOIN dim_order o ON f.order_id = o.order_id
GROUP BY f.payment_type;


-- v_discount_impact
-- Average profit per line and loss rate across discount bands.
CREATE OR REPLACE VIEW v_discount_impact AS
SELECT
    CASE
        WHEN order_item_discount_rate = 0     THEN '0%'
        WHEN order_item_discount_rate <= 0.10 THEN '1-10%'
        WHEN order_item_discount_rate <= 0.20 THEN '11-20%'
        ELSE '21-25%'
    END                                                                     AS discount_band,
    COUNT(*)                                                                AS order_lines,
    ROUND(AVG(order_item_profit), 2)                                        AS avg_profit_per_line,
    ROUND(AVG(CASE WHEN order_item_profit < 0 THEN 1 ELSE 0 END) * 100, 1)  AS pct_lines_at_loss
FROM fact_order_items
GROUP BY 1;
