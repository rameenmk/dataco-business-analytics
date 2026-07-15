# DataCo Business Performance Review

An end-to-end analytics project on the DataCo Global supply chain dataset:
raw data to a modeled warehouse, SQL analysis, and a Power BI dashboard that
answers real business questions. Built to production shape — reproducible ETL,
a validated star schema, documented measures, and recommendations a stakeholder
could act on.

![Dashboard](dashboard.png)

---

## The headline findings

**1. Premium shipping tiers can't keep their promises.** First Class quotes
next-day delivery and misses it 95% of the time, because it actually takes two
days. Standard Class, which quotes four days, is the most reliable tier. The
company is late on 55% of shipments, and the cause is the quoted delivery
windows, not warehouse speed.

**2. Half the order book has never settled.** Of $36.8M in order value, only
$16.1M has been collected. $19.1M sits unsettled, $8.1M of it in pending payment
alone. That is a larger problem, in dollars, than the delivery issue.

**3. Every fraud flag traces to one payment method.** All suspected-fraud orders
used bank transfer; debit, cash, and other methods show zero. A pattern this
clean points to an automated review rule, not real fraud — so the 2.26% rate is
treated as a system artifact, not a fraud measure.

Full write-up: [`docs/04_recommendations.md`](docs/04_recommendations.md).

---

## What's in this repo

| Area | What it is |
|---|---|
| **ETL** | Python pipeline: cleans raw data, strips PII, models a star schema, validates itself. |
| **Data quality** | Standalone check script — keys, referential integrity, PII, value bounds. |
| **Warehouse** | PostgreSQL schema (DDL) and a one-command load script. |
| **SQL analysis** | Six business questions answered with documented queries. |
| **Semantic model** | Power BI model: 20+ DAX measures, role-playing date dimension, custom theme. |
| **Dashboard** | Single-page business performance review (the image above). |
| **Docs** | Data dictionary, findings, recommendations, dashboard spec. |

---

## Tech stack

Python (pandas) · PostgreSQL · SQL · Power BI (DAX) · star-schema dimensional modeling

---

## How it's built

**Star schema.** The raw 53-column flat file is modeled into one fact table at
order-line grain plus six dimensions (order, customer, product, category,
department, date). Grain is the finest available, so any metric rolls up cleanly.

**Reproducible ETL.** `etl/clean_and_model.py` reads the Latin-1 source, removes
PII (email, password, address), drops dead and duplicate columns, standardizes
names, and writes the modeled tables. It validates key uniqueness and referential
integrity on every run.

**Semantic model.** The Power BI layer defines 20+ measures once — sales, margin,
late rate, revenue at risk, fraud rate, unsettled value — with additivity handled
correctly (rates are averaged, never summed) and a role-playing date dimension for
order vs. shipping date.

Details: [`docs/01_data_model.md`](docs/01_data_model.md) ·
[`docs/05_data_dictionary.md`](docs/05_data_dictionary.md)

---

## Reproduce it

```bash
pip install -r requirements.txt

python etl/clean_and_model.py        # raw CSV -> modeled star-schema tables
python etl/data_quality_checks.py    # validate the warehouse (exit 0 = pass)
./warehouse/load_postgres.sh         # build the PostgreSQL warehouse (optional)
```

Then open `powerbi/` for the measures and theme, and point Power BI at the
tables in `data/processed/`.

---

## Repo structure

```
etl/          clean_and_model.py, data_quality_checks.py
warehouse/    schema.sql, load_postgres.sh
sql/          analysis.sql
powerbi/      measures.dax, theme.json
docs/         data model, findings, recommendations, data dictionary, dashboard spec
data/         processed tables (raw data not committed)
```

---

## Data and limitations

Source: DataCo Global supply chain, 180,519 order lines. Order volume drops by
more than half after September 2017 with no change in any other metric, which
indicates incomplete data capture rather than a real decline. Analysis is limited
to the clean window (Jan 2015 – Sep 2017, 171,962 lines). Late delivery, margin,
and discount rate are flat across market, segment, category, and day of week,
which is why the analysis focuses on shipping mode and order status, where the
real variation is. The fraud figure reflects a likely system rule and is not
treated as an observed fraud rate.
