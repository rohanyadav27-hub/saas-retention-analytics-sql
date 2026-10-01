-- ============================================================================
-- Query 4: Customer Health Scoring & Churn Early Warning Indicator
-- Domain: Customer Success, Churn Prevention & Risk Scoring
-- SQL Concepts: Windowed Moving Averages, Multi-condition Case Scoring,
--               Cross-table Behavioral Aggregation
-- Compatible with: PostgreSQL, DuckDB, SQLite
-- ============================================================================

WITH recent_usage_trends AS (
    SELECT
        u.customer_id,
        u.usage_month,
        u.active_users_count,
        u.feature_actions_count,
        u.support_tickets_opened,
        u.nps_score,
        
        -- 3-month moving average of active users for this customer
        AVG(u.active_users_count) OVER (
            PARTITION BY u.customer_id 
            ORDER BY u.usage_month 
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS avg_prior_active_users,
        
        -- 3-month moving average of feature actions
        AVG(u.feature_actions_count) OVER (
            PARTITION BY u.customer_id 
            ORDER BY u.usage_month 
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS avg_prior_actions,
        
        -- Rank to get the most recent recorded month per customer
        ROW_NUMBER() OVER (
            PARTITION BY u.customer_id 
            ORDER BY u.usage_month DESC
        ) AS recency_rank

    FROM usage_metrics u
),

latest_customer_signals AS (
    SELECT
        r.customer_id,
        r.usage_month,
        r.active_users_count,
        r.feature_actions_count,
        r.support_tickets_opened,
        r.nps_score,
        r.avg_prior_active_users,
        r.avg_prior_actions,
        
        -- Usage drop ratio vs prior baseline (e.g. 0.40 means 60% drop in active users)
        CASE 
            WHEN r.avg_prior_active_users > 0 
            THEN ROUND(CAST(r.active_users_count AS FLOAT) / r.avg_prior_active_users, 2)
            ELSE 1.0 
        END AS user_activity_ratio

    FROM recent_usage_trends r
    WHERE r.recency_rank = 1
),

payment_risk AS (
    -- Count failed invoices in the last 6 months
    SELECT
        customer_id,
        COUNT(CASE WHEN payment_status = 'failed' THEN 1 END) AS failed_payments_count
    FROM invoices
    GROUP BY customer_id
)

SELECT
    c.customer_id,
    c.company_name,
    c.industry,
    c.company_size,
    p.plan_name,
    p.price_monthly AS current_mrr,
    s.status AS subscription_status,
    ls.usage_month AS latest_usage_month,
    ls.active_users_count,
    ls.support_tickets_opened,
    ls.nps_score,
    ls.user_activity_ratio,
    COALESCE(pr.failed_payments_count, 0) AS failed_payments_count,
    
    -- Composite Risk Score (0 = No Risk, 100 = Imminent Churn)
    (
        -- Activity drop penalty: up to 40 pts if user engagement drops below 50%
        CASE 
            WHEN ls.user_activity_ratio <= 0.3 THEN 40
            WHEN ls.user_activity_ratio <= 0.6 THEN 25
            ELSE 0 
        END +
        -- High ticket friction penalty: up to 25 pts
        CASE 
            WHEN ls.support_tickets_opened >= 3 THEN 25
            WHEN ls.support_tickets_opened >= 1 THEN 10
            ELSE 0 
        END +
        -- Low NPS penalty: up to 25 pts
        CASE 
            WHEN ls.nps_score IS NOT NULL AND ls.nps_score <= 4 THEN 25
            WHEN ls.nps_score IS NOT NULL AND ls.nps_score <= 6 THEN 15
            ELSE 0 
        END +
        -- Payment failure friction: 10 pts
        CASE 
            WHEN COALESCE(pr.failed_payments_count, 0) > 0 THEN 10
            ELSE 0 
        END
    ) AS churn_risk_score,

    -- Risk Segment Categorization
    CASE
        WHEN (
            CASE WHEN ls.user_activity_ratio <= 0.3 THEN 40 WHEN ls.user_activity_ratio <= 0.6 THEN 25 ELSE 0 END +
            CASE WHEN ls.support_tickets_opened >= 3 THEN 25 WHEN ls.support_tickets_opened >= 1 THEN 10 ELSE 0 END +
            CASE WHEN ls.nps_score IS NOT NULL AND ls.nps_score <= 4 THEN 25 WHEN ls.nps_score IS NOT NULL AND ls.nps_score <= 6 THEN 15 ELSE 0 END +
            CASE WHEN COALESCE(pr.failed_payments_count, 0) > 0 THEN 10 ELSE 0 END
        ) >= 60 THEN 'CRITICAL - HIGH CHURN RISK'
        WHEN (
            CASE WHEN ls.user_activity_ratio <= 0.3 THEN 40 WHEN ls.user_activity_ratio <= 0.6 THEN 25 ELSE 0 END +
            CASE WHEN ls.support_tickets_opened >= 3 THEN 25 WHEN ls.support_tickets_opened >= 1 THEN 10 ELSE 0 END +
            CASE WHEN ls.nps_score IS NOT NULL AND ls.nps_score <= 4 THEN 25 WHEN ls.nps_score IS NOT NULL AND ls.nps_score <= 6 THEN 15 ELSE 0 END +
            CASE WHEN COALESCE(pr.failed_payments_count, 0) > 0 THEN 10 ELSE 0 END
        ) >= 30 THEN 'ELEVATED RISK'
        ELSE 'HEALTHY'
    END AS health_tier

FROM customers c
JOIN subscriptions s ON c.customer_id = s.customer_id
JOIN plans p ON s.plan_id = p.plan_id
JOIN latest_customer_signals ls ON c.customer_id = ls.customer_id
LEFT JOIN payment_risk pr ON c.customer_id = pr.customer_id
WHERE s.status = 'active'
ORDER BY churn_risk_score DESC, current_mrr DESC
LIMIT 20;
