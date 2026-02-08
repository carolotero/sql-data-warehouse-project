/*
================================================================================================
PRODUCT REPORT
================================================================================================
Purpose:
	- This report consolidates key product metrics and behaviors

Highlights:
	1. Gathers essential fields such as product name, category, subcategory, and cost.
	2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performer.
	3. Aggregates product-level metrics:
		- total orders
		- total sales
		- total quantity sold
		- total customers (unique)
		- lifespan (in months)
	4. Calculates valuable KPIs:
		- recency (months since last sale)
		- average  order revenue (AOR)
		- average montly revenue
================================================================================================
*/
CREATE VIEW gold.report_products AS
WITH base_query AS (
/*--------------------------------------------------------------------------------------------
1) Base Query: Retrieves core columns from tables
*/--------------------------------------------------------------------------------------------
	SELECT
	T1.order_number,
	T1.order_date,
	T1.customer_key,
	T1.sales_amount,
	T1.quantity,
	T2.product_key,
	T2.product_name,
	T2.category,
	T2.subcategory,
	T2.product_cost
	FROM [gold].[fact_sales] T1
	LEFT JOIN [gold].[dim_products] T2 ON T1.product_key = T2.product_key
	WHERE order_date IS NOT NULL
)

, product_aggregation AS (
/*--------------------------------------------------------------------------------------------
2) Product Aggregations: Summarize key metrics at the product level
*/--------------------------------------------------------------------------------------------
SELECT
	product_key,
	product_name,
	category,
	subcategory,
	product_cost,
	COUNT(DISTINCT(order_number)) AS total_orders,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT(customer_key)) AS total_customers,
	MAX(order_date) AS last_order_date,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
	ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity,0)),1) AS avg_selling_price
	FROM base_query
	GROUP BY product_key,
	product_name,
	category,
	subcategory,
	product_cost
)

SELECT
/*--------------------------------------------------------------------------------------------
3) Final Query: combines all products result into one output
*/--------------------------------------------------------------------------------------------
	product_key,
	product_name,
	category,
	subcategory,
	product_cost,
	last_order_date,
	DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
	CASE WHEN total_sales > 50000 THEN 'High-Performer'
		 WHEN total_sales >= 10000 THEN 'Mid-Range'
		 ELSE 'Low-Performer'
	END AS product_segment,
	lifespan,
	total_orders,
	total_sales,
	total_quantity,
	total_customers,
	avg_selling_price,
	CASE WHEN total_orders = 0 THEN 0
		 ELSE (total_sales / total_orders)
	END AS avg_order_revenue, ---Compute Average Order Revenue AOR
	CASE WHEN lifespan = 0 THEN total_sales
		 WHEN total_sales = 0 THEN 0
		 ELSE (total_sales / lifespan)
	END AS avg_monthly_revenue--Compute average monthly revenue
FROM product_aggregation
