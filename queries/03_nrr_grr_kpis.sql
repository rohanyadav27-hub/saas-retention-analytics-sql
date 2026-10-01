-- ============================================================================
-- Query 3: Executive SaaS Retention KPIs: Net Retention Rate (NRR) & Gross Retention Rate (GRR)
-- Domain: Board-level SaaS Metrics & Unit Economics
-- SQL Concepts: Windowed CTEs, Ratio Analysis, Division by Zero Guards (NULLIF),
--               Blended Multi-metric Rollups
-- Compatible with: PostgreSQL, DuckDB, SQLite
-- ============================================================================

WITH monthly_revenue_changes AS (
    SELECT
        SUBSTR(event_date, 1, 7) AS activity_month,
        
        -- Starting cohorts: Expansion and Churn dynamics from existing accounts
        SUM(CASE WHEN event_type = 'signup' THEN new_mrr ELSE 0 END) AS new_mrr,
        SUM(CASE WHEN event_type = 'upgrade' THEN mrr_delta ELSE 0 END) AS expansion_mrr,
        SUM(CASE WHEN event_type = 'downgrade' THEN ABS(mrr_delta) ELSE 0 END) AS contraction_mrr,
        SUM(CASE WHEN event_type = 'cancellation' THEN ABS(mrr_delta) ELSE 0 END) AS churned_mrr,
        SUM(CASE WHEN event_type = 'reactivation' THEN new_mrr ELSE 0 END) AS reactivation_mrr,
        
        -- Customer counts
        COUNT(DISTINCT CASE WHEN event_type = 'signup' THEN customer_id END) AS new_customers,
        COUNT(DISTINCT CASE WHEN event_type = 'cancellation' THEN customer_id END) AS churned_customers
        
    FROM subscription_events
    GROUP BY SUBSTR(event_date, 1, 7)
),

mrr_state AS (
    SELECT
        activity_month,
        new_mrr,
        expansion_mrr,
        contraction_mrr,
        churned_mrr,
        reactivation_mrr,
        new_customers,
        churned_customers,
        
        -- Running total of total MRR
        ROUND(SUM(new_mrr + expansion_mrr + reactivation_mrr - contraction_mrr - churned_mrr) 
            OVER (ORDER BY activity_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS ending_mrr
    FROM monthly_revenue_changes
),

kpi_calculations AS (
    SELECT
        activity_month,
        COALESCE(LAG(ending_mrr) OVER (ORDER BY activity_month), 0.0) AS beginning_mrr,
        new_mrr,
        expansion_mrr,
        contraction_mrr,
        churned_mrr,
        reactivation_mrr,
        ending_mrr,
        churned_customers
    FROM mrr_state
)

SELECT
    activity_month,
    beginning_mrr,
    ending_mrr,
    
    -- Gross Revenue Retention (GRR): Max 100%. Ignores expansion and new signups.
    -- Measures how well the core revenue is protected against churn and downgrades.
    CASE 
        WHEN beginning_mrr > 0 
        THEN ROUND(
            ((beginning_mrr - (contraction_mrr + churned_mrr)) * 100.0) / beginning_mrr, 
            2
        )
        ELSE NULL 
    END AS grr_pct,
    
    -- Net Revenue Retention (NRR): Can exceed 100%.
    -- Measures organic expansion of the existing install base (Beginning + Expansion - Contraction - Churn) / Beginning
    CASE 
        WHEN beginning_mrr > 0 
        THEN ROUND(
            ((beginning_mrr + expansion_mrr - (contraction_mrr + churned_mrr)) * 100.0) / beginning_mrr, 
            2
        )
        ELSE NULL 
    END AS nrr_pct,
    
    -- Revenue Churn Rate %
    CASE 
        WHEN beginning_mrr > 0 
        THEN ROUND((churned_mrr * 100.0) / beginning_mrr, 2)
        ELSE 0.0 
    END AS revenue_churn_rate_pct,

    churned_customers

FROM kpi_calculations
ORDER BY activity_month ASC;
