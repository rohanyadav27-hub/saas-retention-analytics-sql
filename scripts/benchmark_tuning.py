"""
Benchmark and Query Execution Plan Analyzer
Compares EXPLAIN QUERY PLAN before and after creating indexes.
"""

import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "..", "saas_analytics.db")
INDEX_PATH = os.path.join(os.path.dirname(__file__), "..", "queries", "05_performance_tuning.sql")

def analyze_plans():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Target query: Invoice lookup for cohort matrix
    test_query = """
    SELECT customer_id, SUBSTR(invoice_date, 1, 7) AS active_month
    FROM invoices
    WHERE payment_status = 'paid'
    """
    
    print("=" * 70)
    print("1. BEFORE INDEXING: Query Execution Plan")
    print("=" * 70)
    cursor.execute(f"EXPLAIN QUERY PLAN {test_query}")
    for row in cursor.fetchall():
        print(f"Plan step: {row}")
        
    print("\nApplying Index Tuning Strategy (05_performance_tuning.sql)...")
    with open(INDEX_PATH, 'r') as f:
        cursor.executescript(f.read())
    conn.commit()
    
    print("\n" + "=" * 70)
    print("2. AFTER INDEXING: Query Execution Plan")
    print("=" * 70)
    cursor.execute(f"EXPLAIN QUERY PLAN {test_query}")
    for row in cursor.fetchall():
        print(f"Plan step: {row}")
        
    # Test customer usage lookup
    usage_query = """
    SELECT customer_id, usage_month, active_users_count
    FROM usage_metrics
    WHERE customer_id = 'test-id'
    ORDER BY usage_month DESC
    """
    print("\n" + "=" * 70)
    print("3. USAGE METRICS WITH COMPOSITE INDEX:")
    print("=" * 70)
    cursor.execute(f"EXPLAIN QUERY PLAN {usage_query}")
    for row in cursor.fetchall():
        print(f"Plan step: {row}")
        
    conn.close()

if __name__ == '__main__':
    analyze_plans()
