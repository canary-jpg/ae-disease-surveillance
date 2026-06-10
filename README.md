# Disease Surveillance Analytics Engineering Portfolio - Project 3

An end-to-end analytics engineering pipeline built on real CDC surveillance data. Demonstrates incremental modeling, statistical anomaly detection, multi-pathogen surveillance, and time-series forecasting applied to public health epidemiology.

## Architecture

```
CDC Surveillance Data (Socrata API)
         ↓
Python Ingestion Scripts       — pulls & loads to BigQuery
         ↓
Staging Layer (dbt views)      — cleaned, typed, renamed
         ↓
Marts Layer (dbt tables)       — epidemiological metrics + anomaly detection
         ↓
Analysis Notebooks (Python)    — EDA, outbreak visualization
         ↓
Prophet Forecasting            — 8-week ahead influenza forecast
         ↓
ML Output (dbt table)          — forecasts surfaced with alert levels
```

## Data Sources

All data sourced from CDC public datasets via Socrata API (no API key required)

| Source | Dataset | Rows |
| ---- | ---- | ---- |
CDC NCHS | P&1 mortality by state and season | 32,606 |
| CDC NCHS | Weekly provisional deaths (flue, pneumonia, COVID) | 12,600 |
| CDC | Respiratory pathogen test positivity | 573 |

## Project Structure 

```
ae-disease-surveillance/
├── data_ingestion/
│   └── ingest_cdc_data.py         # CDC API ingestion
├── analysis/
│   ├── 01_surveillance_eda.ipynb  # EDA + outbreak visualization
│   └── 02_forecasting.ipynb       # Prophet forecasting
└── ae_disease_surveillance/       # dbt project
    ├── seeds/
    │   └── hhs_regions.csv        # HHS region reference
    ├── models/
    │   ├── staging/surveillance/  # 3 staging models
    │   └── marts/
    │       ├── surveillance/      # fct_weekly_deaths, fct_outbreak_flags
    │       │                      # fct_state_mortality, fct_pathogen_trends
    │       └── ml_outputs/        # fct_influenza_forecast
    └── macros/
        └── generate_schema_name.sql
```

## Data Models 

| Model | Layer | Rows | Description |
| --- | --- | --- | --- |
| `stg_surveillance__mortality_by_state` | Staging | 32K | P&I deaths by state |
| `stg_surveillance__weekly_deaths` | Staging | 12.6K | National weekly deaths |
| `stg_surveillance__test_positivity` | Staging | 573 | Pathogen test positivity |
| `fct_weekly_deaths` | Marts | 200 | Rolling averages + z-scores |
| `fct_outbreak_flags` | Marts | 199 | Z-score + CUMSUM detection |
| `fct_state_mortality` | Marts | 25.7K | State P&I burden by season |
| `fct_pathogen_trends` | Marts | 573 | Multi-pathogen signals |
| `fct_influenza_forecast` | ML Outputs | 8 | Prophet 8-week forecast | 

## Testing 

36 total tests across sources, staging, and marts. 

```bash
dbt build
```

| Result | Count |
| --- | --- |
| Pass | 35 |
| Warn | 1 (blank geoid in source data) | 
| Error | 0 | 

## Key Modeling Decisions

**Z-score anomaly detection:** Weekly influenza mortality is compared against a 52-week rolling baseline. A z-score > 2.0 triggers an elevated alert, > 3.0 triggers high alert. This is consistent with CDC's own statistical process control methodology.

**CUMSUM detection:** Complements z-score by detecting sustained elevations rather than single-week spikes. A CUMSUM statistic > 3.0 indicates a persistent signal requiring investigation.

**pct_pi calculation:** The source dataset provides raw death counts but not the P&I percentage. This was calculated in the staging model as `safe_divide(pi_deaths, all_deaths) * 100` - a data quality finding documented in the staging model description.

**Multi-pathogen surveillance:** Uses respiratory test positivity data covering influenza, COVID-19, and RSV reflecting modern surveillance practice where co-circulation of pathogens is the norm.

## Analysis Highlights

- **State mortality heatmap** - 50 states x 10 flu seasons of P&I burden
- **Outbreak detection dashboard** - z-score + CUMSUM alert visualization
- **Multi-pathogen comparison** - test positivity trends across pathogens
- **Prophet forecast** - 8-week ahead influenza mortality with 95% prediction intervals and cross-validated performance metrics

## Setup

```bash
#1. ingest CDC data
pip install request pandas google-cloud-bigquery pyarrow
python data_ingestion/ingest_cdc_data.py

#2.authenticate
gcloud auth application-default login

#3. install dbt dependencies
cd ae_disease_surveillance
dbt deps

#4. run full pipeline
dbt build

#5. run notebooks
pip install prophet scikit-learn matplotlib seaborn
jupyter notebook
```

## Stack

- **Warehouse:** Google BigQuery
- **Transformation:** dbt Core 1.11
- **Languages:** SQL, Python
- **Forecasting:** Prophet
- **Visualization:** matplotlib, seaborn

## Portfolio Context

This is Project 3 of a 5-project analytics engineering portfolio.

| Project | Domain | Key Patterns | 
| --- | --- | --- | 
[Project 1 - Product Analytics](https://github.com/canary-jpg/ae-product-analytics) | eCommerce | Sessionalization, cohort retention, churn model |
| [Project 2 - Support Analytics](https://github.com/canary-jpg/ae-support-analytics) | SaaS Support | SCD Type 2, NLP classification, escalation prediction |
| **Project 3 - Disease Surveillance** *(this repo)* |  Public Health | Anomaly detection, CUMSUM, Prophet forecasting |
| Project 4 - Health Outcomes *(coming soon)* | Clinical | Survival analysis, readmission prediction |
| Project 5 - Metrics Layer *(coming soon)* | Cross-domain | dbt Semantic Layer, unified metric definitions | 