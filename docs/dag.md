# dbt Model Lineage (DAG)

```mermaid
graph LR
    %% Source
    SRC["ga4.events_*"]:::source

    %% Staging
    STG["stg_ga4__events"]:::staging

    %% Intermediate
    INT_S["int_sessions"]:::intermediate
    INT_F["int_user_funnel"]:::intermediate
    INT_AA["int_aa_test_groups"]:::intermediate

    %% Marts
    MART_F["mart_funnel_metrics"]:::mart
    MART_AA["mart_aa_test_results"]:::mart

    %% Edges
    SRC --> STG
    STG --> INT_S
    STG --> INT_F
    STG --> INT_AA
    INT_S --> MART_F
    INT_F --> MART_F
    INT_AA --> MART_F
    INT_F --> MART_AA
    INT_AA --> MART_AA

    %% Styles
    classDef source fill:#4A90D9,stroke:#2E5A88,color:#fff
    classDef staging fill:#CD7F32,stroke:#8B5A2B,color:#fff
    classDef intermediate fill:#C0C0C0,stroke:#808080,color:#000
    classDef mart fill:#DAA520,stroke:#B8860B,color:#fff
```

**Legend:**
- Blue — Source (BigQuery public dataset)
- Bronze — Staging (flattened, typed)
- Silver — Intermediate (sessions, funnel, A/A groups)
- Gold — Marts (aggregated metrics, statistical tests)
