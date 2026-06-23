/*
    Staging: GA4 Event Flattening

    Transforms raw GA4 BigQuery export into a flat, typed event table.
    Extracts nested event_params (session ID, page info, engagement),
    unpacks ecommerce, device, geo, and traffic_source structs.
    Filtered to Nov 2020 – Jan 2021 via _TABLE_SUFFIX.

    Grain: one row per event.
    Source: bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*
*/

{{ config(materialized='table') }}

-- pull raw events from GA4 public dataset, filtered by date range
with source as (
    select *
    from {{ source('ga4', 'events') }}
    where _TABLE_SUFFIX between '20201101' and '20210131'
),

-- flatten nested structs and extract event_params into typed columns
flattened as (
    select
        event_date,
        timestamp_micros(event_timestamp)                                                          as event_timestamp,
        event_name,
        user_pseudo_id,

        -- session identifiers from event_params
        (select value.int_value    from unnest(event_params) where key = 'ga_session_id')          as session_id,
        (select value.int_value    from unnest(event_params) where key = 'ga_session_number')      as session_number,

        -- page context
        (select value.string_value from unnest(event_params) where key = 'page_location')          as page_location,
        (select value.string_value from unnest(event_params) where key = 'page_title')             as page_title,

        -- engagement metrics
        (select value.int_value    from unnest(event_params) where key = 'engagement_time_msec')   as engagement_time_msec,
        (select value.string_value from unnest(event_params) where key = 'session_engaged')        as session_engaged,

        -- ecommerce fields (non-null only for purchase events)
        ecommerce.transaction_id,
        ecommerce.purchase_revenue_in_usd                                                          as revenue_usd,

        -- first-touch acquisition attributes
        traffic_source.source      as traffic_source,
        traffic_source.medium      as traffic_medium,
        traffic_source.name        as traffic_campaign,

        -- device info
        device.category            as device_category,
        device.operating_system,
        device.web_info.browser,

        -- geolocation from IP
        geo.country,
        geo.city

    from source
)

select * from flattened
