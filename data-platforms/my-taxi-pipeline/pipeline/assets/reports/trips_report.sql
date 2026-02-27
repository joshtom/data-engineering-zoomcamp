/* @bruin

name: reports.trips_report
type: duckdb.sql

depends:
  - staging.trips

materialization:
  type: table
  strategy: time_interval
  incremental_key: pickup_datetime
  time_granularity: timestamp

columns:
  - name: trip_date
    type: date
    description: "Calendar date the trips took place (derived from pickup_datetime)"
    primary_key: true
    checks:
      - name: not_null
  - name: taxi_type
    type: string
    description: "Type of taxi (yellow, green)"
    primary_key: true
    checks:
      - name: not_null
  - name: payment_type_name
    type: string
    description: "Human-readable payment type (from payment_lookup)"
    primary_key: true
  - name: total_trips
    type: integer
    description: "Number of trips in this grouping"
    checks:
      - name: non_negative
  - name: total_passengers
    type: integer
    description: "Sum of passenger counts for this grouping"
    checks:
      - name: non_negative
  - name: total_distance_miles
    type: float
    description: "Sum of trip distances in miles"
    checks:
      - name: non_negative
  - name: total_fare_amount
    type: float
    description: "Sum of base fares in USD"
    checks:
      - name: non_negative
  - name: total_revenue
    type: float
    description: "Sum of total amounts charged (fares + tips + fees) in USD"
    checks:
      - name: non_negative
  - name: avg_trip_distance_miles
    type: float
    description: "Average trip distance in miles for this grouping"
    checks:
      - name: non_negative
  - name: avg_fare_amount
    type: float
    description: "Average base fare in USD for this grouping"
    checks:
      - name: non_negative

@bruin */

SELECT
    CAST(pickup_datetime AS DATE)          AS trip_date,
    taxi_type,
    COALESCE(payment_type_name, 'unknown') AS payment_type_name,
    COUNT(*)                               AS total_trips,
    SUM(passenger_count)                   AS total_passengers,
    SUM(trip_distance)                     AS total_distance_miles,
    SUM(fare_amount)                       AS total_fare_amount,
    SUM(total_amount)                      AS total_revenue,
    AVG(trip_distance)                     AS avg_trip_distance_miles,
    AVG(fare_amount)                       AS avg_fare_amount
FROM staging.trips
WHERE pickup_datetime >= '{{ start_datetime }}'
  AND pickup_datetime <  '{{ end_datetime }}'
GROUP BY 1, 2, 3
