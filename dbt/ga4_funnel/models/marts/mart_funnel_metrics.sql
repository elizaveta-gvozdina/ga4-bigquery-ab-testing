{{ config(materialized='table') }}

-- Funnel conversion rates per A/B group.
-- Each step rate is calculated relative to the previous step (step-over-step).

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

aggregated as (
    select
        ab_group,
        count(distinct concat(user_pseudo_id, cast(session_id as string))) as total_sessions,
        sum(reached_session_start)   as n_session_start,
        sum(reached_view_item)       as n_view_item,
        sum(reached_add_to_cart)     as n_add_to_cart,
        sum(reached_begin_checkout)  as n_begin_checkout,
        sum(reached_purchase)        as n_purchase,
        round(sum(revenue_usd), 2)   as total_revenue_usd
    from combined
    group by ab_group
)

select
    ab_group,
    total_sessions,
    n_session_start,
    n_view_item,
    n_add_to_cart,
    n_begin_checkout,
    n_purchase,
    total_revenue_usd,

    -- step-over-step conversion rates
    round(safe_divide(n_view_item,      n_session_start)  * 100, 2) as view_item_rate_pct,
    round(safe_divide(n_add_to_cart,    n_view_item)      * 100, 2) as add_to_cart_rate_pct,
    round(safe_divide(n_begin_checkout, n_add_to_cart)    * 100, 2) as begin_checkout_rate_pct,
    round(safe_divide(n_purchase,       n_begin_checkout) * 100, 2) as purchase_rate_pct,

    -- end-to-end conversion (session → purchase)
    round(safe_divide(n_purchase, total_sessions) * 100, 2)         as overall_conversion_rate_pct,

    -- revenue metrics
    round(safe_divide(total_revenue_usd, n_purchase), 2)            as avg_order_value_usd,
    round(safe_divide(total_revenue_usd, total_sessions), 2)        as revenue_per_session_usd

from aggregated
