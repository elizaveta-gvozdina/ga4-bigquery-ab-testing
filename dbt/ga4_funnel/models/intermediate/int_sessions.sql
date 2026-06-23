/*
    Intermediate: Session Aggregation

    Aggregates GA4 events to session level. Computes session duration,
    pageview count, engagement flag, and captures first observed
    traffic source, device, and geo attributes per session.

    Grain: one row per (user_pseudo_id, session_id).
    Upstream: stg_ga4__events
*/

{{ config(materialized='table') }}

with events as (
    select * from {{ ref('stg_ga4__events') }}
),

-- aggregate event-level data to one row per session
sessions as (
    select
        user_pseudo_id,
        session_id,

        -- session timing
        min(event_timestamp)                                                           as session_start_at,
        max(event_timestamp)                                                           as session_end_at,
        timestamp_diff(max(event_timestamp), min(event_timestamp), second)             as session_duration_seconds,

        -- activity metrics
        countif(event_name = 'page_view')                                              as pageviews,
        max(if(session_engaged = '1', 1, 0))                                           as is_engaged,

        -- acquisition (first non-null value in session)
        max(traffic_source)                                                            as traffic_source,
        max(traffic_medium)                                                            as traffic_medium,
        max(traffic_campaign)                                                          as traffic_campaign,

        -- device & geo context
        max(device_category)                                                           as device_category,
        max(operating_system)                                                          as operating_system,
        max(browser)                                                                   as browser,
        max(country)                                                                   as country,
        max(city)                                                                      as city

    from events
    where session_id is not null
    group by user_pseudo_id, session_id
)

select * from sessions
