-- ============================================================================
-- Query 2: Triangular Cohort Retention Matrix (User & Subscription Retention)
-- Domain: Product Analytics, Churn Analysis & LTV Forecasting
-- SQL Concepts: Cohort Grouping, Date Normalization, Pivot Aggregation (CASE WHEN),
--               Self-contained Dimensional Windowing
-- Compatible with: PostgreSQL, DuckDB, SQLite
-- ============================================================================

WITH customer_cohorts AS (
    -- Define the Cohort Month for each customer (Month 0)
    SELECT
        customer_id,
        SUBSTR(signup_date, 1, 7) AS cohort_month
    FROM customers
),

customer_active_months AS (
    -- Determine every month in which a customer was actively billed and paid
    SELECT DISTINCT
        customer_id,
        SUBSTR(invoice_date, 1, 7) AS active_month
    FROM invoices
    WHERE payment_status = 'paid'
),

cohort_activity AS (
    -- Calculate the month index (Month 0, 1, 2, 3...) relative to cohort signup
    SELECT
        c.cohort_month,
        c.customer_id,
        a.active_month,
        (
            (CAST(SUBSTR(a.active_month, 1, 4) AS INTEGER) - CAST(SUBSTR(c.cohort_month, 1, 4) AS INTEGER)) * 12 +
            (CAST(SUBSTR(a.active_month, 6, 2) AS INTEGER) - CAST(SUBSTR(c.cohort_month, 6, 2) AS INTEGER))
        ) AS month_number
    FROM customer_cohorts c
    JOIN customer_active_months a ON c.customer_id = a.customer_id
    WHERE a.active_month >= c.cohort_month
),

cohort_sizes AS (
    -- Total count of distinct customers acquired in each cohort
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS total_cohort_users
    FROM customer_cohorts
    GROUP BY cohort_month
)

SELECT
    cs.cohort_month,
    cs.total_cohort_users AS cohort_size,
    
    -- Retention Percentages across months since signup (Month 0 is always 100%)
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 0 THEN ca.customer_id END) / cs.total_cohort_users, 1) AS m0_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 1 THEN ca.customer_id END) / cs.total_cohort_users, 1) AS m1_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 2 THEN ca.customer_id END) / cs.total_cohort_users, 1) AS m2_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 3 THEN ca.customer_id END) / cs.total_cohort_users, 1) AS m3_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 4 THEN ca.customer_id END) / cs.total_cohort_users, 1) AS m4_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 5 THEN ca.customer_id END) / cs.total_cohort_users, 1) AS m5_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 6 THEN ca.customer_id END) / cs.total_cohort_users, 1) AS m6_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 9 THEN ca.customer_id END) / cs.total_cohort_users, 1) AS m9_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 12 THEN ca.customer_id END) / cs.total_cohort_users, 1) AS m12_pct

FROM cohort_sizes cs
LEFT JOIN cohort_activity ca ON cs.cohort_month = ca.cohort_month
GROUP BY cs.cohort_month, cs.total_cohort_users
ORDER BY cs.cohort_month ASC;
