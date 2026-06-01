-- Olist SQL Queries
/*
================================================================
OLIST E-COMMERCE ANALYSIS — SQL QUERIES
================================================================
Author   : Rishabh Kumar Singh
Database : MS SQL Server
Dataset  : Olist Brazilian E-Commerce (Kaggle)

Business Questions:
  Q1. What is total revenue and average order value?
  Q2. Which states generate the most revenue?
  Q3. Do late deliveries cause lower review scores?
  Q4. What is the monthly revenue trend?
  Q5. Who are the top 10 sellers?
  Q6. Which categories earn the most? (window function)
  Q7. Month-over-month growth (CTE + LAG)
  Q8. What % of customers are repeat buyers?
================================================================
*/

USE olist_project;
GO

-- ============================================================
-- Q1: Total revenue and average order value
-- Finding: Total R$XX million, average order R$120
-- ============================================================
SELECT
    COUNT(DISTINCT order_id)        AS total_orders,
    ROUND(SUM(order_total), 2)      AS total_revenue,
    ROUND(AVG(order_total), 2)      AS avg_order_value,
    ROUND(MIN(order_total), 2)      AS min_order_value,
    ROUND(MAX(order_total), 2)      AS max_order_value
FROM (
    SELECT order_id, SUM(payment_value) AS order_total
    FROM olist_order_payments
    GROUP BY order_id
) AS order_totals;


-- ============================================================
-- Q2: Revenue by customer state
-- Finding: SP alone = ~40% of total revenue
-- ============================================================
SELECT
    c.customer_state                    AS state,
    COUNT(DISTINCT o.order_id)          AS total_orders,
    ROUND(SUM(p.payment_value), 2)      AS total_revenue,
    ROUND(AVG(p.payment_value), 2)      AS avg_order_value
FROM olist_customers      c
JOIN olist_orders         o  ON c.customer_id = o.customer_id
JOIN olist_order_payments p  ON o.order_id    = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC;


-- ============================================================
-- Q3: Do late deliveries cause lower review scores?
-- Finding: Late = 2.5 stars, On Time = 4.2 stars
-- Proven statistically with t-test in Python (p < 0.001)
-- ============================================================
SELECT
    CASE
        WHEN order_delivered_customer_date
           > order_estimated_delivery_date
        THEN 'Late'
        ELSE 'On Time'
    END                                 AS delivery_status,
    COUNT(*)                            AS order_count,
    ROUND(AVG(r.review_score * 1.0), 2) AS avg_review_score
FROM olist_orders        o
JOIN olist_order_reviews r  ON o.order_id = r.order_id
WHERE o.order_status                    = 'delivered'
  AND o.order_delivered_customer_date  IS NOT NULL
  AND o.order_estimated_delivery_date  IS NOT NULL
GROUP BY
    CASE
        WHEN order_delivered_customer_date
           > order_estimated_delivery_date
        THEN 'Late'
        ELSE 'On Time'
    END;


-- ============================================================
-- Q4: Monthly revenue trend
-- Finding: 35x growth in 18 months, Black Friday spike Nov 2017
-- ============================================================
SELECT
    FORMAT(o.order_purchase_timestamp, 'yyyy-MM') AS order_month,
    COUNT(DISTINCT o.order_id)                     AS total_orders,
    ROUND(SUM(p.payment_value), 2)                 AS monthly_revenue
FROM olist_orders         o
JOIN olist_order_payments p  ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
ORDER BY order_month;


-- ============================================================
-- Q5: Top 10 sellers by revenue
-- Finding: Top sellers concentrated in SP
-- ============================================================
SELECT TOP 10
    i.seller_id,
    s.seller_state,
    COUNT(DISTINCT i.order_id)  AS orders_fulfilled,
    ROUND(SUM(i.price), 2)      AS total_revenue,
    ROUND(AVG(i.price), 2)      AS avg_item_price
FROM olist_order_items i
JOIN olist_sellers     s  ON i.seller_id = s.seller_id
GROUP BY i.seller_id, s.seller_state
ORDER BY total_revenue DESC;


-- ============================================================
-- Q6: Category revenue with window function RANK()
-- Concept: window functions calculate rank without collapsing rows
-- ============================================================
SELECT
    t.product_category_name_english     AS category,
    ROUND(SUM(i.price), 2)              AS total_revenue,
    RANK() OVER (ORDER BY SUM(i.price) DESC) AS revenue_rank,
    ROUND(
        SUM(i.price) * 100.0
        / SUM(SUM(i.price)) OVER (),
        2
    )                                   AS pct_of_total
FROM olist_order_items                  i
JOIN olist_products                     p
    ON i.product_id = p.product_id
JOIN product_category_translation       t
    ON p.product_category_name = t.product_category_name
GROUP BY t.product_category_name_english
ORDER BY revenue_rank;


-- ============================================================
-- Q7: Month-over-month revenue growth using CTE + LAG()
-- Concept: CTE = reusable named query, LAG = previous row value
-- ============================================================
WITH monthly_revenue AS (
    SELECT
        FORMAT(o.order_purchase_timestamp, 'yyyy-MM') AS order_month,
        ROUND(SUM(p.payment_value), 2)                AS revenue
    FROM olist_orders         o
    JOIN olist_order_payments p  ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
)
SELECT
    order_month,
    revenue,
    LAG(revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY order_month))
        * 100.0
        / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0),
        2
    )                                        AS mom_growth_pct
FROM monthly_revenue
ORDER BY order_month;


-- ============================================================
-- Q8: Customer segmentation — one-time vs repeat buyers
-- Finding: 97% of customers buy only once — major retention problem
-- ============================================================
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id) AS total_orders
    FROM olist_customers c
    JOIN olist_orders    o  ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN total_orders = 1            THEN '1. One-time buyer'
        WHEN total_orders BETWEEN 2 AND 3 THEN '2. Occasional (2-3 orders)'
        ELSE                                  '3. Loyal (4+ orders)'
    END                                          AS customer_segment,
    COUNT(*)                                     AS customer_count,
    ROUND(COUNT(*) * 100.0
          / SUM(COUNT(*)) OVER (), 2)            AS pct_of_total
FROM customer_orders
GROUP BY
    CASE
        WHEN total_orders = 1            THEN '1. One-time buyer'
        WHEN total_orders BETWEEN 2 AND 3 THEN '2. Occasional (2-3 orders)'
        ELSE                                  '3. Loyal (4+ orders)'
    END
ORDER BY customer_segment;
