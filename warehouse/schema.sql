-- =====================================================================
-- DataCo Supply Chain Warehouse - PostgreSQL DDL
-- Star schema: 1 fact (order line grain) + 6 conformed dimensions
-- =====================================================================
DROP TABLE IF EXISTS fact_order_items CASCADE;
DROP TABLE IF EXISTS dim_order       CASCADE;
DROP TABLE IF EXISTS dim_product     CASCADE;
DROP TABLE IF EXISTS dim_customer    CASCADE;
DROP TABLE IF EXISTS dim_department  CASCADE;
DROP TABLE IF EXISTS dim_category    CASCADE;
DROP TABLE IF EXISTS dim_date        CASCADE;

-- ---------- DIMENSIONS ----------
CREATE TABLE dim_date (
    date_key     INTEGER      PRIMARY KEY,          -- yyyymmdd
    full_date    DATE         NOT NULL,
    year         SMALLINT     NOT NULL,
    quarter      SMALLINT     NOT NULL,
    month        SMALLINT     NOT NULL,
    month_name   VARCHAR(12)  NOT NULL,
    day          SMALLINT     NOT NULL,
    day_of_week  VARCHAR(10)  NOT NULL,
    is_weekend   BOOLEAN      NOT NULL
);

CREATE TABLE dim_category (
    category_id   INTEGER      PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL
);

CREATE TABLE dim_department (
    department_id   INTEGER      PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL
);

CREATE TABLE dim_customer (
    customer_id      INTEGER      PRIMARY KEY,
    customer_segment VARCHAR(30),
    customer_city    VARCHAR(100),
    customer_state   VARCHAR(30),
    customer_country VARCHAR(50),
    customer_zipcode INTEGER                          -- -1 = unknown
);

CREATE TABLE dim_product (
    product_card_id INTEGER        PRIMARY KEY,
    product_name    VARCHAR(200),
    product_price   NUMERIC(12,2),
    product_status  SMALLINT,
    category_id     INTEGER        REFERENCES dim_category(category_id)
);

CREATE TABLE dim_order (
    order_id       INTEGER      PRIMARY KEY,
    order_city     VARCHAR(100),
    order_state    VARCHAR(100),
    order_country  VARCHAR(100),
    order_region   VARCHAR(50),
    market         VARCHAR(30),
    order_status   VARCHAR(30),
    order_date     TIMESTAMP,
    order_date_key INTEGER      REFERENCES dim_date(date_key)
);

-- ---------- FACT (grain = one order line item) ----------
CREATE TABLE fact_order_items (
    order_item_id            INTEGER      PRIMARY KEY,
    -- foreign keys
    order_id                 INTEGER      REFERENCES dim_order(order_id),
    customer_id              INTEGER      REFERENCES dim_customer(customer_id),
    product_card_id          INTEGER      REFERENCES dim_product(product_card_id),
    category_id              INTEGER      REFERENCES dim_category(category_id),
    department_id            INTEGER      REFERENCES dim_department(department_id),
    order_date_key           INTEGER      REFERENCES dim_date(date_key),
    shipping_date_key        INTEGER      REFERENCES dim_date(date_key),
    -- degenerate / operational attributes
    payment_type             VARCHAR(20),
    shipping_mode            VARCHAR(30),
    delivery_status          VARCHAR(30),
    -- ADDITIVE measures (safe to SUM)
    order_item_quantity      INTEGER,
    order_item_product_price NUMERIC(12,2),
    order_item_discount      NUMERIC(12,2),
    sales                    NUMERIC(12,2),
    order_item_total         NUMERIC(12,2),
    order_item_profit        NUMERIC(12,2),          -- true line-level profit
    -- NON-ADDITIVE measures (AVG / weighted-avg only, never SUM)
    days_shipping_real       SMALLINT,
    days_shipping_scheduled  SMALLINT,
    late_delivery_risk       SMALLINT,               -- 0/1 -> AVG = late rate
    order_item_discount_rate NUMERIC(6,4),
    order_item_profit_ratio  NUMERIC(6,4),
    -- geo (store origin)
    store_latitude           NUMERIC(9,6),
    store_longitude          NUMERIC(9,6)
);

-- ---------- INDEXES on FK columns (star-join performance) ----------
CREATE INDEX idx_foi_order      ON fact_order_items(order_id);
CREATE INDEX idx_foi_customer   ON fact_order_items(customer_id);
CREATE INDEX idx_foi_product    ON fact_order_items(product_card_id);
CREATE INDEX idx_foi_category   ON fact_order_items(category_id);
CREATE INDEX idx_foi_department ON fact_order_items(department_id);
CREATE INDEX idx_foi_orderdate  ON fact_order_items(order_date_key);
CREATE INDEX idx_foi_shipdate   ON fact_order_items(shipping_date_key);
