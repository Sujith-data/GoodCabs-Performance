# Business Request - 1: City-Level Fare and Trip Summary Report
#Generate a report that displays the total trips, average fare per km, average fare per trip, and the percentage contribution of each city's trips to the overall trips. 
#This report will help in assessing trip volume, pricing efficiency, and each city's contribution to the overall trip count.
# Fields:
# city_name, total_trips, avg_fare_per_km, avg_fare_per_trip, %_contribution_to_total_trips

WITH city_level_fare AS (
SELECT
	city_name,
	COUNT(trip_id) AS total_trips,
    ROUND(SUM(fare_amount)/SUM(distance_travelled_km),2) AS avg_fare_per_km,
    ROUND(SUM(fare_amount)/COUNT(trip_id)) AS avg_fare_per_trip
    FROM dim_city c
JOIN fact_trips t
	USING(city_id)
GROUP BY city_name
)
SELECT
	*,
    ROUND(total_trips *100 / (SELECT COUNT(trip_id) FROM fact_trips),2) AS pct_contribution_to_total_trips
FROM city_level_fare;

# Business Request - 2: Monthly City-Level Trips Target Performance Report
# Generate a report that evaluates the target performance for trips at the monthly and city level. For each city and month, 
# compare the actual total trips with the target trips and categorise the performance as follows:
# If actual trips are greater than target trips, mark it as "Above Target".
# If actual trips are less than or equal to target trips, mark it as "Below Target".
# Additionally, calculate the % difference between actual and target trips to quantify the performance gap.
# Fields:
 	#City_name, month name, actual_trips, target_trips, performance_status, % difference

WITH ActualTrip AS (
SELECT
	c.city_id,
	city_name,
    MONTHNAME(date) AS month_name,
    COUNT(trip_id) AS actual_trips
FROM dim_city c
JOIN fact_trips t
	USING(city_id)
GROUP BY city_id, city_name, month_name
),
TargetTrips AS (
SELECT
	MONTHNAME(month) AS month_name,
	tm.city_id,
	total_target_trips
FROM targets_db.monthly_target_trips tm
JOIN fact_trips t
	ON tm.city_id = t.city_id AND tm.month = t.date
GROUP BY month,
	tm.city_id
)
SELECT 
	atr.city_name,
    tt.month_name,
    atr.actual_trips,
    total_target_trips,
    CASE 
		WHEN actual_trips > total_target_trips THEN "Above Target"
		ELSE "Below Target"
	END AS performance_status,
    CONCAT(ROUND((actual_trips - total_target_trips)/total_target_trips *100,2),"%") AS difference
FROM ActualTrip atr
JOIN TargetTrips tt 
ON atr.city_id = tt.city_id AND atr.month_name = tt.month_name;


    
# Business Request - 3: City-Level Repeat Passenger Trip Frequency Report
# Generate a report that shows the percentage distribution of repeat passengers by the number of trips they have taken in each city. 
# Calculate the percentage of repeat passengers who took 2 trips, 3 trips, and so on, up to 10 trips.
# Each column should represent a trip count category, displaying the percentage of repeat passengers who fall into that category out of the total repeat passengers for that city.
# This report will help identify cities with high repeat trip frequency, which can indicate strong customer loyalty or frequent usage patterns.
# Fields: city_name, 2-Trips, 3-Trips, 4-Trips, 5-Trips, 6-Trips, 7-Trips, 8-Trips, 9-Trips, 10-Trips
    
WITH CityTotalPassengers AS (
  SELECT
    city_name,
    SUM(repeat_passenger_count) AS total_repeat_passengers
  FROM
    dim_city c
  JOIN dim_repeat_trip_distribution t
    USING (city_id)
  GROUP BY city_name
)
SELECT
  c.city_name,
  CONCAT(ROUND((SUM(CASE WHEN trip_count = 2 THEN repeat_passenger_count ELSE 0 END) / ctp.total_repeat_passengers) * 100, 2),"%") AS "2-Trips",
  CONCAT(ROUND((SUM(CASE WHEN trip_count = 3 THEN repeat_passenger_count ELSE 0 END) / ctp.total_repeat_passengers) * 100, 2),"%") AS "3-Trips",
  CONCAT(ROUND((SUM(CASE WHEN trip_count = 4 THEN repeat_passenger_count ELSE 0 END) / ctp.total_repeat_passengers) * 100, 2),"%") AS "4-Trips",
  CONCAT(ROUND((SUM(CASE WHEN trip_count = 5 THEN repeat_passenger_count ELSE 0 END) / ctp.total_repeat_passengers) * 100, 2),"%") AS "5-Trips",
  CONCAT(ROUND((SUM(CASE WHEN trip_count = 6 THEN repeat_passenger_count ELSE 0 END) / ctp.total_repeat_passengers) * 100, 2),"%") AS "6-Trips",
  CONCAT(ROUND((SUM(CASE WHEN trip_count = 7 THEN repeat_passenger_count ELSE 0 END) / ctp.total_repeat_passengers) * 100, 2),"%") AS "7-Trips",
  CONCAT(ROUND((SUM(CASE WHEN trip_count = 8 THEN repeat_passenger_count ELSE 0 END) / ctp.total_repeat_passengers) * 100, 2),"%") AS "8-Trips",
  CONCAT(ROUND((SUM(CASE WHEN trip_count = 9 THEN repeat_passenger_count ELSE 0 END) / ctp.total_repeat_passengers) * 100, 2),"%") AS "9-Trips",
  CONCAT(ROUND((SUM(CASE WHEN trip_count = 10 THEN repeat_passenger_count ELSE 0 END) / ctp.total_repeat_passengers) * 100, 2),"%") AS "10-Trips"
FROM
  dim_city c
JOIN dim_repeat_trip_distribution t
  USING (city_id)
JOIN CityTotalPassengers ctp
  ON c.city_name = ctp.city_name
GROUP BY
  c.city_name;    
    
    


# Business Request - 4: Identify Cities with Highest and Lowest Total New Passengers
# Generate a report that calculates the total new passengers for each city and ranks them based on this value. 
# Identify the top 3 cities with the highest number of new passengers as well as the bottom 3 cities with the lowest number of new passengers, categorising them as "Top 3" or "Bottom 3" accordingly.
# Fields city_name, total new_passengers, city_category ("Top 3" or "Bottom 3")

WITH passenger_ranking AS (
SELECT 
	city_name,
    SUM(new_passengers) AS total_new_passengers,
    ROW_NUMBER() OVER(ORDER BY SUM(new_passengers)DESC) AS rank_desc,
    ROW_NUMBER() OVER(ORDER BY SUM(new_passengers)ASC) AS rank_asc
FROM dim_city c
JOIN fact_passenger_summary p
	USING(city_id)
GROUP BY city_name
)
SELECT 
	city_name,
    total_new_passengers,
    CASE
		WHEN rank_desc <=3 THEN "Top 3"
        WHEN rank_asc <=3 THEN "Bottom 3"
	END AS city_category
FROM passenger_ranking
HAVING city_category IS NOT NULL;


# Business Request - 5: Identify Month with Highest Revenue for Each City
# Generate a report that identifies the month with the highest revenue for each city. 
# For each city, display the month_name, the revenue amount for that month, and the percentage contribution of that month's revenue to the city's total revenue.
# Fields city_name, highest_revenue month, revenue   percentage_contribution (%)


WITH CityMonthRevenue AS (
SELECT
	city_name,
    MONTHNAME(date) AS month_name,
    SUM(fare_amount) AS revenue,
    RANK() OVER(PARTITION BY city_name ORDER BY SUM(fare_amount) DESC) AS rn
FROM dim_city c
JOIN fact_trips t
	USING(city_id)
GROUP BY city_id, city_name, MONTHNAME(date)
),
CityTotalRevenue AS (
SELECT
    city_name,
    SUM(revenue) AS total_revenue
  FROM
    CityMonthRevenue
  GROUP BY
    city_name
)
SELECT 
	cmr.city_name,
    cmr.month_name AS highest_revenue_month,
	cmr.revenue,
	CONCAT(ROUND((cmr.revenue / ctr.total_revenue) *100,2),"%") AS percentage_contribution
FROM CityMonthRevenue cmr
JOIN CityTotalRevenue ctr
	USING(city_name)
WHERE rn = 1;


# Business Request - 6: Repeat Passenger Rate Analysis
# Generate a report that calculates two metrics:
# 1. Monthly Repeat Passenger Rate: Calculate the repeat passenger rate for each city and month by comparing the number of repeat passengers to the total passengers.
# 2. City-wide Repeat Passenger Rate: Calculate the overall repeat passenger rate for each city, considering all passengers across months.
# These metrics will provide insights into monthly repeat trends as well as the overall repeat behaviour for each city.
# Fields: city_name   month   total_passengers   repeat_passengers   monthly_repeat_passenger_rate (%): 
# Repeat passenger rate at the city and month level   city_repeat_passenger_rate (%): Overall repeat passenger rate for each city, aggregated across months

WITH PassengerMonth AS(
SELECT city_name, MONTHNAME(ps.month) AS month_name,
	SUM(total_passengers) AS total_passengers,
    SUM(repeat_passengers) AS repeat_passengers,
    SUM(repeat_passengers)/SUM(total_passengers)*100 AS monthly_repeat_passenger_rate
FROM dim_city c
JOIN fact_passenger_summary ps
	USING(city_id)
GROUP BY city_name , ps.month
),
CityPassenger AS(
SELECT city_name,
	SUM(total_passengers) AS total_passengers,
    SUM(repeat_passengers) AS repeat_passengers,
    SUM(repeat_passengers)/SUM(total_passengers)*100 AS city_repeat_passenger_rate
FROM dim_city c
JOIN fact_passenger_summary ps
	USING(city_id)
GROUP BY city_name
)
SELECT 
    pm.city_name,
    month_name,
    pm.total_passengers,
    pm.repeat_passengers,
    pm.monthly_repeat_passenger_rate,
    cp.city_repeat_passenger_rate
FROM PassengerMonth pm
JOIN CityPassenger cp USING (city_name)


