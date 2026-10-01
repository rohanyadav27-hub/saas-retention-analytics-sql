-- ============================================================================
-- Query 1: Monthly Recurring Revenue (MRR) Bridge / Waterfall Analysis
-- Domain: SaaS Executive KPI & Financial Modeling
-- SQL Concepts: Multi-stage CTEs, Conditional Aggregation, Window Functions (LAG)
-- Compatible with: PostgreSQL, DuckDB, SQLite
-- ============================================================================

WITH monthly_event_totals AS (
    SELECT
        SUBSTR(event_date, 1, 7) AS activity_month,
        
        -- New MRR: Net new customers signing up
        ROUND(SUM(CASE 
            WHEN event_type = 'signup' THEN new_mrr 
            ELSE 0 
        END), 2) AS new_mrr,
        
        -- Expansion MRR: Existing customers upgrading their plan
        ROUND(SUM(CASE 
            WHEN event_type = 'upgrade' THEN mrr_delta 
            ELSE 0 
        END), 2) AS expansion_mrr,
        
        -- Contraction MRR: Existing customers downgrading (mrr_delta is negative, convert to positive magnitude)
        ROUND(SUM(CASE 
            WHEN event_type = 'downgrade' THEN ABS(mrr_delta) 
            ELSE 0 
        END), 2) AS contraction_mrr,
        
        -- Churned MRR: Customers cancelling subscription
        ROUND(SUM(CASE 
            WHEN event_type = 'cancellation' THEN ABS(mrr_delta) 
            ELSE 0 
        END), 2) AS churned_mrr,
        
        -- Reactivation MRR: Previously churned customers resubscribing
        ROUND(SUM(CASE 
            WHEN event_type = 'reactivation' THEN new_mrr 
            ELSE 0 
        END), 2) AS reactivation_mrr

    FROM subscription_events
    GROUP BY SUBSTR(event_date, 1, 7)
),

mrr_waterfall AS (
    SELECT
        activity_month,
        new_mrr,
        expansion_mrr,
        contraction_mrr,
        churned_mrr,
        reactivation_mrr,
        
        -- Net Change in MRR for this specific month
        ROUND(new_mrr + expansion_mrr + reactivation_mrr - contraction_mrr - churned_mrr, 2) AS net_mrr_change,
        
        -- Cumulative Ending MRR using Window Function Running Total
        ROUND(SUM(new_mrr + expansion_mrr + reactivation_mrr - contraction_mrr - churned_mrr) 
            OVER (ORDER BY activity_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS ending_mrr
    FROM monthly_event_totals
)

SELECT
    activity_month,
    -- Beginning MRR is previous month's Ending MRR (NULL replaced by 0 for month 1)
    COALESCE(LAG(ending_mrr) OVER (ORDER BY activity_month), 0.00) AS beginning_mrr,
    new_mrr,
    expansion_mrr,
    contraction_mrr,
    churned_mrr,
    reactivation_mrr,
    net_mrr_change,
    ending_mrr,
    
    -- Month-over-Month Growth Rate %
    CASE 
        WHEN COALESCE(LAG(ending_mrr) OVER (ORDER BY activity_month), 0) > 0 
        THEN ROUND(((ending_mrr - LAG(ending_mrr) OVER (ORDER BY activity_month)) * 100.0) / LAG(ending_mrr) OVER (ORDER BY activity_month), 2)
        ELSE NULL 
    END AS mom_growth_pct

FROM mrr_waterfall
ORDER BY activity_month ASC;
