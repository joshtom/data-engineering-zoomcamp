"""@bruin

name: ingestion.trips
type: python
image: python:3.11
connection: duckdb-default
materialization:
  type: table
  strategy: append

@bruin"""

import json
import os
from datetime import datetime, timezone
import pandas as pd
import requests
from io import BytesIO


BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"


def generate_monthly_urls(taxi_types: list[str], start_date: str, end_date: str) -> list[tuple[str, str]]:
    """
    Generate (url, taxi_type) tuples for all taxi types within the given date range.
    Each Parquet file covers one calendar month. We iterate month-by-month from
    start_date (inclusive) to end_date (exclusive) and build the TLC download URL.
    """
    start = datetime.strptime(start_date, "%Y-%m-%d")
    end = datetime.strptime(end_date, "%Y-%m-%d")

    urls = []
    for taxi_type in taxi_types:
        current = start.replace(day=1)
        while current < end:
            year_month = current.strftime("%Y-%m")
            filename = f"{taxi_type}_tripdata_{year_month}.parquet"
            url = f"{BASE_URL}/{filename}"
            urls.append((url, taxi_type))
            # Advance by one month without external deps
            if current.month == 12:
                current = current.replace(year=current.year + 1, month=1)
            else:
                current = current.replace(month=current.month + 1)
    return urls


def fetch_parquet(url: str) -> pd.DataFrame | None:
    """Download a Parquet file from a URL and return it as a DataFrame. Returns None on failure."""
    print(f"Fetching: {url}")
    response = requests.get(url, timeout=120)
    if response.status_code == 404:
        print(f"  -> Not found (skipping): {url}")
        return None
    response.raise_for_status()
    return pd.read_parquet(BytesIO(response.content))


def materialize() -> pd.DataFrame:
    """
    Fetch NYC Taxi trip data from the TLC public endpoint for each taxi type and
    month in the Bruin run window, then return a single concatenated DataFrame.

    Environment variables consumed:
      - BRUIN_START_DATE  (YYYY-MM-DD)  – inclusive lower bound of the run window
      - BRUIN_END_DATE    (YYYY-MM-DD)  – exclusive upper bound of the run window
      - BRUIN_VARS        (JSON string) – pipeline variables, must contain `taxi_types`

    Materialisation strategy is `append`, so deduplication is handled downstream
    in the staging layer.
    """
    # --- Date window ----------------------------------------------------------
    start_date = os.environ.get("BRUIN_START_DATE", "2022-01-01")
    end_date = os.environ.get("BRUIN_END_DATE", "2022-02-01")

    # --- Pipeline variable: taxi_types ----------------------------------------
    bruin_vars_raw = os.environ.get("BRUIN_VARS", '{"taxi_types": ["yellow"]}')
    bruin_vars = json.loads(bruin_vars_raw)
    taxi_types: list[str] = bruin_vars.get("taxi_types", ["yellow"])

    print(f"Run window : {start_date} → {end_date}")
    print(f"Taxi types : {taxi_types}")

    # --- Build URL list and fetch --------------------------------------------
    endpoints = generate_monthly_urls(taxi_types, start_date, end_date)

    if not endpoints:
        print("No endpoints generated for the given window — returning empty DataFrame.")
        return pd.DataFrame()

    frames: list[pd.DataFrame] = []
    extracted_at = datetime.now(timezone.utc)

    for url, taxi_type in endpoints:
        df = fetch_parquet(url)
        if df is None:
            continue

        # Keep data in its raw format; only add lineage columns
        df["taxi_type"] = taxi_type
        df["extracted_at"] = extracted_at

        # Normalise column names to lowercase so DuckDB handles them consistently
        df.columns = [c.lower() for c in df.columns]

        frames.append(df)
        print(f"  -> Loaded {len(df):,} rows from {url}")

    if not frames:
        print("No data fetched — returning empty DataFrame.")
        return pd.DataFrame()

    result = pd.concat(frames, ignore_index=True)
    print(f"Total rows ingested: {len(result):,}")
    return result
