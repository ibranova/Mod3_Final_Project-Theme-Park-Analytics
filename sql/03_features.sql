-- Two from the list + two custom. Stakeholder rationale in comments.

-- stay_minutes: Ops cares to align staffing, maintenance, and entertainment windows to session length.
-- First let's create a view to help us get the avg wait per visit
CREATE VIEW IF NOT EXISTS v_visit_waits AS
SELECT
  revn.visit_id,
  AVG(revn.wait_minutes) AS avg_wait_minutes
FROM fact_ride_events revn
GROUP BY revn.visit_id;
-- we can use this view to find out how long on average it's take to wait for each visit

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
  FROM fact_visits v;
/*“The stay_minutes feature is important because the Operations team can use session length 
and base on the number of customers they have every moment of the day to plan how many staff they need,
when to schedule maintenance, and when to run entertainment so everything matches the customer’s stay.”
For instance if the staff know that people stay on average 60 munites in average and in the morning the can use that data to better plan.*/

-- is_repeat_guest: GM/Marketing segment for loyalty and retention programs.
WITH repeat_flag AS (
  -- is_repeat_guest based on number of visits for the guest across all time
  SELECT
    visit_id,
    CASE WHEN visit_count > 1 THEN 'Repeted' ELSE 'Non-repeted' END AS is_repeat_guest
  FROM (
    SELECT
      v.visit_id,
      COUNT(*) OVER (PARTITION BY v.guest_id) AS visit_count
    FROM fact_visits v
  )
)

/* “The is_repeat_guest feature tells us if a guest has come back before. 
The General Manager and Marketing team use this information to segment guests and design loyalty/retention programs.”
This can use that column to find out if repeat visitors are increasing year to year
And The maketing team can identify the repeated guest and send them a thank you note with a coupon for their next ride
Also the can identify the behavior of between new and repeted customer, because repeted customers tend to spend more on 
services based on their past experiences*/

-- Let's create another feature as a table to classify the total spend per category for each customers
create table spend_per_category AS
SELECT g.guest_id,
       SUM(CASE WHEN p.category = 'Food' THEN p.amount_cents_clean ELSE 0 END) AS food_spend,
       SUM(CASE WHEN p.category= 'Merch' THEN p.amount_cents_clean ELSE 0 END) AS merch_spend
FROM dim_guest g
JOIN fact_visits f ON f.guest_id = g.guest_id
JOIN fact_purchases p ON f.visit_id = p.visit_id
GROUP BY g.guest_id;

/* Stakeholders might care about identifying which categories drive the most revenue.
Also Show whether guests spend more on experiences (rides/games) or extras (food/merch).
It can informs the marketing team how to bette prepare for campaigns like making a discount on low-performing categories */


-- Last, creating a view for the stakeholders to see their customers lifetime values is good a feature
CREATE VIEW if not EXISTS customers_life_time_value AS
SELECT g.guest_id, first_name, last_name, 
       SUM(p.amount_cents_clean) AS lifetime_value
FROM dim_guest g
JOIN fact_visits f ON f.guest_id = g.guest_id
JOIN fact_purchases p ON f.visit_id = p.visit_id
GROUP BY g.guest_id
ORDER BY lifetime_value DESC;

/*Stakeholders  might care about identifies VIPs guests who bring the most money over time.
Helps with loyalty programs offering discounts or memberships to keep high spenders returning.
This feature can supports marketing allocation, to decide whether to focus on acquiring new guests or favorise existing ones.
This can also help for long-term planning.*/


--An addtionanly feature to identify the 3 top populare attraction by wait time
WITH ride AS(
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

/*I found that the guests spend more when they have to wait for at least 30 minutes for a ride, meaning the most popular ride by wait minutes in the park is the tiny trucks.
 Its seems like people love riding trucks. Ops should add more staff for that attraction to accelerate the services and help the guest to have a better experience.
Also, the marketing team could run more ticket promotions for the recurring customers to push them to ride more and they can make other discounts for them in other attractions to make them spend more money in the park. */