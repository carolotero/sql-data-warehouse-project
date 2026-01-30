/*
===============================================================================
DDL Script: Create Gold Tables
===============================================================================
Script Purpose:
    This script creates views for the 'gold' layer in the data warehouse.
	The Gold layer represents the final dimension and fact tables (Star schema)

	Each view performs transformations and combines data from the Silver layer
	to produce a clean, enriched, and business-ready dataset.

Usage:
	- These views can be queried directly for analytics and reporting.
  
===============================================================================
*/
-- ===============================================================================
-- Create Dimension: gold.dim_customers
-- ===============================================================================
IF OBJECT('gold.dim_customers', 'V') IS NOT NULL
	DROP VIEW gold.dim_customers;
GO
	
CREATE VIEW gold.dim_customers AS
SELECT 
	ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key
	,T1.cst_id AS customer_id
	,T1.cst_key	AS customer_number
	,T1.cst_firstname AS first_name	
	,T1.cst_lastname AS last_name
	,T3.cntry AS country
	,T1.cst_marital_status AS marital_status
	,CASE WHEN T1.cst_gndr != 'N/A' THEN T1.cst_gndr ----CRM is the master for gender info
		  ELSE COALESCE(T2.gen, 'N/A')
	 END AS gender
	,T2.bdate AS birthdate
	,T1.cst_create_date AS create_date
FROM [silver].[crm_cust_info] T1
LEFT JOIN [silver].[erp_cust_az12] T2 ON T1.cst_key = T2.cid
LEFT JOIN [silver].[erp_loc_a101] T3 ON T1.cst_key = T3.cid;


-- ===============================================================================
-- Create Dimension: gold.dim_products
-- ===============================================================================
IF OBJECT('gold.dim_products', 'V') IS NOT NULL
	DROP VIEW gold.dim_products;
GO
CREATE VIEW gold.dim_products AS
SELECT
	ROW_NUMBER() OVER (ORDER BY prd_start_dt, prd_key) AS product_key
	,T1.prd_id AS product_id
	,T1.prd_key	AS product_number
	,T1.prd_nm AS product_name
	,T1.cat_id AS category_id	
	,T2.cat AS category
	,T2.subcat AS subcategory	
	,T2.maintenance AS maintenance
	,T1.prd_cost AS product_cost	
	,T1.prd_line AS product_line
	,T1.prd_start_dt AS product_start_date	
	,T1.prd_end_dt AS product_end_date
FROM [silver].[crm_prd_info] T1
LEFT JOIN [silver].[erp_px_cat_g1v2] T2 ON T1.cat_id = T2.id
WHERE T1.prd_end_dt IS NULL ---Filter out all historical data


-- ===============================================================================
-- Create Dimension: gold.fact_sales
-- ===============================================================================
IF OBJECT('gold.fact_sales', 'V') IS NOT NULL
	DROP VIEW gold.fact_sales;
GO
CREATE VIEW gold.fact_sales AS
SELECT
T1.sls_ord_num AS order_number
,T2.product_key
,T3.customer_key
,T1.sls_order_dt AS order_date	
,T1.sls_ship_dt	AS shipping_date
,T1.sls_due_dt AS due_date	
,T1.sls_sales AS sales_amount	
,T1.sls_quantity AS quantity	
,T1.sls_price AS price
FROM [silver].[crm_sales_details] T1
LEFT JOIN [gold].[dim_products] T2 ON T1.sls_prd_key = T2.product_number
LEFT JOIN [gold].[dim_customers] T3 ON T1.sls_cust_id = T3.customer_id
