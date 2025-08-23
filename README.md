# Supernova Theme Park Data Analysis 🎡
## Project Owner: 	[Ibrahima Diallo](https://www.linkedin.com/in/ibranova/) Data Analyst
### Business Problem
The Supernova theme park has experienced uneven guest satisfaction scores and fluctuating revenue streams over the past two quarters. Operational data reveals recurring complaints about long wait times, inconsistent ride availability due to maintenance issues, and overcrowding during peak hours. Meanwhile, the Marketing team struggles to understand which ticket types and promotional campaigns attract the most valuable guests who spend significantly on food, merchandise, and premium experiences. Leadership needs an evidence-based, cross-departmental plan to align operational efficiency, guest experience, and targeted marketing strategies to maximize both satisfaction and revenue.
### Stakeholders
- **Primary:** Park General Manager (GM) - Strategic decision-making and overall park performance
- **Supporting:** Operations Director - Staffing optimization and queue management
- **Supporting:** Marketing Director - Promotional campaigns and ticket mix optimization
### Database Overview
My analysis uses a star schema database with dimension tables for guests, tickets, and attractions, connected to fact tables capturing visits, ride events, and purchases. This start schema structure in this context enables us we an efficient analysis across multiple dimensions while maintaining data integrity through foreign key relationships. It basically allows us to write simple queries and improve our performance when joining tables. Also, Star schemas can effectively help to handle large datasets and scale to accommodate growing business data while maintaining efficiency.
### Schema Structure:
- **Dimension Tables:** `dim_guest`, `dim_ticket`, `dim_attraction`, `dim_date`
- **Fact Tables:** `fact_visits`, `fact_ride_events`, `fact_purchases`
<img width="2082" height="1200" alt="themedatabaseschema" src="https://github.com/user-attachments/assets/c27fb022-6f9f-47e1-8cff-981b91e481c3" />

## EDA (Exploratory Data Analysis)
Initially, my exploration revealed 47 total visits across the analysis period. I thought that before making any decisions, I needed to know if we're analyzing 47 visits or more because the preliminary insights don't give a definitive strategy. Next, I identified many significant data quality issues, including currency formatting inconsistencies. I decided to clean it and standardize the data because otherwise, we can't make good business recommendations. This directly impacts the GM's concern - fluctuating revenue streams. Next, I found 8 duplicate ride events and missing values in wait times and promotional codes, so I decided to delete the duplicate because lead to a wrong business decision. I prioritized these because they directly connect to the stated problems, and I wanted to make sure that I can thrust the data to the business problem. The EDA analysis identified key patterns in guest behavior, spending distributions, and operational delays that informed subsequent feature engineering.
My detailed analysis can be found here: [sql/01_eda.sql](https://github.com/ibranova/Mod3_Final_Project-Theme-Park-Analytics/blob/main/sql/01_eda.sql)
## Feature Engineering
Created strategic features to support stakeholder decision-making:
- `stay_minutes` - Calculated visit duration for Operations team to align staffing, maintenance, and entertainment scheduling with guest session patterns
The stay_minutes feature is important because the Operations team can use the session length 
and based on the number of customers they have every moment of the day, to plan how many staff they need,
when to schedule maintenance, and when to run entertainment so everything matches the customer’s stay.”
For instance, if the staff know that people stay on average 60 minutes in average and in the morning, they can use that data to better plan.
- `is_repeat_guest` - a flag identifying returning visitors for GM and Marketing to design targeted loyalty and retention programs
  The is_repeat_guest feature tells us if a guest has come back before. 
The General Manager and Marketing team use this information to segment guests and design loyalty/retention programs.”
This can use that column to find out if repeat visitors are increasing year to year
And the marketing team can identify the repeat guest and send them a thank-you note with a coupon for their next ride
Also, they can identify the behavior between new and repeat customers, because repeat customers tend to spend more on 
services based on their past experiences
- `spend_per_category` - Food vs merchandise spending breakdown to inform Marketing about category performance and discount strategies
  Stakeholders might care about identifying which categories drive the most revenue.
Also, show whether guests spend more on experiences (rides/games) or extras (food/merch).
It can inform the marketing team how to better prepare for campaigns like making a discount on low-performing categories
- `customers_lifetime_value` - Total guest spending across all visits to identify VIP guests and inform marketing resource allocation.
  Stakeholders  might care about identifying VIP guests who bring the most money over time.
Helps with loyalty programs offering discounts or memberships to keep high spenders returning.
This feature can support marketing allocation, to decide whether to focus on acquiring new guests or favorise existing ones.
This can also help with long-term planning.

  More details can be found here:[sql/03_features.sql](https://github.com/ibranova/Mod3_Final_Project-Theme-Park-Analytics/blob/main/sql/03_features.sql)

## CTEs & Window Functions
### Daily Performance Analysis
<img width="1017" height="457" alt="Screenshot 2025-08-22 at 11 42 00 PM" src="https://github.com/user-attachments/assets/84c7837f-fea2-4aec-bb57-d01a1df53063" />

### RFM Analysis with State-Level Ranking
<img width="1102" height="487" alt="Screenshot 2025-08-22 at 11 45 26 PM" src="https://github.com/user-attachments/assets/d82790a8-ce5f-4699-8798-bf5a220a7f70" />

More features can be found in the file: [sql/04_Ctes&Windows.sql](https://github.com/ibranova/Mod3_Final_Project-Theme-Park-Analytics/blob/main/sql/04_ctes_windows.sql)

## Visualizations
1. Daily Performance Analysis
<img width="1015" height="934" alt="daily" src="https://github.com/user-attachments/assets/19d81bd2-1c42-4af3-b7fc-ac43594eec39" />

   **Key Insights:** Weekdays (Monday-Tuesday) show higher attendance than weekends, with Monday July 7th recording peak traffic of 10+ visits. Revenue patterns follow attendance trends, indicating strong correlation between visitor volume and spending.
3. Wait Time vs Satisfaction Analysis
4. 
5. Customer Lifetime Value & Ticket Performance





