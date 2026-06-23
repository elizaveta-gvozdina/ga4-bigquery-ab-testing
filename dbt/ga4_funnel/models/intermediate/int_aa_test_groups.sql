/*
    Intermediate: A/A Test Group Assignment

    Deterministically splits users into two groups (control / treatment)
    using FARM_FINGERPRINT hash. Both groups saw the same website —
    this is an A/A test to validate the pipeline and confirm
    no statistically significant difference between identical experiences.

    Grain: one row per user_pseudo_id.
    Upstream: stg_ga4__events
*/

{{ config(materialized='table') }}

-- get distinct users from all events
with users as (
    select distinct user_pseudo_id
    from {{ ref('stg_ga4__events') }}
),

-- assign group via deterministic hash (same user → same group every run)
assigned as (
    select
        user_pseudo_id,
        case
            when mod(abs(farm_fingerprint(user_pseudo_id)), 2) = 0 then 'control'
            else 'treatment'
        end as aa_group
    from users
)

select * from assigned
