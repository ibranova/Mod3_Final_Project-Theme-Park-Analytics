-- 01_eda.sql — Exploratory SQL (comment everything)

-- Q0: Row counts per table
SELECT 'dim_guest' AS table_name, COUNT(*) AS n FROM dim_guest
UNION ALL SELECT 'dim_ticket', COUNT(*) FROM dim_ticket
UNION ALL SELECT 'dim_attraction', COUNT(*) FROM dim_attraction
UNION ALL SELECT 'fact_visits', COUNT(*) FROM fact_visits
UNION ALL SELECT 'fact_ride_events', COUNT(*) FROM fact_ride_events
UNION ALL SELECT 'fact_purchases', COUNT(*) FROM fact_purchases;

-- Q1: Date range, distinct dates, visits per date
-- Purpose: understand coverage window and daily volume
SELECT MIN(visit_date) AS min_date, MAX(visit_date) AS max_date, COUNT(DISTINCT visit_date) AS distinct_dates
FROM fact_visits;

SELECT visit_date, COUNT(DISTINCT visit_id) AS visits
FROM fact_visits
GROUP BY visit_date
ORDER BY visit_date;

-- Q2: Visits by ticket_type_name (most -> least)
-- Join visits to ticket dimension
SELECT t.ticket_type_name, COUNT(DISTINCT v.visit_id) AS visits
FROM fact_visits v
LEFT JOIN dim_ticket t ON t.ticket_type_id = v.ticket_type_id
GROUP BY t.ticket_type_name
ORDER BY visits DESC;

-- Q3: Distribution of wait_minutes (with NULL count)
-- We review central tendency and missingness
SELECT
  COUNT(*) AS rows_total,
  SUM(CASE WHEN wait_minutes IS NULL THEN 1 ELSE 0 END) AS wait_nulls,
  AVG(wait_minutes) AS avg_wait,
  MIN(wait_minutes) AS min_wait,
  MAX(wait_minutes) AS max_wait
FROM fact_ride_events;

-- Optional: bucketed distribution to visualize queue pressure
SELECT
  CASE
    WHEN wait_minutes IS NULL THEN 'NULL'
    WHEN wait_minutes BETWEEN 0 AND 15 THEN '00–15'
    WHEN wait_minutes BETWEEN 16 AND 30 THEN '16–30'
    WHEN wait_minutes BETWEEN 31 AND 60 THEN '31–60'
    ELSE '>60'
  END AS wait_bucket,
  COUNT(*) AS events
FROM fact_ride_events
GROUP BY wait_bucket
ORDER BY
  CASE wait_bucket
    WHEN 'NULL' THEN 0
    WHEN '00–15' THEN 1
    WHEN '16–30' THEN 2
    WHEN '31–60' THEN 3
    ELSE 4
  END;

-- Q4: Average satisfaction by attraction and by category
SELECT a.attraction_name, AVG(satisfaction_rating) AS avg_satisfaction, COUNT(*) AS n_events
FROM fact_ride_events re
LEFT JOIN dim_attraction a ON a.attraction_id = re.attraction_id
GROUP BY a.attraction_name
ORDER BY avg_satisfaction DESC;

SELECT a.category, AVG(satisfaction_rating) AS avg_satisfaction, COUNT(*) AS n_events
FROM fact_ride_events re
LEFT JOIN dim_attraction a ON a.attraction_id = re.attraction_id
GROUP BY a.category
ORDER BY avg_satisfaction DESC;

-- Q5: Duplicates check — exact duplicate rows in fact_ride_events
-- We group by all columns; count>1 indicates duplicates
SELECT
  ride_event_id, visit_id, attraction_id, ride_time, wait_minutes, satisfaction_rating, photo_purchase,
  COUNT(*) AS dup_count
FROM fact_ride_events
GROUP BY ride_event_id, visit_id, attraction_id, ride_time, wait_minutes, satisfaction_rating, photo_purchase
HAVING COUNT(*) > 1
ORDER BY dup_count DESC;

-- Q6: Null audit for key columns
SELECT 'fact_visits.spend_cents_clean' AS col, SUM(CASE WHEN spend_cents_clean IS NULL THEN 1 ELSE 0 END) AS nulls FROM fact_visits
UNION ALL
SELECT 'fact_visits.guest_id', SUM(CASE WHEN guest_id IS NULL THEN 1 ELSE 0 END) FROM fact_visits
UNION ALL
SELECT 'fact_visits.ticket_type_id', SUM(CASE WHEN ticket_type_id IS NULL THEN 1 ELSE 0 END) FROM fact_visits
UNION ALL
SELECT 'fact_ride_events.wait_minutes', SUM(CASE WHEN wait_minutes IS NULL THEN 1 ELSE 0 END) FROM fact_ride_events
UNION ALL
SELECT 'fact_ride_events.satisfaction_rating', SUM(CASE WHEN satisfaction_rating IS NULL THEN 1 ELSE 0 END) FROM fact_ride_events
UNION ALL
SELECT 'fact_purchases.amount_cents_clean', SUM(CASE WHEN amount_cents_clean IS NULL THEN 1 ELSE 0 END) FROM fact_purchases;

-- Q7: Average party_size by day of week (dim_date.day_name)
-- Requires dim_date to be wired first
SELECT d.day_name, AVG(v.party_size) AS avg_party_size, COUNT(DISTINCT v.visit_id) AS visits
FROM fact_visits v
LEFT JOIN dim_date d ON d.date_id = v.date_id
GROUP BY d.day_name
ORDER BY
  CASE d.day_name
    WHEN 'Monday' THEN 1
    WHEN 'Tuesday' THEN 2
    WHEN 'Wednesday' THEN 3
    WHEN 'Thursday' THEN 4
    WHEN 'Friday' THEN 5
    WHEN 'Saturday' THEN 6
    WHEN 'Sunday' THEN 7
    ELSE 8 END;
