"""
Seed Data Generator for SaaS Subscription & Cohort Analytics Engine
Simulates realistic 24-month customer journeys:
- Signups across various channels & company sizes
- Natural upgrades, downgrades, churn, and reactivations
- Monthly invoices with edge cases (failed payments, refunds)
- Behavioral usage metrics (activity drop-offs preceding churn)
"""

import sqlite3
import random
import uuid
from datetime import datetime, date, timedelta
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "..", "saas_analytics.db")
SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "..", "schema", "01_schema.sql")

random.seed(42)

INDUSTRIES = ['Fintech', 'Healthcare', 'E-commerce', 'EdTech', 'Cybersecurity', 'Logistics', 'MarketingTech']
COMPANY_SIZES = ['1-10', '11-50', '51-200', '201-1000', '1000+']
COUNTRIES = ['United States', 'United Kingdom', 'Canada', 'Germany', 'Australia', 'India', 'France']
CHANNELS = ['Organic Search', 'Paid Ads', 'Referral', 'Outbound Sales']
CANCELLATION_REASONS = ['Price too high', 'Switched to competitor', 'Missing features', 'Company downsizing', 'Budget cut', 'Product too complex']

PLANS = [
    (1, 'Starter', 'Basic', 49.00, 5),
    (2, 'Professional', 'Mid', 199.00, 25),
    (3, 'Enterprise', 'High', 799.00, 100)
]

def add_months(sourcedate, months):
    month = sourcedate.month - 1 + months
    year = sourcedate.year + month // 12
    month = month % 12 + 1
    day = min(sourcedate.day, 28)
    return date(year, month, day)

def init_db():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    with open(SCHEMA_PATH, 'r') as f:
        schema_sql = f.read()
    
    cursor.executescript(schema_sql)
    
    # Insert plans
    cursor.executemany(
        "INSERT INTO plans (plan_id, plan_name, tier, price_monthly, max_seats) VALUES (?, ?, ?, ?, ?)",
        PLANS
    )
    conn.commit()
    return conn

def generate_data(conn, total_customers=600):
    cursor = conn.cursor()
    
    start_sim_date = date(2023, 1, 1)
    end_sim_date = date(2024, 12, 31)
    
    plan_prices = {p[0]: float(p[3]) for p in PLANS}
    
    customers_data = []
    subscriptions_data = []
    events_data = []
    invoices_data = []
    usage_data = []
    
    print(f"Generating data for {total_customers} customer accounts over 24 months...")
    
    for i in range(1, total_customers + 1):
        cust_id = str(uuid.uuid4())
        company_name = f"Corp_{i:04d}_{random.choice(['Tech', 'Labs', 'Global', 'Solutions', 'Data', 'Systems', 'AI'])}"
        industry = random.choice(INDUSTRIES)
        size = random.choices(COMPANY_SIZES, weights=[0.35, 0.30, 0.20, 0.10, 0.05])[0]
        country = random.choices(COUNTRIES, weights=[0.45, 0.15, 0.10, 0.10, 0.08, 0.07, 0.05])[0]
        channel = random.choices(CHANNELS, weights=[0.35, 0.30, 0.20, 0.15])[0]
        
        # Signup month between month 0 and 20
        month_offset = random.randint(0, 22)
        signup_day = random.randint(1, 28)
        signup_date = add_months(start_sim_date, month_offset).replace(day=signup_day)
        
        customers_data.append((cust_id, company_name, industry, size, country, channel, signup_date.isoformat()))
        
        # Initial Plan: Enterprise more likely for larger companies
        if size in ['201-1000', '1000+']:
            curr_plan_id = random.choices([1, 2, 3], weights=[0.1, 0.3, 0.6])[0]
        elif size == '51-200':
            curr_plan_id = random.choices([1, 2, 3], weights=[0.2, 0.6, 0.2])[0]
        else:
            curr_plan_id = random.choices([1, 2, 3], weights=[0.75, 0.22, 0.03])[0]
            
        billing_interval = random.choices(['monthly', 'annual'], weights=[0.8, 0.2])[0]
        sub_id = str(uuid.uuid4())
        curr_mrr = plan_prices[curr_plan_id]
        
        # Signup event
        events_data.append((
            str(uuid.uuid4()), sub_id, cust_id, 'signup', signup_date.isoformat(),
            0.0, curr_mrr, curr_mrr, None
        ))
        
        # Track monthly status
        curr_date = signup_date
        is_active = True
        churn_date = None
        reactivation_date = None
        
        while curr_date <= end_sim_date:
            month_start = curr_date.replace(day=1)
            
            # Record invoice if active
            if is_active:
                inv_status = random.choices(['paid', 'failed'], weights=[0.96, 0.04])[0]
                amount_paid = curr_mrr if inv_status == 'paid' else 0.0
                invoices_data.append((
                    str(uuid.uuid4()), cust_id, sub_id, curr_date.isoformat(),
                    curr_mrr, amount_paid, inv_status, 'credit_card'
                ))
                
                # Usage metrics (higher for active and enterprise, drops before churn)
                base_users = 3 if curr_plan_id == 1 else (15 if curr_plan_id == 2 else 60)
                active_users = max(1, int(random.gauss(base_users, base_users * 0.2)))
                feature_actions = max(10, int(active_users * random.uniform(25, 60)))
                tickets = random.choices([0, 1, 2, 3], weights=[0.7, 0.2, 0.07, 0.03])[0]
                nps = random.choice([7, 8, 9, 10, None])
                
                usage_data.append((
                    str(uuid.uuid4()), cust_id, month_start.isoformat(),
                    active_users, feature_actions, tickets, nps
                ))
            
            # Next month simulation
            next_date = add_months(curr_date, 1)
            if next_date > end_sim_date:
                break
                
            if is_active:
                # Decide state change: Upgrade (8%), Downgrade (4%), Churn (5-8%), Stay active (80%)
                action = random.choices(['stay', 'upgrade', 'downgrade', 'churn'], weights=[0.82, 0.07, 0.04, 0.07])[0]
                
                if action == 'upgrade' and curr_plan_id < 3:
                    new_plan_id = curr_plan_id + 1
                    new_mrr = plan_prices[new_plan_id]
                    events_data.append((
                        str(uuid.uuid4()), sub_id, cust_id, 'upgrade', next_date.isoformat(),
                        curr_mrr, new_mrr, new_mrr - curr_mrr, None
                    ))
                    curr_plan_id = new_plan_id
                    curr_mrr = new_mrr
                    
                elif action == 'downgrade' and curr_plan_id > 1:
                    new_plan_id = curr_plan_id - 1
                    new_mrr = plan_prices[new_plan_id]
                    events_data.append((
                        str(uuid.uuid4()), sub_id, cust_id, 'downgrade', next_date.isoformat(),
                        curr_mrr, new_mrr, new_mrr - curr_mrr, None
                    ))
                    curr_plan_id = new_plan_id
                    curr_mrr = new_mrr
                    
                elif action == 'churn':
                    is_active = False
                    churn_date = next_date
                    reason = random.choice(CANCELLATION_REASONS)
                    events_data.append((
                        str(uuid.uuid4()), sub_id, cust_id, 'cancellation', next_date.isoformat(),
                        curr_mrr, 0.0, -curr_mrr, reason
                    ))
                    
                    # Record a degraded usage record right around churn
                    usage_data.append((
                        str(uuid.uuid4()), cust_id, next_date.replace(day=1).isoformat(),
                        max(1, int(base_users * 0.2)), 5, random.randint(2, 5), random.choice([2, 3, 4])
                    ))
                    
            else:
                # If currently churned, small chance of reactivation (4% per month)
                if random.random() < 0.04 and curr_date > churn_date:
                    is_active = True
                    reactivation_date = next_date
                    events_data.append((
                        str(uuid.uuid4()), sub_id, cust_id, 'reactivation', next_date.isoformat(),
                        0.0, curr_mrr, curr_mrr, None
                    ))
            
            curr_date = next_date
            
        status = 'active' if is_active else 'churned'
        final_end_date = churn_date.isoformat() if churn_date and not is_active else None
        subscriptions_data.append((
            sub_id, cust_id, curr_plan_id, status, billing_interval,
            signup_date.isoformat(), final_end_date, add_months(signup_date, 12).isoformat()
        ))
        
    # Bulk insert into DB
    cursor.executemany("INSERT INTO customers VALUES (?, ?, ?, ?, ?, ?, ?)", customers_data)
    cursor.executemany("INSERT INTO subscriptions VALUES (?, ?, ?, ?, ?, ?, ?, ?)", subscriptions_data)
    cursor.executemany("INSERT INTO subscription_events VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", events_data)
    cursor.executemany("INSERT INTO invoices VALUES (?, ?, ?, ?, ?, ?, ?, ?)", invoices_data)
    cursor.executemany("INSERT INTO usage_metrics VALUES (?, ?, ?, ?, ?, ?, ?)", usage_data)
    
    conn.commit()
    print("Database populated successfully!")
    print(f"Total Customers: {len(customers_data)}")
    print(f"Total Subscriptions: {len(subscriptions_data)}")
    print(f"Total Subscription Events: {len(events_data)}")
    print(f"Total Invoices: {len(invoices_data)}")
    print(f"Total Monthly Usage Logs: {len(usage_data)}")

if __name__ == '__main__':
    conn = init_db()
    generate_data(conn, total_customers=600)
    conn.close()
