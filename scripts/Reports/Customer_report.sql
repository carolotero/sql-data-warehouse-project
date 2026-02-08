/*
================================================================================================
CUSTOMER REPORT
================================================================================================
Purpose:
	- This report consolidates key customer metrics and behaviors

Highlights:
	1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
	3. Aggregates customer-level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- lifespan (in months)
	4. Calculates valuable KPIs:
		- recency (months since last order)
		- average  order value
		- average montly spend
================================================================================================
*/
CREATE VIEW gold.report_customers AS
WITH base_query AS (
/*--------------------------------------------------------------------------------------------
1) Base Query: Retrieves core columns from tables
*/--------------------------------------------------------------------------------------------
SELECT
T1.order_number,
T1.product_key,
T1.order_date,
T1.sales_amount,
T1.quantity,
T2.customer_key,
T2.customer_number,
CONCAT(T2.first_name, ' ', T2.last_name) AS customer_name,
DATEDIFF(YEAR, T2.birthdate, GETDATE()) AS customer_age
FROM [gold].[fact_sales] T1
LEFT JOIN [gold].[dim_customers] T2 ON T1.customer_key = T2.customer_key
WHERE order_date IS NOT NULL
)

, customer_aggregation AS (
/*--------------------------------------------------------------------------------------------
2) Customer Aggregations: Summarize key metrics at the customer level
*/--------------------------------------------------------------------------------------------
SELECT
customer_key,
customer_number,
customer_name,
customer_age,
COUNT(DISTINCT(order_number)) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS quantity_purchased,
COUNT(DISTINCT(product_key)) AS total_products,
MAX(order_date) AS last_order_date,
DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM base_query
GROUP BY customer_key,
customer_number,
customer_name,
customer_age
)

SELECT
/*--------------------------------------------------------------------------------------------
3) Segments customers: into categories (VIP, Regular, New) and age groups.
*/--------------------------------------------------------------------------------------------
customer_key,
customer_number,
customer_name,
customer_age,
CASE WHEN customer_age < 20 THEN 'Under 20'
	 WHEN customer_age BETWEEN 20 AND 29 THEN '20-29'
	 WHEN customer_age BETWEEN 30 AND 39 THEN '30-39'
	 WHEN customer_age BETWEEN 40 AND 49 THEN '40-49'
	 ELSE '50 and above'
END AS age_group,
CASE WHEN total_sales > 5000  AND lifespan >= 12 THEN 'VIP'
	 WHEN total_sales <= 5000 AND lifespan >= 12 THEN 'Regular'
	 ELSE 'New'
END AS customer_segment,
last_order_date,
DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
total_orders,
total_sales,
quantity_purchased,
total_products,
lifespan,
CASE WHEN total_sales = 0 THEN 0
     ELSE (total_sales / total_orders)
END AS avg_order_value, ---Compute AVO
CASE WHEN lifespan = 0 THEN total_sales
	 WHEN total_sales = 0 THEN 0
     ELSE (total_sales / lifespan)
END AS avg_monthly_spend--Compute average monthly spending
FROM customer_aggregation
