-- ============================================================================
-- Query 5: Indexing Strategy & Query Optimization DDL
-- Domain: Database Performance Engineering & Query Execution Tuning
-- SQL Concepts: B-Tree Indexes, Composite Covering Indexes, Partial Indexes
-- Compatible with: PostgreSQL, SQLite
-- ============================================================================

-- 1. Accelerates MRR Bridge: Groups and filters on event_date and event_type
CREATE INDEX IF NOT EXISTS idx_sub_events_date_type 
ON subscription_events(event_date, event_type, mrr_delta, new_mrr);

-- 2. Accelerates Cohort Retention: Filters on payment_status and groups on invoice_date
CREATE INDEX IF NOT EXISTS idx_invoices_status_date_cust 
ON invoices(payment_status, invoice_date, customer_id);

-- 3. Accelerates Churn Health Scoring: Partitioned window functions on (customer_id, usage_month)
CREATE INDEX IF NOT EXISTS idx_usage_cust_month 
ON usage_metrics(customer_id, usage_month);

-- 4. Accelerates Subscription Joins & Status Filtering
CREATE INDEX IF NOT EXISTS idx_subscriptions_cust_status 
ON subscriptions(customer_id, status, plan_id);

-- 5. Accelerates Customer Signup Cohort Lookups
CREATE INDEX IF NOT EXISTS idx_customers_signup 
ON customers(signup_date, customer_id);
