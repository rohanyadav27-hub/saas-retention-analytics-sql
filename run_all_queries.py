"""
CLI Runner for SaaS Subscription & Cohort Retention Analytics
Executes all analytical queries and displays formatted outputs in console.
"""

import sqlite3
import pandas as pd
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "saas_analytics.db")
QUERIES_DIR = os.path.join(os.path.dirname(__file__), "queries")

import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

pd.set_option('display.max_columns', 15)
pd.set_option('display.width', 1000)

def execute_query(conn, filename, title):
    filepath = os.path.join(QUERIES_DIR, filename)
    with open(filepath, 'r') as f:
        query_sql = f.read()
    
    print("\n" + "=" * 90)
    print(f"[*] {title}")
    print(f"[File] queries/{filename}")
    print("=" * 90)
    
    df = pd.read_sql_query(query_sql, conn)
    print(df.to_string(index=False))
    return df

def main():
    if not os.path.exists(DB_PATH):
        print("Database not found! Please run: python scripts/generate_seed_data.py")
        return
        
    conn = sqlite3.connect(DB_PATH)
    
    # 1. MRR Waterfall
    execute_query(conn, "01_mrr_revenue_bridge.sql", "Monthly Recurring Revenue (MRR) Bridge / Waterfall")
    
    # 2. Cohort Retention Matrix
    execute_query(conn, "02_cohort_retention_matrix.sql", "Triangular Cohort Retention Matrix (%)")
    
    # 3. NRR / GRR Executive KPIs
    execute_query(conn, "03_nrr_grr_kpis.sql", "Executive Unit Economics: NRR, GRR & Churn Rates")
    
    # 4. Customer Churn Early Warning
    execute_query(conn, "04_churn_health_score.sql", "Customer Health & Early Churn Risk Scoring (Top 20 Accounts)")
    
    conn.close()
    print("\n" + "=" * 90)
    print("[SUCCESS] All analytical SQL queries executed successfully!")
    print("=" * 90)

if __name__ == '__main__':
    main()
