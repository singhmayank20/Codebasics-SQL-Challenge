use gdb023;
-- (1) list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT DISTINCT market
FROM dim_customer
WHERE customer = 'Atliq Exclusive'
AND region = 'APAC' ;

-- (2) percentage of unique product increase in 2021 vs. 2020

WITH unique_products_2020 AS (
SELECT COUNT(DISTINCT product_code) as unique_products_2020
FROM fact_sales_monthly
WHERE fiscal_year = 2020
), unique_products_2021 AS (
SELECT COUNT(DISTINCT product_code) as unique_products_2021
FROM fact_sales_monthly
WHERE fiscal_year = 2021
)
SELECT
unique_products_2020,
unique_products_2021,
ROUND((unique_products_2021 - unique_products_2020) / unique_products_2020 * 100, 2) AS percentage_chg
FROM
unique_products_2020
CROSS JOIN
unique_products_2021;

-- OR

WITH cte AS ( SELECT
COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END) AS unique_products_2020,
COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) AS unique_products_2021
FROM fact_sales_monthly )
SELECT unique_products_2020, unique_products_2021,
ROUND((unique_products_2021 - unique_products_2020)/unique_products_2020 * 100,2) AS percentage_chg
FROM cte;

-- (3) all the unique product counts for each segment and sort them in descending order of product counts
SELECT segment, COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- (4) Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?

WITH cte AS (
    SELECT 
        b.segment,
        COUNT(DISTINCT a.product_code) as product_count,
        a.fiscal_year
    FROM fact_sales_monthly a
    JOIN dim_product b ON a.product_code = b.product_code
    WHERE a.fiscal_year in (2020,2021)
    GROUP BY b.segment, a.fiscal_year
)
SELECT 
    cte_2020.segment,
    cte_2020.product_count as product_count_2020,
    cte_2021.product_count as product_count_2021,
    cte_2021.product_count - cte_2020.product_count as difference
FROM cte cte_2020
JOIN cte cte_2021 ON cte_2020.segment = cte_2021.segment
WHERE cte_2020.fiscal_year = 2020
AND cte_2021.fiscal_year = 2021
ORDER BY difference DESC;

-- OR 

WITH cte AS ( SELECT b.segment,
COUNT(DISTINCT CASE WHEN a.fiscal_year = 2020 THEN a.product_code END) AS product_count_2020,
COUNT(DISTINCT CASE WHEN a.fiscal_year = 2021 THEN a.product_code END) AS product_count_2021
FROM fact_sales_monthly a 
INNER JOIN dim_product b
ON a.product_code = b.product_code
GROUP BY b.segment )
SELECT segment, product_count_2020, product_count_2021,
(product_count_2021 - product_count_2020) AS difference
FROM cte
ORDER BY difference DESC;

-- (5) The products that have the highest and lowest manufacturing costs.
SELECT a.product_code, a.product, b.manufacturing_cost
FROM dim_product a
INNER JOIN fact_manufacturing_cost b 
ON a.product_code = b.product_code
WHERE b.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
OR b.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost);

-- OR

WITH cte AS (
SELECT b.product_code, b.product, a.manufacturing_cost,
DENSE_RANK() OVER(ORDER BY manufacturing_cost DESC) AS max_cost,
DENSE_RANK() OVER(ORDER BY manufacturing_cost ASC) AS min_cost
FROM fact_manufacturing_cost a
LEFT JOIN dim_product b
ON a.product_code = b.product_code )
SELECT DISTINCT product_code, product, manufacturing_cost
FROM cte 
WHERE min_cost = 1 OR max_cost = 1;

-- (6)top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.
SELECT a.customer_code, a.customer, 
ROUND(AVG(b.pre_invoice_discount_pct)*100, 2) AS average_discount_percentage
FROM dim_customer a
JOIN fact_pre_invoice_deductions b 
ON a.customer_code = b.customer_code
WHERE a.market = 'India'
AND fiscal_year = 2021
GROUP BY a.customer_code, a.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;


-- (7) the Gross sales amount for the customer “Atliq Exclusive” for each month.
SELECT MONTHNAME(a.date) AS month, a.fiscal_year, 
ROUND(SUM(c.gross_price * a.sold_quantity),2) AS Gross_sales_amount
FROM fact_sales_monthly a
JOIN dim_customer b ON a.customer_code = b.customer_code
JOIN fact_gross_price c ON a.product_code = c.product_code
WHERE b.customer = 'Atliq Exclusive'
GROUP BY MONTH(a.date), a.fiscal_year
order by Gross_sales_amount desc;

SELECT MONTH(date) AS months, a.fiscal_year,
SUM(gross_price * sold_quantity) AS gross_sales
FROM fact_sales_monthly a
JOIN dim_customer b USING(customer_code)
JOIN fact_gross_price c USING(product_code)
WHERE customer = 'Atliq exclusive'
GROUP BY months, fiscal_year
ORDER BY gross_sales DESC;



-- (8) In which quarter of 2020, got the maximum total_sold_quantity?
WITH quarterly_sales AS (
SELECT
CASE
WHEN MONTH(date) IN (9,10,11) THEN 'Q1'
WHEN MONTH(date) IN (12,1,2) THEN 'Q2'
WHEN MONTH(date) IN (3,4,5) THEN 'Q3'
WHEN MONTH(date) IN (6,7,8) THEN 'Q4'
END AS quarter,
SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY quarter
)
SELECT quarter, total_sold_quantity
FROM quarterly_sales
ORDER BY total_sold_quantity DESC;
-- LIMIT 1;

-- (9)
WITH gross_sales_cte AS (
SELECT
c.channel,
ROUND(SUM(b.gross_price * a.sold_quantity) / 1000000, 2) AS gross_sales_mln
FROM fact_sales_monthly a
JOIN fact_gross_price b ON a.product_code = b.product_code
JOIN dim_customer c ON a.customer_code = c.customer_code
AND a.fiscal_year = b.fiscal_year
WHERE a.fiscal_year = 2021
GROUP BY c.channel
)
SELECT
channel,
gross_sales_mln,
ROUND(gross_sales_mln / SUM(gross_sales_mln) OVER() * 100, 2) AS percentage
FROM gross_sales_cte
ORDER BY gross_sales_mln DESC;
-- LIMIT 1;

-- (10) Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021

WITH cte AS (
    SELECT 
        b.division,
        b.product_code,
        b.product,
        SUM(a.sold_quantity) AS total_sold_quantity,
        RANK() OVER (PARTITION BY b.division ORDER BY SUM(a.sold_quantity) DESC) AS rank_order
    FROM fact_sales_monthly a
    JOIN dim_product b ON a.product_code = b.product_code
    WHERE a.fiscal_year = 2021
    GROUP BY b.division, b.product_code, b.product
)
SELECT division, product_code, product, total_sold_quantity, rank_order
FROM cte
WHERE rank_order <= 3;













