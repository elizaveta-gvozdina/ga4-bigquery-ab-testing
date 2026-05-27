{{ config(materialized='table') }}

-- A/B test statistical summary for the primary metric: purchase conversion rate.
-- Uses two-proportion z-test. P-value approximation via ERF (available in BigQuery).
-- For full analysis (bootstrap, multiple metrics) use the Python notebook.

with funnel as (
    select * from {{ ref('int_user_funnel') }}
),

ab_groups as (
    select * from {{ ref('int_ab_test_groups') }}
),

combined as (
    select
        f.*,
        a.ab_group
    from funnel f
    left join ab_groups a using (user_pseudo_id)
),

group_stats as (
    select
        ab_group,
        count(distinct concat(user_pseudo_id, cast(session_id as string))) as n_sessions,
        sum(reached_purchase)                                               as n_conversions,
        safe_divide(
            sum(reached_purchase),
            count(distinct concat(user_pseudo_id, cast(session_id as string)))
        )                                                                   as conversion_rate,
        round(sum(revenue_usd), 2)                                          as total_revenue_usd,
        round(safe_divide(sum(revenue_usd), nullif(sum(reached_purchase), 0)), 2) as avg_order_value_usd
    from combined
    group by ab_group
),

pivoted as (
    select
        max(if(ab_group = 'control',   n_sessions,       null)) as ctrl_sessions,
        max(if(ab_group = 'control',   n_conversions,    null)) as ctrl_conversions,
        max(if(ab_group = 'control',   conversion_rate,  null)) as ctrl_rate,
        max(if(ab_group = 'control',   total_revenue_usd, null)) as ctrl_revenue_usd,
        max(if(ab_group = 'control',   avg_order_value_usd, null)) as ctrl_aov_usd,

        max(if(ab_group = 'treatment', n_sessions,       null)) as test_sessions,
        max(if(ab_group = 'treatment', n_conversions,    null)) as test_conversions,
        max(if(ab_group = 'treatment', conversion_rate,  null)) as test_rate,
        max(if(ab_group = 'treatment', total_revenue_usd, null)) as test_revenue_usd,
        max(if(ab_group = 'treatment', avg_order_value_usd, null)) as test_aov_usd
    from group_stats
),

with_pooled as (
    select
        *,
        (ctrl_conversions + test_conversions) / (ctrl_sessions + test_sessions) as pooled_rate
    from pivoted
),

with_z as (
    select
        *,
        safe_divide(
            test_rate - ctrl_rate,
            sqrt(pooled_rate * (1 - pooled_rate) * (1 / ctrl_sessions + 1 / test_sessions))
        ) as z_score
    from with_pooled
)

select
    -- sample sizes
    ctrl_sessions,
    ctrl_conversions,
    round(ctrl_rate * 100, 4)              as ctrl_conversion_rate_pct,
    ctrl_revenue_usd,
    ctrl_aov_usd,

    test_sessions,
    test_conversions,
    round(test_rate * 100, 4)              as test_conversion_rate_pct,
    test_revenue_usd,
    test_aov_usd,

    -- lift
    round((test_rate - ctrl_rate) * 100, 4)            as absolute_lift_pct,
    round(safe_divide(test_rate - ctrl_rate, ctrl_rate) * 100, 2) as relative_lift_pct,

    -- z-test
    round(z_score, 4)                      as z_score,

    -- two-tailed p-value via complementary error function: p = erfc(|z| / sqrt(2))
    round(erfc(abs(z_score) / sqrt(2)), 4) as p_value,

    -- significance flags
    abs(z_score) > 1.645                   as is_significant_90,
    abs(z_score) > 1.960                   as is_significant_95,
    abs(z_score) > 2.576                   as is_significant_99

from with_z
