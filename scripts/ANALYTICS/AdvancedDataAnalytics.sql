--- 7 CHANGE OVER TIME (Trends) ---date dimension
--- Analyze sales performance over time
--- by year
SELECT
YEAR(order_date) AS order_year,
SUM(sales_amount) AS Total_revenue,
COUNT(DISTINCT(customer_key)) AS number_customers,
SUM(quantity) AS items
FROM [gold].[fact_sales]
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date)

--- by month


SELECT
MONTH(order_date) AS order_month,
SUM(sales_amount) AS Total_revenue,
COUNT(DISTINCT(customer_key)) AS number_customers,
SUM(quantity) AS items
FROM [gold].[fact_sales]
WHERE order_date IS NOT NULL AND YEAR(order_date) BETWEEN '2011' AND '2013'
GROUP BY MONTH(order_date)
ORDER BY MONTH(order_date)


--- by year and month
SELECT
YEAR(order_date) AS order_year,
MONTH(order_date) AS order_month,
SUM(sales_amount) AS Total_revenue,
COUNT(DISTINCT(customer_key)) AS number_customers,
SUM(quantity) AS items
FROM [gold].[fact_sales]
WHERE order_date IS NOT NULL AND YEAR(order_date) BETWEEN '2011' AND '2013'
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date)

--- see the date grouped by month
SELECT
DATETRUNC(MONTH, order_date) AS order_date,
SUM(sales_amount) AS Total_revenue,
COUNT(DISTINCT(customer_key)) AS number_customers,
SUM(quantity) AS items
FROM [gold].[fact_sales]
WHERE order_date IS NOT NULL AND YEAR(order_date) BETWEEN '2011' AND '2013'
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY DATETRUNC(MONTH, order_date)


--- see the date grouped by year
SELECT
DATETRUNC(YEAR, order_date) AS order_date,
SUM(sales_amount) AS Total_revenue,
COUNT(DISTINCT(customer_key)) AS number_customers,
SUM(quantity) AS items
FROM [gold].[fact_sales]
WHERE order_date IS NOT NULL AND YEAR(order_date) BETWEEN '2011' AND '2013'
GROUP BY DATETRUNC(YEAR, order_date)
ORDER BY DATETRUNC(YEAR, order_date)


--- Changing the format
SELECT
FORMAT(order_date, 'yyyy-MMM') AS order_date,
SUM(sales_amount) AS Total_revenue,
COUNT(DISTINCT(customer_key)) AS number_customers,
SUM(quantity) AS items
FROM [gold].[fact_sales]
WHERE order_date IS NOT NULL AND YEAR(order_date) BETWEEN '2011' AND '2013'
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM')



--- 8 CUMULATIVE ANALYSIS -Date dimension
--- calculate the total sales per month
--- and the running total of sales over time

SELECT
order_month,
total_Sales,
SUM(total_Sales) OVER (ORDER BY order_month) AS running_total_Sales,
SUM(total_Sales) OVER (PARTITION BY YEAR(order_month) ORDER BY order_month) AS running_total_Sales_byYear
FROM
(
SELECT
DATETRUNC(MONTH,order_date) AS order_month,
SUM(sales_amount) AS total_Sales
FROM [gold].[fact_sales]
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH,order_date)
)T


--- running sales by year

SELECT
order_month,
total_Sales,
SUM(total_Sales) OVER (ORDER BY order_month) AS running_total_Sales,
AVG(average_price) OVER (ORDER BY order_month) AS moving_average_price
FROM
(
SELECT
DATETRUNC(YEAR,order_date) AS order_month,
SUM(sales_amount) AS total_Sales,
AVG(price) AS average_price
FROM [gold].[fact_sales]
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR,order_date)
)T


--- 9 PERFORMACE ANALYSIS
--- Analyze the yearly performance of products
--- by comparing each product's sales to both: its average sales performance and the previous year's sales.

SELECT
order_date,
product_name,
total_Sales,
AVG(total_Sales) OVER(ORDER BY order_Date) AS moving_Average_sales
FROM
(
SELECT
YEAR(T1.order_date) AS order_date,
T2.product_name,
SUM(T1.sales_amount) AS total_Sales
FROM [gold].[fact_sales] T1
LEFT JOIN [gold].[dim_products] T2 ON T1.product_key = T2.product_key
WHERE YEAR(T1.order_date) IS NOT NULL 
GROUP BY YEAR(T1.order_date), T2.product_name)T


----cte
WITH yearly_product_Sales AS (
	SELECT
	YEAR(T1.order_date) AS order_date,
	T2.product_name,
	SUM(T1.sales_amount) AS total_Sales
	FROM [gold].[fact_sales] T1
	LEFT JOIN [gold].[dim_products] T2 ON T1.product_key = T2.product_key
	WHERE YEAR(T1.order_date) IS NOT NULL 
	GROUP BY YEAR(T1.order_date), T2.product_name
)
SELECT
order_date,
product_name,
total_Sales,
AVG(total_Sales) OVER(PARTITION BY product_name) AS moving_Average_sales,
total_Sales - AVG(total_Sales) OVER(PARTITION BY product_name) AS Diff_avg,
CASE WHEN (total_Sales - AVG(total_Sales) OVER(PARTITION BY product_name)) < 0 THEN 'Below average' 
	WHEN (total_Sales - AVG(total_Sales) OVER(PARTITION BY product_name)) > 0 THEN 'Above average' 
	ELSE 'Average' 
	END AS 'Status',
LAG(total_Sales) OVER(PARTITION BY product_name ORDER BY order_date) AS previous_year,
total_Sales - LAG(total_Sales) OVER(PARTITION BY product_name ORDER BY order_date) AS Diff_previous_year,
CASE WHEN (total_Sales - LAG(total_Sales) OVER(PARTITION BY product_name ORDER BY order_date)) < 0 THEN 'Decrease' 
	WHEN (total_Sales - LAG(total_Sales) OVER(PARTITION BY product_name ORDER BY order_date)) > 0 THEN 'Increase' 
	WHEN (total_Sales - LAG(total_Sales) OVER(PARTITION BY product_name ORDER BY order_date)) IS NULL THEN 'No previous data'
	ELSE 'No change' 
	END AS 'Previous_year_change'
FROM yearly_product_Sales


--- 10 PART TO WHOLE -- PROPORTIONAL ANALYSIS
--- Which categories contribute the most to the overall sales

WITH category_sales AS (
	SELECT
	T2.category,
	SUM(T1.sales_amount) AS total_Sales
	FROM [gold].[fact_sales] T1
	LEFT JOIN [gold].[dim_products] T2 ON T1.product_key = T2.product_key
	GROUP BY T2.category
)
SELECT
category,
total_Sales,
SUM(total_Sales) OVER() AS overall_Sales,
CONCAT(ROUND(CAST(total_Sales AS FLOAT) / SUM(total_Sales) OVER() *100, 2), '%' ) AS Proportion_over_sales
FROM category_sales
ORDER BY total_Sales DESC


--- 11 DATA SEGMENTATION --CORRELATION BETWEEN TWO MEASURES
--- /*Segment products into cost ranges and count how many products fall into each segment*/

WITH cost_categories AS (
SELECT 
product_key,
product_name,
product_cost,
CASE WHEN product_cost < 100  THEN 'Below 100'
	WHEN product_cost BETWEEN 100 AND 500 THEN '100-500'
	WHEN product_cost BETWEEN 500 AND 1000 THEN '500-1000'
	ELSE 'Above 1000'
END AS cost_range,
CASE WHEN product_cost < 100  THEN '1'
	WHEN product_cost BETWEEN 100 AND 500 THEN '2'
	WHEN product_cost BETWEEN 500 AND 1000 THEN '3'
	ELSE '4'
END AS order_categories
FROM [gold].[dim_products]
)
SELECT
order_categories,
cost_range,
COUNT(product_key) AS products
FROM cost_categories
GROUP BY order_categories,cost_range
ORDER BY order_categories

--- Group customers into three segments based on their spending behavior
/*
VIP: at least 12 months of history and spending more than 5000
Regular: at least 12 months of history and spending 5000 or less
New: lifespan less than 12 months.
*/

WITH customer_segments AS (
SELECT 
customer_key,
SUM(sales_amount) AS total_Sales,
MIN(order_date) AS mindate, 
MAX(order_date) AS maxdate,
DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS months_hystory
FROM [gold].[fact_sales]
GROUP BY customer_key
)
SELECT
CASE WHEN total_Sales > 5000  AND months_hystory >= 12 THEN 'VIP'
	WHEN total_Sales <= 5000 AND months_hystory >= 12 THEN 'Regular'
	ELSE 'New'
END AS segments,
COUNT(DISTINCT(customer_key)) AS customers
FROM customer_segments
GROUP BY CASE WHEN total_Sales > 5000  AND months_hystory >= 12 THEN 'VIP'
	WHEN total_Sales <= 5000 AND months_hystory >= 12 THEN 'Regular'
	ELSE 'New' END

	------INSTEAD OF REPEATING EVERYTHING IN THE GROUP BY CLAUSULE

WITH customer_segments AS (
SELECT 
customer_key,
SUM(sales_amount) AS total_Sales,
MIN(order_date) AS mindate, 
MAX(order_date) AS maxdate,
DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS months_hystory
FROM [gold].[fact_sales]
GROUP BY customer_key
)

SELECT 
segments,
COUNT(DISTINCT(customer_key)) AS customers
FROM (
	SELECT
	CASE WHEN total_Sales > 5000  AND months_hystory >= 12 THEN 'VIP'
		WHEN total_Sales <= 5000 AND months_hystory >= 12 THEN 'Regular'
		ELSE 'New'
	END AS segments,
	customer_key
	FROM customer_segments)T
GROUP BY segments
ORDER BY customers DESC
