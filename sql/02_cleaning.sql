-- 02_cleaning.sql — coercions, duplicates, key validation, missingness handling

-- A) Currency coercion: convert messy text to integer cents (ignore truly empty)
-- Add columns once (idempotent pattern: try-catch not available; ensure they don't already exist)
-- If these ALTERs fail due to existing columns, comment them out and re-run from WITH clauses.

ALTER TABLE fact_visits    ADD COLUMN spend_cents_clean   INTEGER;
ALTER TABLE fact_purchases ADD COLUMN amount_cents_clean  INTEGER;

-- Visits: compute cleaned cents
WITH c AS (
  SELECT
    rowid AS rid,
    REPLACE(REPLACE(REPLACE(REPLACE(UPPER(COALESCE(total_spend_cents,'')),
      'USD',''), '$',''), ',', ''), ' ', '') AS cleaned
  FROM fact_visits
)

UPDATE fact_visits
SET spend_cents_clean = CAST((SELECT cleaned FROM c WHERE c.rid = fact_visits.rowid) AS INTEGER)
WHERE LENGTH((SELECT cleaned FROM c WHERE c.rid = fact_visits.rowid)) > 0;

-- Purchases: same approach as above. 
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

-- Let's create two views to convert cents to dollars for the 'visit_spend and purchase_amount' columns
-- these views will help us visulize the columns for a quick inspection
CREATE VIEW IF NOT EXISTS v_visit_spend_dollars AS
SELECT visit_id, spend_cents_clean/100.0 AS spend_usd
FROM fact_visits;

CREATE VIEW IF NOT EXISTS v_purchase_amount_dollars AS
SELECT purchase_id, amount_cents_clean/100.0 AS amount_usd
FROM fact_purchases;

-- B) Exact duplicates in fact_ride_events
SELECT COUNT(*) AS duplicate_groups
FROM (
  SELECT visit_id, attraction_id, ride_time, wait_minutes, satisfaction_rating, photo_purchase, COUNT(*) AS c
  FROM fact_ride_events
  GROUP BY visit_id, attraction_id, ride_time, wait_minutes, satisfaction_rating, photo_purchase
  HAVING COUNT(*) > 1
);
-- I found 8 duplicates values in the whole table fact_ride_events, 2 values in each columns. 
/*I think we can delete those duplicates values because it can affect our analyses, like if we are counting by number of visit for each attractions,
 we can count it twice without knowing because of the duplicate */

-- Strategy to keep the earliest rowid per duplicate group and delete the rest
/* I can use a window function to rank the values by selecting unique rows and  assigning a row number and then filtering for ROW_NUMBER() > 1. 
and then delete the rest of the values that are duplicated */
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

-- C) Validate keys (orphan checks for all the PK/FK combination accross the table).
/* Orphans are rows in a child table that reference a non-existent primary key in a parent table. 
This situation happens when a reference is maintained, sometimes when a parent table has deleted rows record without deleting the same row reference inside the child table. 
ex: In this case we can have a guest_id deleted in the parent table dim_guest, with deleting the same row in child table fact_visit */ 

-- Orphan visits (guest_id not in dim_guest) — should be zero
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

/*Refection: There are no orpharns for all the PK/FK combination inside all the table, 
so we are sure than each parent table has the it Primary key in the child table.
This will make sure than we get the information we want when join those table together. 
It's a good practice to confirm that a foreign key always exit in child tables during when cleaning the data.*/


-- D) Handling missing values / normalization
-- Example: Set non-positive waits to NULL; this is best practice that just guessing 
UPDATE fact_ride_events
SET wait_minutes = NULL
WHERE wait_minutes IS NOT NULL AND wait_minutes < 0;
/* This ensure that we don't have a negative waiting time, making sure that all values can be used for calculation, like the 
Average waiting time for each attraction, also help us communicate insights clearly  */

-- Normalize promotion_code for analysis
ALTER TABLE fact_visits ADD COLUMN promotion_code_norm TEXT;
UPDATE fact_visits
SET promotion_code_norm = NULLIF(TRIM(UPPER(COALESCE(promotion_code,''))), '');

UPDATE fact_visits
SET promotion_code_norm = REPLACE(promotion_code_norm, 'SUMMER-25', 'SUMMER25'); 
-- To make sure that the text is the same inside all the records, so if we want to filter by the 'promotion code' we don't miss any row.  

-- Report how many values were cleaned/normalized (example)
SELECT
  (SELECT COUNT(*) FROM fact_ride_events WHERE wait_minutes IS NULL) AS waits_null_after_clean,
  (SELECT COUNT(*) FROM fact_visits WHERE promotion_code_norm IS NULL) AS promo_nulls_after_norm;
-- we have 67 null values in the filed 'waiting time' and 14 in the filed 'code promo'
