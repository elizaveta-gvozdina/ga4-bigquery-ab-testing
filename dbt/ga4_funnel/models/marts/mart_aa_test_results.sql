/*
    Mart: A/A Test Statistical Results

    Compares control vs treatment groups on the primary metric:
    purchase conversion rate. Since both groups saw the same website,
    we expect NO statistically significant difference (p > 0.05).
    A significant result would indicate bias in the splitting method.

    Uses two-proportion z-test with p-value via BigQuery ERFC function.
    Outputs significance flags at 90%, 95%, and 99% confidence levels.

    Grain: single row (one comparison).
    Upstream: int_user_funnel, int_aa_test_groups
*/

{{ config(materialized='table') }}

with funnel as (
    select * from {{ ref('int_user_funnel') }}
),

aa_groups as (
    select * from {{ ref('int_aa_test_groups') }}
),

-- attach group labels to funnel data
combined as (
    select
        f.*,
        a.aa_group
    from funnel f
    left join aa_groups a using (user_pseudo_id)
),

-- compute conversion stats per group
group_stats as (
    select
        aa_group,
        count(distinct concat(user_pseudo_id, cast(session_id as string))) as n_sessions,
        sum(reached_purchase)                                               as n_conversions,
        safe_divide(
            sum(reached_purchase),
            count(distinct concat(user_pseudo_id, cast(session_id as string)))
        )                                                                   as conversion_rate,
        round(sum(revenue_usd), 2)                                          as total_revenue_usd,
        round(safe_divide(sum(revenue_usd), nullif(sum(reached_purchase), 0)), 2) as avg_order_value_usd
    from combined
    group by aa_group
),

-- pivot into control vs treatment columns for comparison
pivoted as (
    select
        max(if(aa_group = 'control',   n_sessions,       null)) as ctrl_sessions,
        max(if(aa_group = 'control',   n_conversions,    null)) as ctrl_conversions,
        max(if(aa_group = 'control',   conversion_rate,  null)) as ctrl_rate,
        max(if(aa_group = 'control',   total_revenue_usd, null)) as ctrl_revenue_usd,
        max(if(aa_group = 'control',   avg_order_value_usd, null)) as ctrl_aov_usd,

        max(if(aa_group = 'treatment', n_sessions,       null)) as test_sessions,
        max(if(aa_group = 'treatment', n_conversions,    null)) as test_conversions,
        max(if(aa_group = 'treatment', conversion_rate,  null)) as test_rate,
        max(if(aa_group = 'treatment', total_revenue_usd, null)) as test_revenue_usd,
        max(if(aa_group = 'treatment', avg_order_value_usd, null)) as test_aov_usd
    from group_stats
),

-- compute pooled conversion rate for z-test denominator
with_pooled as (
    select
        *,
        (ctrl_conversions + test_conversions) / (ctrl_sessions + test_sessions) as pooled_rate
    from pivoted
),

-- two-proportion z-test
with_z as (
    select
        *,
        safe_divide(
            test_rate - ctrl_rate,
            sqrt(pooled_rate * (1 - pooled_rate) * (1 / ctrl_sessions + 1 / test_sessions))
        ) as z_score
    from with_pooled
)

-- final output with p-value and significance flags
select
    -- control group
    ctrl_sessions,
    ctrl_conversions,
    round(ctrl_rate * 100, 4)              as ctrl_conversion_rate_pct,
    ctrl_revenue_usd,
    ctrl_aov_usd,

    -- treatment group
    test_sessions,
    test_conversions,
    round(test_rate * 100, 4)              as test_conversion_rate_pct,
    test_revenue_usd,
    test_aov_usd,

    -- lift metrics
    round((test_rate - ctrl_rate) * 100, 4)            as absolute_lift_pct,
    round(safe_divide(test_rate - ctrl_rate, ctrl_rate) * 100, 2) as relative_lift_pct,

    -- z-test results
    round(z_score, 4)                      as z_score,

    -- significance flags (expect all FALSE for a valid A/A test)
    -- exact p-value is computed in the Python notebook via scipy.stats
    abs(z_score) > 1.645                   as is_significant_90,
    abs(z_score) > 1.960                   as is_significant_95,
    abs(z_score) > 2.576                   as is_significant_99

from with_z
