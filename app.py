"""
Interactive Streamlit Dashboard for SaaS Subscription & Cohort Analytics Engine
Run locally with: streamlit run app.py
"""

import sqlite3
import pandas as pd
import streamlit as st
import os

st.set_page_config(page_title="SaaS Retention & Cohort Analytics", page_icon="📈", layout="wide")

DB_PATH = os.path.join(os.path.dirname(__file__), "saas_analytics.db")
QUERIES_DIR = os.path.join(os.path.dirname(__file__), "queries")

def load_query(filename):
    with open(os.path.join(QUERIES_DIR, filename), 'r') as f:
        return f.read()

def run_query(sql):
    conn = sqlite3.connect(DB_PATH)
    df = pd.read_sql_query(sql, conn)
    conn.close()
    return df

st.title("📈 SaaS Subscription & Cohort Retention Analytics Engine")
st.markdown("Production-grade SQL analytics tracking MRR Bridges, Cohort Retention Matrices, and Customer Health Signals.")

if not os.path.exists(DB_PATH):
    with st.spinner("Initializing database and generating 24-month SaaS seed data..."):
        from scripts.generate_seed_data import init_db, generate_data
        _conn = init_db()
        generate_data(_conn, total_customers=600)
        _conn.close()
    st.success("Database initialized successfully!")

# Load DataFrames
df_mrr = run_query(load_query("01_mrr_revenue_bridge.sql"))
df_cohort = run_query(load_query("02_cohort_retention_matrix.sql"))
df_kpis = run_query(load_query("03_nrr_grr_kpis.sql"))
df_churn = run_query(load_query("04_churn_health_score.sql"))

latest_mrr = df_mrr['ending_mrr'].iloc[-1]
prev_mrr = df_mrr['beginning_mrr'].iloc[-1]
avg_nrr = df_kpis['nrr_pct'].dropna().mean()
avg_grr = df_kpis['grr_pct'].dropna().mean()

# Header Metrics
c1, c2, c3, c4 = st.columns(4)
c1.metric("Current MRR", f"${latest_mrr:,.2f}", f"{((latest_mrr - prev_mrr)/prev_mrr)*100:.1f}% MoM")
c2.metric("Average NRR", f"{avg_nrr:.1f}%", "Target > 100%")
c3.metric("Average GRR", f"{avg_grr:.1f}%", "Core Protection")
c4.metric("High-Risk Accounts", f"{len(df_churn[df_churn['health_tier'].str.contains('RISK')])} Accounts", "Action Required", delta_color="inverse")

tabs = st.tabs(["📊 MRR Waterfall", "🗓️ Cohort Retention Matrix", "📉 Unit Economics (NRR/GRR)", "🚨 Churn Early Warning", "💻 SQL Code Explorer"])

# TAB 1: MRR Waterfall
with tabs[0]:
    st.subheader("Monthly Recurring Revenue (MRR) Bridge")
    st.line_chart(df_mrr.set_index("activity_month")[["ending_mrr"]])
    st.bar_chart(df_mrr.set_index("activity_month")[["new_mrr", "expansion_mrr", "contraction_mrr", "churned_mrr"]])
    st.dataframe(df_mrr, use_container_width=True)

# TAB 2: Cohort Matrix
with tabs[1]:
    st.subheader("Triangular Cohort Retention Matrix (% Retained Users)")
    cohort_display = df_cohort.set_index("cohort_month").drop(columns=["cohort_size"])
    st.dataframe(
        cohort_display.style.background_gradient(cmap="Blues", vmin=30, vmax=100).format("{:.1f}%"),
        use_container_width=True
    )

# TAB 3: Unit Economics
with tabs[2]:
    st.subheader("Net Retention Rate (NRR) vs Gross Retention Rate (GRR)")
    st.line_chart(df_kpis.set_index("activity_month")[["nrr_pct", "grr_pct"]])
    st.dataframe(df_kpis, use_container_width=True)

# TAB 4: Churn Early Warning
with tabs[3]:
    st.subheader("Top At-Risk Accounts (Behavioral Churn Scoring)")
    st.dataframe(df_churn, use_container_width=True)

# TAB 5: Raw SQL Explorer
with tabs[4]:
    st.subheader("Production SQL Query Source Code")
    selected_query = st.selectbox(
        "Select Query:",
        [
            ("01_mrr_revenue_bridge.sql", "MRR Revenue Bridge / Waterfall"),
            ("02_cohort_retention_matrix.sql", "Triangular Cohort Retention Matrix"),
            ("03_nrr_grr_kpis.sql", "Executive KPIs (NRR & GRR)"),
            ("04_churn_health_score.sql", "Behavioral Churn Risk Scoring"),
            ("05_performance_tuning.sql", "Indexing & Optimization DDL")
        ],
        format_func=lambda x: f"{x[0]} - {x[1]}"
    )
    code = load_query(selected_query[0])
    st.code(code, language="sql")
