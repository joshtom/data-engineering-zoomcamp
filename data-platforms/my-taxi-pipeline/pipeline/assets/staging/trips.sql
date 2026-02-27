/* @bruin

name: staging.trips
type: duckdb.sql

depends:
  - ingestion.trips
  - ingestion.payment_lookup

materialization:
  type: table
  strategy: time_interval
  incremental_key: pickup_datetime
  time_granularity: timestamp

columns:
  - name: pickup_datetime
    type: timestamp
    description: "When the trip started — used as the incremental key"
    primary_key: true
    nullable: false
    checks:
      - name: not_null
  - name: dropoff_datetime
    type: timestamp
    description: "When the trip ended"
    primary_key: true
    nullable: false
    checks:
      - name: not_null
  - name: pickup_location_id
    type: integer
    description: "TLC zone ID where the trip started"
    primary_key: true
    checks:
      - name: not_null
  - name: dropoff_location_id
    type: integer
    description: "TLC zone ID where the trip ended"
    primary_key: true
    checks:
      - name: not_null
  - name: fare_amount
    type: float
    description: "Base metered fare in USD"
    primary_key: true
    checks:
      - name: not_null
  - name: taxi_type
    type: string
    description: "Type of taxi (yellow, green)"
    checks:
      - name: not_null
  - name: payment_type_id
    type: integer
    description: "Numeric payment type code from the raw data"
  - name: payment_type_name
    type: string
    description: "Human-readable payment type joined from ingestion.payment_lookup"
  - name: passenger_count
    type: integer
    description: "Number of passengers reported by the driver"
  - name: trip_distance
    type: float
    description: "Trip distance in miles"
    checks:
      - name: non_negative
  - name: total_amount
    type: float
    description: "Total amount charged including all fees and tips"
    checks:
      - name: non_negative
  - name: extracted_at
    type: timestamp
    description: "Timestamp when the record was extracted from the TLC source"

custom_checks:
  - name: no_duplicate_trips
    description: "Composite primary key (pickup_datetime, dropoff_datetime, pickup_location_id, dropoff_location_id, fare_amount) must be unique after deduplication"
    query: |
      SELECT COUNT(*) FROM (
        SELECT pickup_datetime, dropoff_datetime, pickup_location_id, dropoff_location_id, fare_amount
        FROM staging.trips
        GROUP BY 1, 2, 3, 4, 5
        HAVING COUNT(*) > 1
      ) duplicates
    value: 0

@bruin */

WITH deduplicated AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                pickup_datetime,
                dropoff_datetime,
                pulocationid,
                dolocationid,
                fare_amount
            ORDER BY extracted_at DESC
        ) AS rn
    FROM ingestion.trips
    WHERE pickup_datetime >= '{{ start_datetime }}'
      AND pickup_datetime <  '{{ end_datetime }}'
      AND pickup_datetime IS NOT NULL
      AND dropoff_datetime IS NOT NULL
      AND fare_amount IS NOT NULL
)

SELECT
    t.pickup_datetime,
    t.dropoff_datetime,
    t.pulocationid          AS pickup_location_id,
    t.dolocationid          AS dropoff_location_id,
    t.passenger_count,
    t.trip_distance,
    t.fare_amount,
    t.total_amount,
    t.payment_type          AS payment_type_id,
    p.payment_type_name,
    t.taxi_type,
    t.extracted_at
FROM deduplicated t
LEFT JOIN ingestion.payment_lookup p
    ON t.payment_type = p.payment_type_id
WHERE t.rn = 1
