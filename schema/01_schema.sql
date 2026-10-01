-- ============================================================================
-- Project: SaaS Subscription & Cohort Retention Analytics Engine
-- File: schema/01_schema.sql
-- Description: DDL definitions for customers, subscription tiers, subscriptions,
--              lifecycle events, billing invoices, and monthly product usage.
-- Compatible with: PostgreSQL, DuckDB, and SQLite
-- ============================================================================

-- 1. Dim Customers: Profile and firmographic attributes
CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(36) PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL,
    industry VARCHAR(50) NOT NULL,
    company_size VARCHAR(20) NOT NULL, -- '1-10', '11-50', '51-200', '201-1000', '1000+'
    country VARCHAR(50) NOT NULL,
    acquisition_channel VARCHAR(50) NOT NULL, -- 'Organic Search', 'Paid Ads', 'Referral', 'Outbound Sales'
    signup_date DATE NOT NULL
);

-- 2. Dim Plans: Pricing tiers and feature levels
CREATE TABLE IF NOT EXISTS plans (
    plan_id INTEGER PRIMARY KEY,
    plan_name VARCHAR(50) NOT NULL, -- 'Starter', 'Professional', 'Enterprise'
    tier VARCHAR(20) NOT NULL,       -- 'Basic', 'Mid', 'High'
    price_monthly NUMERIC(10, 2) NOT NULL,
    max_seats INTEGER NOT NULL
);

-- 3. Fact Subscriptions: Current/historical subscription state
CREATE TABLE IF NOT EXISTS subscriptions (
    subscription_id VARCHAR(36) PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL REFERENCES customers(customer_id),
    plan_id INTEGER NOT NULL REFERENCES plans(plan_id),
    status VARCHAR(20) NOT NULL, -- 'active', 'churned', 'paused', 'past_due'
    billing_interval VARCHAR(20) NOT NULL, -- 'monthly', 'annual'
    start_date DATE NOT NULL,
    end_date DATE,               -- NULL if still active
    renewal_date DATE
);

-- 4. Fact Subscription Events: Immutable ledger tracking every change in MRR
CREATE TABLE IF NOT EXISTS subscription_events (
    event_id VARCHAR(36) PRIMARY KEY,
    subscription_id VARCHAR(36) NOT NULL REFERENCES subscriptions(subscription_id),
    customer_id VARCHAR(36) NOT NULL REFERENCES customers(customer_id),
    event_type VARCHAR(30) NOT NULL, -- 'signup', 'upgrade', 'downgrade', 'cancellation', 'reactivation'
    event_date DATE NOT NULL,
    previous_mrr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    new_mrr NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    mrr_delta NUMERIC(10, 2) NOT NULL, -- new_mrr - previous_mrr
    cancellation_reason VARCHAR(100)  -- 'Price', 'Competitor', 'Missing Feature', 'Out of Business', etc.
);

-- 5. Fact Invoices: Financial billing and payment status
CREATE TABLE IF NOT EXISTS invoices (
    invoice_id VARCHAR(36) PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL REFERENCES customers(customer_id),
    subscription_id VARCHAR(36) NOT NULL REFERENCES subscriptions(subscription_id),
    invoice_date DATE NOT NULL,
    amount_due NUMERIC(10, 2) NOT NULL,
    amount_paid NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    payment_status VARCHAR(20) NOT NULL, -- 'paid', 'failed', 'refunded', 'pending'
    payment_method VARCHAR(30)           -- 'credit_card', 'ach', 'wire_transfer'
);

-- 6. Fact Usage Metrics: Monthly behavioral signals for churn correlation
CREATE TABLE IF NOT EXISTS usage_metrics (
    metric_id VARCHAR(36) PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL REFERENCES customers(customer_id),
    usage_month DATE NOT NULL,           -- First day of the month (YYYY-MM-01)
    active_users_count INTEGER NOT NULL,
    feature_actions_count INTEGER NOT NULL,
    support_tickets_opened INTEGER NOT NULL DEFAULT 0,
    nps_score INTEGER                    -- 0 to 10 customer satisfaction score (NULL if not surveyed)
);
