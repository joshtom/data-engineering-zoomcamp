# Module 5 Homework: Data Platforms with Bruin — Solutions

## Question 1. Bruin Pipeline Structure

**Answer: `.bruin.yml` and `pipeline.yml` (assets can be anywhere)**

From the README:
> "The required parts of a Bruin project are:
> - `.bruin.yml` in the root directory
> - `pipeline.yml` in the `pipeline/` directory **(or in the root directory if you keep everything flat)**
> - `assets/` folder next to `pipeline.yml`"

The `.bruin.yml` and `pipeline.yml` are the two truly required files. The `assets/` folder location is flexible — it just needs to be discoverable next to `pipeline.yml`.

---

## Question 2. Materialization Strategies

**Answer: `time_interval` — incremental based on a time column**

`time_interval` is the strategy designed for time-windowed data. It:
1. **Deletes** all rows where the `incremental_key` falls within the run's time window
2. **Re-inserts** the result of your SELECT query for that same window

This is exactly what's needed for monthly NYC taxi data partitioned by `pickup_datetime` — it lets you reprocess any date range without rebuilding the entire table.

---

## Question 3. Pipeline Variables

**Answer: `bruin run --var 'taxi_types=["yellow"]'`**

Pipeline variables defined as arrays in `pipeline.yml` are overridden by passing a JSON array string to `--var`. The single quotes wrap the JSON so the shell doesn't interpret the double quotes. Example from the README:

```bash
bruin run ./pipeline/assets/ingestion/trips.py \
  --var 'taxi_types=["yellow"]'
```

---

## Question 4. Running with Dependencies

**Answer: `bruin run ingestion/trips.py --downstream`**

The `--downstream` flag tells Bruin to run the specified asset **and every asset that depends on it** (transitively). The path argument is the file path to the asset.

```bash
bruin run ingestion/trips.py --downstream
```

---

## Question 5. Quality Checks

**Answer: `name: not_null`**

`not_null` is the built-in Bruin check that fails if any row in the column contains a NULL value:

```yaml
columns:
  - name: pickup_datetime
    type: timestamp
    checks:
      - name: not_null
```

---

## Question 6. Lineage and Dependencies

**Answer: `bruin lineage`**

```bash
bruin lineage ./pipeline/assets/ingestion/trips.py
```

This prints the upstream and downstream dependency graph for the given asset. The VS Code extension also shows it visually in the Lineage Panel.

---

## Question 7. First-Time Run

**Answer: `--full-refresh`**

```bash
bruin run ./pipeline/pipeline.yml --full-refresh
```

`--full-refresh` truncates and recreates tables from scratch. The README explicitly notes:
> "Use `--full-refresh` to create/replace tables from scratch (helpful on a new DuckDB file)."
