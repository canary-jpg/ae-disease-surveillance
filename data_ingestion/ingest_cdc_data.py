"""
CDC FluView data ingestion script.
Uses CDC's Socrata datasets: 
- pp7x-dyj2: P&I mortality by state and season
- ynw2-4viq: Weekly provisional deaths (flu, pneumonia, COVID)
- seuz-s2cv: Weekly respiratory pathogen test positivity
"""

import requests
import pandas as pd 
import numpy as np 
from google.cloud import bigquery 
from datetime import datetime
import time 

PROJECT = "ae-project-portfolio"
DATASET = "surveillance_raw"

client = bigquery.Client(project=PROJECT)

#helper functions
def write_to_bq(df, table_id, schema, mode="WRITE_TRUNCATE"):
    full_table = f"{PROJECT}.{DATASET}.{table_id}"
    job_config = bigquery.LoadJobConfig(
        schema=schema,
        write_disposition=mode
    )
    job = client.load_table_from_dataframe(df, full_table, job_config=job_config)
    job.result()
    print(f"Written {len(df):,} rows to {full_table}")

def create_dataset():
    try:
        client.create_dataset(f"{PROJECT}.{DATASET}", exists_ok=True)
        print(f"Dataset: {DATASET} ready")
    except Exception as e:
        print(f"Dataset note: {e}")

def fetch_all_pages(url, params, limit=5000):
    """Paginate throug a Socrata endpoint """
    all_records = []
    offset = 0
    params['$limit'] = limit 

    while True:
        params['$offset'] = offset
        response = requests.get(url, params, timeout=60)
        batch = response.json()

        if not batch or isinstance(batch, dict):
            break
        
        all_records.extend(batch)
        print(f"Fetch {len(all_records):,} records so far...")

        if len(batch) < limit:
            break 
        offset += limit
    return all_records

#P&I mortality by state
def fetch_mortality_by_state():
    print("\nFetching P&I mortality by state...")

    url = "https://data.cdc.gov/resource/pp7x-dyj2.json"
    params = {'$order': 'mmwr_year_week DESC'}
    data = fetch_all_pages(url, params)
    print(f"Total records: {len(data):,}")

    records = []
    for item in data:
        try:
            records.append({
                'state': str(item.get('state', '')),
                'geoid': str(item.get('geoid', '')),
                'age': str(item.get('age', '')),
                'season': str(item.get('season', '')),
                'mmwr_year_week': str(item.get('mmwr_year_week', '')),
                'year': int(str(item.get('mmwr_year_week', '0'))[:4] or 0),
                'week': int(str(item.get('mmwr_year_week', '00'))[-2:] or 0),
                'pi_deaths': float(item.get('deaths_from_pneumonia_and_influenza', 0) or 0),
                'all_deaths': float(item.get('all_deaths', 0) or 0),
                'pct_pi': float(item.get('percent_of_deaths_due_to_pneumonia_or_influenza', 0) or 0),
                'pct_complete': float(item.get('percent_complete', 0) or 0),
            })
        except (ValueError, TypeError):
            continue 
    return pd.DataFrame(records)



#weekly provisional deaths
def fetch_weekly_deaths():
    print("\nFetching weekly provisional deaths...")

    url = "https://data.cdc.gov/resource/ynw2-4viq.json"
    params = {'$order': 'week_ending_date DESC'}
    data = fetch_all_pages(url, params)
    print(f"Total records: {len(data):,}")

    records = []
    for item in data:
        if item.get('group') != 'By Week':
            continue
        if item.get('age_group') != 'All Ages':
            continue
        try:
            records.append({
                'jurisdiction': str(item.get('jurisdiction', '')),
                'week_ending_date': str(item.get('week_ending_date', ''))[:10],
                'mmwr_year': int(item.get('mmwryear', 0) or 0),
                'mmwr_week': int(item.get('mmwrweek', 0) or 0),
                'total_deaths': float(item.get('total_deaths', 0) or 0),
                'pneumonia_deaths': float(item.get('pneumonia_deaths', 0) or 0),
                'influenza_deaths': float(item.get('influenza_deaths', 0) or 0),
                'covid_deaths': float(item.get('covid_19_deaths', 0) or 0),
                'pni_deaths': float(item.get('pneumonia_or_influenza', 0) or 0),
                'pni_covid_deaths': float(item.get('pneumonia_influenza_or_covid', 0) or 0),
            })
        except (ValueError, TypeError):
            continue 
    return pd.DataFrame(records)


#respiratory pathogen test positivity
def fetch_test_positivity():
    print("\nFetching respiratory pathogen test positivity...")

    url = "https://data.cdc.gov/resource/seuz-s2cv.json"
    params = {'$order': 'week_end DESC'}
    data = fetch_all_pages(url, params)
    print(f"Total records: {len(data):,}")

    records = []
    for item in data:
        try:
            week_end = str(item.get('week_end', ''))[:10]
            records.append({
                'week_end': week_end,
                'pathogen': str(item.get('pathogen', '')),
                'pct_positive': float(item.get('percent_test_positivity', 0) or 0),
            })
        except (ValueError, TypeError):
            continue 
    return pd.DataFrame(records)


#main function
if __name__ == "__main__":
    create_dataset()

    #mortality by state
    mort_state_df = fetch_mortality_by_state()
    if not mort_state_df.empty:
        write_to_bq(mort_state_df, 'mortality_by_state', [
            bigquery.SchemaField("state", "STRING"),
            bigquery.SchemaField("geoid", "STRING"),
            bigquery.SchemaField("age", "STRING"),
            bigquery.SchemaField("season", "STRING"),
            bigquery.SchemaField("mmwr_year_week", "STRING"),
            bigquery.SchemaField("year", "INTEGER"),
            bigquery.SchemaField("week", "INTEGER"),
            bigquery.SchemaField("pi_deaths", "FLOAT"),
            bigquery.SchemaField("all_deaths", "FLOAT"),
            bigquery.SchemaField("pct_pi", "FLOAT"),
            bigquery.SchemaField("pct_complete", "FLOAT"),
        ])
    
    #weekly deaths
    weekly_df = fetch_weekly_deaths()
    if not weekly_df.empty:
        write_to_bq(weekly_df, 'weekly_deaths', [
            bigquery.SchemaField("jurisdiction", "STRING"),
            bigquery.SchemaField("week_ending_date", "STRING"),
            bigquery.SchemaField("mmwr_year", "INTEGER"),
            bigquery.SchemaField("mmwr_week", "INTEGER"),
            bigquery.SchemaField("total_deaths", "FLOAT"),
            bigquery.SchemaField("pneumonia_deaths", "FLOAT"),
            bigquery.SchemaField("influenza_deaths", "FLOAT"),
            bigquery.SchemaField("covid_deaths", "FLOAT"),
            bigquery.SchemaField("pni_deaths", "FLOAT"),
            bigquery.SchemaField("pni_covid_deaths", "FLOAT"),
        ])

    #test positivity
    test_pos_df = fetch_test_positivity()
    if not test_pos_df.empty:
        write_to_bq(test_pos_df, 'test_positivity', [
            bigquery.SchemaField("week_end", "STRING"),
            bigquery.SchemaField("pathogen", "STRING"),
            bigquery.SchemaField("pct_positive", "FLOAT")
        ])

    print("Ingestion complete!")
    print(f" mortality_by_state: {len(mort_state_df):,} rows")
    print(f"weekly_deaths: {len(weekly_df):,} rows")
    print(f"test_positivity: {len(test_pos_df):,} rows")
            