-- CTEs + Window Functions with AWES comments

-- 1) Daily performance: 
-- First let's build a daily CTE and running totals to identify top 3 peak days
WITH daily AS ( 
 SELECT -- get the date, the day_name, is_weekend, count the daily visit and return the total daily revenue for each day
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
  running AS( -- Knowing the total daily revenue for each day above, now we can get the running total for daily visit and daily total spend
   SELECT
    *,
    SUM(daily_visits) OVER (ORDER BY date_iso) AS visits_running_total,
    SUM(daily_spend_USD) OVER (ORDER BY date_iso) AS spend_running_total
  FROM daily
  )
  SELECT * FROM running ORDER BY date_iso;
/*This query reveals that there are 47 visits in total from july 1st to july 8th with more than 10 visits on monday july 7th. 
And with a total revenue of 4618 USD, showing that weekend had more revenue than week-days*/


-- Top 3 peak days by visits
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
    RANK() OVER (ORDER BY daily_visits DESC) AS rnk -- The rank() window function here rank the day wiht the most visit showing gap after the tie which emphasise the position.
  FROM daily
)
WHERE rnk <= 3
ORDER BY daily_visits DESC;
/*
This query reveals that the are more visits in weekdays that the weekend, so OPS staffing should preprape to receive guests in peak days like monday. 
“the Operations team can use session length and base on the number of customers they have every the day to plan how many staff they need,
when to schedule maintenance, and when to run entertainment so everything matches the customer’s stay.”
For instance if the staff know that thet will have 100 people on mondays, they will add more staff to better the customers. 
So Identifying peak days is essential for Ops to align staffing, maintenance, and entertainment windows to session length.*/

-- 2) Let's calculates Recency, Frequency, and Monetary value for each guest and ranks them by their total spend (CLV proxy) within their home state.

WITH max_date AS (
  SELECT MAX(visit_date) AS max_visit_date FROM fact_visits -- the last vistdate 
),
per_guest AS ( -- get the guest_id, first_name, last_name, home_state, first and last visit date for each guest along with their total spending in USD.
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
rfm AS ( -- get the numbers of days since the last visit
  SELECT
    p.*,
    CAST((JULIANDAY((SELECT max_visit_date FROM max_date)) - JULIANDAY(p.last_visit)) AS INTEGER) AS recency_days
  FROM per_guest p
)
SELECT -- this query rank each customer within their home state.
  r.*,
  DENSE_RANK() OVER (PARTITION BY r.home_state ORDER BY r.clv_USD DESC) AS clv_rank_in_state
FROM rfm r
ORDER BY clv_USD DESC;

/*-- Q2: RFM & CLV for Guest Segmentation
This query calculates Recency, Frequency, and Monetary value for each guest and ranks them by their total spend (CLV proxy) within their home state.
It's helps to identify high-value customers in specific regions, and help preparing for targeted marketing campaigns.
For instance we can send exclusive offers to our top-spending guests in 'CA' and 'NY' to encourage repeat visits.
Overall Segmenting guests by value and location allows for more effective and personalized marketing strategy*/



-- 3) Behavior change: LAG to compute spend delta per guest visit
WITH ordered_visits AS (
  SELECT
    v.guest_id,
    v.visit_id,
    v.visit_date,
    vv.spend_usd, -- spend in USD get from the view v_visit_spend_dollar
    v.ticket_type_id,
    v.party_size,
    d.day_name,
    LAG(vv.spend_usd) OVER (PARTITION BY v.guest_id ORDER BY v.visit_date) AS prev_spend
  FROM fact_visits v
  LEFT JOIN dim_date d ON d.date_id = v.date_id
  LEFT JOIN v_visit_spend_dollars vv ON v.visit_id = vv.visit_id
),
deltas AS ( -- 
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

/*This query takes all visits and orders them by guest and date.
Next, it's uses LAG() window function to look at the previous spend of the same guest.
Next, calculates the change in spend between this visit and the previous one, the delta_spend.
if it's Positive, they spent more than last time, otherwise they spent less.
Also, group the party_size into bucket which help to analyse wether small or big group affect changes in spending. 
Last, it's groups the data by ticket type, day of the week, and party size bucket, calculates the average change in spending (avg_delta_spend) for each combination.
and filters out the first visit per guest (because they don’t have a previous spend).

This query help us understand how much people spend and what make them spend more or less since their last visit.
The marketing team care about the insights comming from query because they can use it to push marketing campaigns. 
For instance, this query reveals that the average spending is higher one "Day-pass" and 'Family-pack' on the weekends.
So, based on that information the markenting team can push promotions on the weekends to bost spending. 
overall it inform, which kinds of guests are spending more than they did last time, and under what conditions?*/

-- 4) Ticket switching: detect if a guest switched away from their first ticket type
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
/*In this query we are finding the sequence of visits per guest.
For each guest, we list all their visits. We also verify the ticket type name (ticket_type_name) for each visit.
Using FIRST_VALUE() window function  OVER (PARTITION BY v.guest_id ORDER BY v.visit_date), we capture the very first ticket type that guest ever purchased like "Day-pass", or "VIP").
the second CTE checks if the guest ever switched from their first ticket type to another ticket type.
If so, it return the guest showing what the first ticket type actually was and the switch tikets 
This is important and takeholders (marketing, sales, operations) care because it tells them if customers are progressing in value or dropping down in spend
For instance, if 20 customer start with day ticket and swithch to VIP, Marketing can double down on campaigns that encourage first-time visitors to upgrade.
Overall, it's help the business identify new customer and encourage them to spend more*/