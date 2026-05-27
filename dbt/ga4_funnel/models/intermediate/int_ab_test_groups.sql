{{ config(materialized='table') }}

-- Deterministic A/B group assignment based on user_pseudo_id.
-- FARM_FINGERPRINT ensures the same user always lands in the same group
-- across all runs (no randomness drift).

with users as (
    select distinct user_pseudo_id
    from {{ ref('stg_ga4__events') }}
),

assigned as (
    select
        user_pseudo_id,
        case
            when mod(abs(farm_fingerprint(user_pseudo_id)), 2) = 0 then 'control'
            else 'treatment'
        end as ab_group
    from users
)

select * from assigned
