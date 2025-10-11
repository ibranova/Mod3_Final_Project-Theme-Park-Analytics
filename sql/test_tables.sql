SELECT * FROM dim_attraction;
SELECT * FROM dim_guest;
SELECT * FROM dim_ticket;
SELECT * FROM fact_purchases;
SELECT * FROM fact_ride_events;
SELECT * FROM fact_visits;
SELECT * FROM dim_date;


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
ORDER BY visits ASC;

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
HAVING dup_count > 1
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


SELECT d.date_iso, d.day_name, d.is_weekend, COUNT(DISTINCT v.visit_id) AS daily_visits
FROM dim_date d
LEFT JOIN fact_visits v ON v.date_id = d.date_id
GROUP BY d.date_iso, d.day_name, d.is_weekend
ORDER BY d.date_iso;
-----------------------


-- 1) Create dim_date
CREATE TABLE IF NOT EXISTS dim_date (
  date_id    INTEGER PRIMARY KEY,   -- e.g., 20250701
  date_iso   TEXT NOT NULL,         -- 'YYYY-MM-DD'
  day_name   TEXT,                  -- 'Monday', ...
  is_weekend INTEGER,               -- 0/1
  season     TEXT                   -- e.g., 'Summer'
);

-- 2) Insert rows (these match the data in themepark.db)
INSERT OR IGNORE INTO dim_date (date_id, date_iso, day_name, is_weekend, season) VALUES
(20250701, '2025-07-01', 'Tuesday',   0, 'Summer'),
(20250702, '2025-07-02', 'Wednesday', 0, 'Summer'),
(20250703, '2025-07-03', 'Thursday',  0, 'Summer'),
(20250704, '2025-07-04', 'Friday',    0, 'Summer'),
(20250705, '2025-07-05', 'Saturday',  1, 'Summer'),
(20250706, '2025-07-06', 'Sunday',    1, 'Summer'),
(20250707, '2025-07-07', 'Monday',    0, 'Summer'),
(20250708, '2025-07-08', 'Tuesday',   0, 'Summer');


-- 3) “Wire” fact_visits to dim_date:
-- Convert visit_date ('YYYY-MM-DD') -> date_id (YYYYMMDD as an integer) and store it.UPDATE fact_visits
UPDATE fact_visits
SET date_id = CAST(STRFTIME('%Y%m%d', visit_date) AS INTEGER);

-- 4) Index for faster joins
CREATE INDEX IF NOT EXISTS idx_fact_visits_date_id ON fact_visits(date_id);

-- 5) Visits lacking a matching dim_date row (should be ZERO after you populate dim_date for your full range)
SELECT COUNT(*) AS visits_without_date
FROM fact_visits v
LEFT JOIN dim_date d ON d.date_id = v.date_id
WHERE d.date_id IS NULL;

-- 6) Sanity check join: Daily visit counts using the “wired” key
SELECT d.date_iso, d.day_name, d.is_weekend, COUNT(DISTINCT v.visit_id) AS daily_visits
FROM dim_date d
LEFT JOIN fact_visits v ON v.date_id = d.date_id
GROUP BY d.date_iso, d.day_name, d.is_weekend
ORDER BY d.date_iso;


WITH c AS (
  SELECT
    rowid AS rid,
    REPLACE(REPLACE(REPLACE(REPLACE(UPPER(COALESCE(amount_cents,'')),
      'USD',''), '$',''), ',', ''), ' ', '') AS cleaned
  FROM fact_purchases
)
UPDATE fact_purchases
SET amount_cents_clean = CAST((SELECT cleaned FROM c WHERE c.rid = fact_purchases.rowid) AS INTEGER)
WHERE LENGTH((SELECT cleaned FROM c WHERE c.rid = fact_purchases.rowid)) > 0;

CREATE VIEW IF NOT EXISTS v_visit_spend_dollars AS
SELECT visit_id, spend_cents_clean/100.0 AS spend_usd
FROM fact_visits;

CREATE VIEW IF NOT EXISTS v_purchase_amount_dollars AS
SELECT purchase_id, amount_cents_clean/100.0 AS amount_usd
FROM fact_purchases;


SELECT COUNT(*) AS duplicate_groups
FROM (
  SELECT visit_id, attraction_id, ride_time, wait_minutes, satisfaction_rating, photo_purchase, COUNT(*) AS c
  FROM fact_ride_events
  GROUP BY visit_id, attraction_id, ride_time, wait_minutes, satisfaction_rating, photo_purchase
  HAVING COUNT(*) > 1
);

BEGIN TRANSACTION;
WITH ranked AS (
  SELECT rowid AS rid,
         ROW_NUMBER() OVER (
           PARTITION BY visit_id, attraction_id, ride_time, wait_minutes, satisfaction_rating, photo_purchase
           ORDER BY rowid
         ) AS rn
  FROM fact_ride_events
)
DELETE FROM fact_ride_events
WHERE rowid IN (SELECT rid FROM ranked WHERE rn > 1);
COMMIT;

-- Orphan 1

SELECT v.visit_id, v.guest_id
FROM fact_visits v
LEFT JOIN dim_guest g ON g.guest_id = v.guest_id
WHERE g.guest_id IS NULL;

-- Orphan visits (ticket_type_id not in dim_ticket)
SELECT v.visit_id, v.ticket_type_id
FROM fact_visits v
LEFT JOIN dim_ticket t ON t.ticket_type_id = v.ticket_type_id
WHERE t.ticket_type_id IS NULL;

-- Orphan ride events (visit_id not in fact_visits)
SELECT re.ride_event_id, re.visit_id
FROM fact_ride_events re
LEFT JOIN fact_visits v ON v.visit_id = re.visit_id
WHERE v.visit_id IS NULL;

-- Orphan ride events (attraction_id not in dim_attraction)
SELECT re.ride_event_id, re.attraction_id
FROM fact_ride_events re
LEFT JOIN dim_attraction a ON a.attraction_id = re.attraction_id
WHERE a.attraction_id IS NULL;

-- Orphan purchases (visit_id not in fact_visits)
SELECT p.purchase_id, p.visit_id
FROM fact_purchases p
LEFT JOIN fact_visits v ON v.visit_id = p.visit_id
WHERE v.visit_id IS NULL;

UPDATE fact_ride_events
SET wait_minutes = NULL
WHERE wait_minutes IS NOT NULL AND wait_minutes < 0;

ALTER TABLE fact_visits ADD COLUMN promotion_code_norm TEXT;
UPDATE fact_visits
SET promotion_code_norm = NULLIF(TRIM(UPPER(COALESCE(promotion_code,''))), '');

UPDATE fact_visits
SET promotion_code_norm = REPLACE(promotion_code_norm, 'SUMMER-25', 'SUMMER25'); 

SELECT
  (SELECT COUNT(*) FROM fact_ride_events WHERE wait_minutes IS NULL) AS waits_null_after_clean,
  (SELECT COUNT(*) FROM fact_visits WHERE promotion_code_norm IS NULL) AS promo_nulls_after_norm;
  
  
  SELECT COUNT(*) AS waits_null FROM fact_ride_events WHERE wait_minutes IS NULL ;
  
  CREATE VIEW IF NOT EXISTS v_visit_waits AS
SELECT
  re.visit_id,
  AVG(re.wait_minutes) AS avg_wait_minutes
FROM fact_ride_events re
GROUP BY re.visit_id;
 CREATE TABLE feat_visits AS
WITH base AS (
  SELECT
    v.visit_id,
    v.guest_id,
    v.ticket_type_id,
    v.visit_date,
    v.party_size,
    v.entry_time,
    v.exit_time,
    v.spend_cents_clean,
    -- stay_minutes
    CAST((JULIANDAY(v.exit_time) - JULIANDAY(v.entry_time)) * 24.0 * 60.0 AS INTEGER) AS stay_minutes,
    -- visit_hour_bucket from entry hour
    CASE
      WHEN CAST(STRFTIME('%H', v.entry_time) AS INTEGER) BETWEEN 0 AND 11 THEN 'Morning'
      WHEN CAST(STRFTIME('%H', v.entry_time) AS INTEGER) BETWEEN 12 AND 16 THEN 'Afternoon'
      WHEN CAST(STRFTIME('%H', v.entry_time) AS INTEGER) BETWEEN 17 AND 20 THEN 'Evening'
      ELSE 'Late'
    END AS visit_hour_bucket
  FROM fact_visits v
),
waits AS (
  SELECT
    vw.visit_id,
    CASE
      WHEN vw.avg_wait_minutes IS NULL THEN 'Unknown'
      WHEN vw.avg_wait_minutes BETWEEN 0 AND 15 THEN '00–15'
      WHEN vw.avg_wait_minutes BETWEEN 16 AND 30 THEN '16–30'
      WHEN vw.avg_wait_minutes BETWEEN 31 AND 60 THEN '31–60'
      ELSE '>60'
    END AS wait_bucket
  FROM v_visit_waits vw
),
repeat_flag AS (
  -- is_repeat_guest based on number of visits for the guest across all time
  SELECT
    visit_id,
    CASE WHEN visit_count > 1 THEN 1 ELSE 0 END AS is_repeat_guest
  FROM (
    SELECT
      v.visit_id,
      COUNT(*) OVER (PARTITION BY v.guest_id) AS visit_count
    FROM fact_visits v
  )
)
SELECT
  b.*,
  w.wait_bucket,
  r.is_repeat_guest,
  -- spend per person (in cents)
  CASE WHEN b.party_size IS NULL OR b.party_size <= 0 THEN NULL
       ELSE CAST(ROUND(b.spend_cents_clean * 1.0 / b.party_size, 0) AS INTEGER)
  END AS spend_per_person_cents
FROM base b
LEFT JOIN waits w ON w.visit_id = b.visit_id
LEFT JOIN repeat_flag r ON r.visit_id = b.visit_id;



SELECT * FROM v_visit_waits
SELECT * FROM fact_purchases;

create table spend_per_category AS
SELECT g.guest_id,
       SUM(CASE WHEN p.category = 'Food' THEN p.amount_cents_clean ELSE 0 END) AS food_spend,
       SUM(CASE WHEN p.category= 'Merch' THEN p.amount_cents_clean ELSE 0 END) AS merch_spend
FROM dim_guest g
JOIN fact_visits f ON f.guest_id = g.guest_id
JOIN fact_purchases p ON f.visit_id = p.visit_id
GROUP BY g.guest_id;
SELECT * FROM spend_per_category



SELECT v.visit_id, v.guest_id
FROM fact_visits v
LEFT JOIN dim_guest g ON g.guest_id = v.guest_id
WHERE g.guest_id IS NOT NULL;

CREATE TABLE customers_life_time_value AS 
SELECT g.guest_id, first_name, last_name, 
       SUM(p.amount_cents_clean) AS lifetime_value
FROM dim_guest g
JOIN fact_visits f ON f.guest_id = g.guest_id
JOIN fact_purchases p ON f.visit_id = p.visit_id
GROUP BY g.guest_id
ORDER BY lifetime_value DESC;

CREATE VIEW if not EXISTS customers_life_time_value AS
SELECT g.guest_id, first_name, last_name, 
       SUM(p.amount_cents_clean) AS lifetime_value
FROM dim_guest g
JOIN fact_visits f ON f.guest_id = g.guest_id
JOIN fact_purchases p ON f.visit_id = p.visit_id
GROUP BY g.guest_id
ORDER BY lifetime_value DESC;
-------------------------------
SELECT * FROM dim_date
SELECT * FROM fact_visits
SELECT * FROM v_visit_spend_dollars
SELECT * FROM dai

WITH filtered AS(
SELECT f.visit_date, 
				    SUM(spend_usd) OVER (ORDER BY spend_usd DESC) AS running_total
FROM fact_visits f 
JOIN v_visit_spend_dollars v ON v.visit_id = f.visit_id
),
daily_visit(
SELECT count(visit_id)
FROM fact_visits 
GROUP BY date_id
)

-------------------------------

WITH daily AS (
 SELECT
    d.date_iso,
    d.day_name,
    d.is_weekend,
    COUNT(DISTINCT v.visit_id) AS daily_visits,
    SUM(vv.spend_usd) AS daily_spend_USD
  FROM dim_date d
  LEFT JOIN fact_visits v ON v.date_id = d.date_id
  LEFT JOIN v_visit_spend_dollars vv ON vv.visit_id = v.visit_id
  GROUP BY d.date_iso, d.day_name, d.is_weekend
  ORDER BY daily_spend_USD DESC
  ),
  with_runs AS(
   SELECT
    *,
    SUM(daily_visits) OVER (ORDER BY date_iso) AS visits_running_total,
    SUM(daily_spend_USD) OVER (ORDER BY date_iso) AS spend_running_total
  FROM daily
  )
  SELECT * FROM with_runs ORDER BY date_iso;
  
  
  ------------------------
WITH daily AS (
  SELECT d.date_iso, is_weekend, day_name, COUNT(DISTINCT v.visit_id) AS daily_visits
  FROM dim_date d
  LEFT JOIN fact_visits v ON v.date_id = d.date_id
  GROUP BY d.date_iso
)
SELECT *
FROM (
  SELECT
    date_iso,
    daily_visits,
	is_weekend,
	day_name,
    DENSE_RANK() OVER (ORDER BY daily_visits DESC) AS rnk
  FROM daily
)
WHERE rnk <= 3
ORDER BY daily_visits DESC;
-------------------------


----
WITH max_date AS (
  SELECT MAX(visit_date) AS max_visit_date FROM fact_visits
),
per_guest AS (
  SELECT
    g.guest_id,
    g.home_state, first_name, last_name, 
    MIN(v.visit_date) AS first_visit,
    MAX(v.visit_date) AS last_visit,
    COUNT(DISTINCT v.visit_id) AS frequency,
    COALESCE(SUM(vv.spend_usd), 0) AS clv_USD
  FROM dim_guest g
  LEFT JOIN fact_visits v ON v.guest_id = g.guest_id
  LEFT JOIN v_visit_spend_dollars vv ON vv.visit_id = v.visit_id
  GROUP BY g.guest_id, g.home_state
),
rfm AS (
  SELECT
    p.*,
    CAST((JULIANDAY((SELECT max_visit_date FROM max_date)) - JULIANDAY(p.last_visit)) AS INTEGER) AS recency_days
  FROM per_guest p
)
SELECT
  r.*,
  DENSE_RANK() OVER (PARTITION BY r.home_state ORDER BY r.clv_USD DESC) AS clv_rank_in_state
FROM rfm r
ORDER BY clv_USD DESC;



-----


WITH ordered_visits AS (
  SELECT
    v.guest_id,
    v.visit_id,
    v.visit_date,
    vv.spend_usd,
    v.ticket_type_id,
    v.party_size,
    d.day_name,
    LAG(vv.spend_usd) OVER (PARTITION BY v.guest_id ORDER BY v.visit_date) AS prev_spend
  FROM fact_visits v
  LEFT JOIN dim_date d ON d.date_id = v.date_id
  LEFT JOIN v_visit_spend_dollars vv ON v.visit_id = vv.visit_id
),
deltas AS (
  SELECT
    o.*,
    (o.spend_usd - o.prev_spend) AS delta_spend,
    CASE
      WHEN o.party_size IS NULL THEN 'Unknown'
      WHEN o.party_size = 1 THEN '1'
      WHEN o.party_size BETWEEN 2 AND 3 THEN '2–3'
      WHEN o.party_size BETWEEN 4 AND 5 THEN '4–5'
      ELSE '6+'
    END AS party_size_bucket
  FROM ordered_visits o
),
by_factors AS (
  SELECT
    t.ticket_type_name,
    day_name,
    party_size_bucket,
    AVG(delta_spend) AS avg_delta_spend
  FROM deltas d
  LEFT JOIN dim_ticket t ON t.ticket_type_id = d.ticket_type_id
  WHERE d.prev_spend IS NOT NULL
  GROUP BY t.ticket_type_name, day_name, party_size_bucket
)
SELECT * FROM by_factors ORDER BY avg_delta_spend DESC;

------


WITH seq AS (
  SELECT
    v.guest_id,
    v.visit_id,
    v.visit_date,
    t.ticket_type_name,
    FIRST_VALUE(t.ticket_type_name) OVER (PARTITION BY v.guest_id ORDER BY v.visit_date) AS first_ticket
  FROM fact_visits v
  LEFT JOIN dim_ticket t ON t.ticket_type_id = v.ticket_type_id
),
flags AS (
  SELECT
    guest_id,
    MAX(CASE WHEN ticket_type_name != first_ticket THEN 1 ELSE 0 END) AS switched_flag
  FROM seq
  GROUP BY guest_id
)
SELECT
  s.guest_id,
  s.switched_flag,
  (SELECT ticket_type_name FROM seq WHERE guest_id = s.guest_id ORDER BY visit_date LIMIT 1) AS first_ticket_example
FROM flags s
ORDER BY s.switched_flag DESC, s.guest_id;

SELECT * FROM fact_ride_events
SELECT * FROM v_visit_spend_dollars
SELECT * from wait_bucket
WITH ride AS (
SELECT f.visit_id, f.attraction_id, f.wait_minutes, attraction_name, sum(vv.spend_usd) AS total_spend
FROM fact_ride_events f 
LEFT JOIN v_visit_spend_dollars vv ON f.visit_id = f.visit_id 
LEFT JOIN dim_attraction d ON f.attraction_id = d.attraction_id 
GROUP BY wait_minutes
ORDER BY total_spend DESC
),
ranking AS(
SELECT r.*,
									dense_rank() OVER ( 
									ORDER BY total_spend DESC) AS attraction_rank
FROM ride r
GROUP BY attraction_name
ORDER BY total_spend DESC
)
SELECT * 
FROM( 
SELECT * FROM ranking
where attraction_rank <=3);

SELECT * FROM v_purchase_amount_dollars
SELECT * FROM dim_date;
COMMIT;


---------------------------
-- Python
-- FIG1
WITH daily AS (
  SELECT
    d.date_iso AS date,
    COUNT(DISTINCT v.visit_id) AS daily_visits,
    SUM(v.spend_cents_clean)/100.0 AS daily_spend_usd
  FROM dim_date d
  LEFT JOIN fact_visits v ON v.date_id = d.date_id
  GROUP BY d.date_iso
)
SELECT * FROM daily ORDER BY date; 

------- FIG2
SELECT
  COALESCE(a.category, 'Unknown') AS category,
  a.attraction_name,
  AVG(re.wait_minutes) AS avg_wait,
  AVG(re.satisfaction_rating) AS avg_sat,
  COUNT(*) AS n_events
FROM fact_ride_events re
LEFT JOIN dim_attraction a ON a.attraction_id = re.attraction_id
GROUP BY a.category, a.attraction_name
HAVING n_events >= 10
ORDER BY avg_wait DESC;


WITH per_guest AS (
  SELECT
    g.home_state,
    g.guest_id,
    COALESCE(SUM(v.spend_cents_clean), 0)/100.0 AS clv_usd
  FROM dim_guest g
  LEFT JOIN fact_visits v ON v.guest_id = g.guest_id
  GROUP BY g.home_state, g.guest_id
),
by_state AS (
  SELECT home_state, AVG(clv_usd) AS avg_clv_usd, COUNT(*) AS n_guests
  FROM per_guest
  GROUP BY home_state
)
SELECT * FROM by_state
ORDER BY avg_clv_usd DESC
LIMIT 10;

UPDATE fact_purchases 
set payment_method = replace(payment_method, 'Apple Pay', 'APPLE PAY')

commit

---------------------------------------------------------------------------------
WITH daily AS ( 
    SELECT 
        d.date_iso,
        d.day_name,
        d.is_weekend,
        COUNT(DISTINCT v.visit_id) AS daily_visits,
        SUM(v.spend_cents_clean/100.0) AS daily_spend_USD
    FROM dim_date d
    LEFT JOIN fact_visits v ON v.date_id = d.date_id
    WHERE v.spend_cents_clean IS NOT NULL
    GROUP BY d.date_iso, d.day_name, d.is_weekend
    ORDER BY d.date_iso
)
SELECT * FROM dim_date;


COMMIT


