#!/usr/bin/env bash
# ---------------------------------------------------------------------
# Build the DataCo warehouse in PostgreSQL from the processed star-schema CSVs.
# Usage:  ./warehouse/load_postgres.sh
# Requires: psql on PATH, and env vars PGHOST/PGUSER/PGPASSWORD (or defaults).
# ---------------------------------------------------------------------
set -euo pipefail

DB=${PGDATABASE:-dataco}
DATA_DIR="$(cd "$(dirname "$0")/../data/processed" && pwd)"

echo ">> creating database '$DB' (if absent)"
createdb "$DB" 2>/dev/null || echo "   database already exists, continuing"

echo ">> applying schema"
psql -d "$DB" -v ON_ERROR_STOP=1 -f "$(dirname "$0")/schema.sql"

# Load order matters: dimensions before the fact (FK constraints).
for t in dim_date dim_category dim_department dim_customer dim_product dim_order fact_order_items; do
    echo ">> loading $t"
    psql -d "$DB" -v ON_ERROR_STOP=1 \
        -c "\copy $t FROM '$DATA_DIR/$t.csv' WITH (FORMAT csv, HEADER true, NULL '')"
done

echo ">> row counts"
psql -d "$DB" -c "
SELECT 'fact_order_items' t, count(*) FROM fact_order_items
UNION ALL SELECT 'dim_order',      count(*) FROM dim_order
UNION ALL SELECT 'dim_customer',   count(*) FROM dim_customer
UNION ALL SELECT 'dim_product',    count(*) FROM dim_product
UNION ALL SELECT 'dim_category',   count(*) FROM dim_category
UNION ALL SELECT 'dim_department', count(*) FROM dim_department
UNION ALL SELECT 'dim_date',       count(*) FROM dim_date;"

echo ">> done. warehouse '$DB' is ready."
