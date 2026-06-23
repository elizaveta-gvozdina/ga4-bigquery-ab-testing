/*
    Intermediate: Ecommerce Funnel Flags

    Maps each session to a set of binary flags indicating which
    funnel steps were reached:
    session_start → view_item → add_to_cart → begin_checkout → purchase.

    Captures revenue and transaction_id for sessions with a purchase.

    Grain: one row per (user_pseudo_id, session_id).
    Upstream: stg_ga4__events
*/

{{ config(materialized='table') }}

with events as (
    select * from {{ ref('stg_ga4__events') }}
),

-- pivot event names into binary flags per session
funnel as (
    select
        user_pseudo_id,
        session_id,

        -- funnel step flags (1 = reached, 0 = not reached)
        max(case when event_name = 'session_start'   then 1 else 0 end) as reached_session_start,
        max(case when event_name = 'view_item'        then 1 else 0 end) as reached_view_item,
        max(case when event_name = 'add_to_cart'      then 1 else 0 end) as reached_add_to_cart,
        max(case when event_name = 'begin_checkout'   then 1 else 0 end) as reached_begin_checkout,
        max(case when event_name = 'purchase'         then 1 else 0 end) as reached_purchase,

        -- purchase details (null when no purchase in session)
        max(case when event_name = 'purchase' then revenue_usd    end)   as revenue_usd,
        max(case when event_name = 'purchase' then transaction_id end)   as transaction_id

    from events
    where session_id is not null
    group by user_pseudo_id, session_id
)

select * from funnel
