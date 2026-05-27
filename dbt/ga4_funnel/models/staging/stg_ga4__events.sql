{{ config(materialized='view') }}

with source as (
    select *
    from `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    where _TABLE_SUFFIX between '20201101' and '20210131'
),

flattened as (
    select
        event_date,
        timestamp_micros(event_timestamp)                                                          as event_timestamp,
        event_name,
        user_pseudo_id,

        -- session identifiers
        (select value.int_value    from unnest(event_params) where key = 'ga_session_id')          as session_id,
        (select value.int_value    from unnest(event_params) where key = 'ga_session_number')      as session_number,

        -- page
        (select value.string_value from unnest(event_params) where key = 'page_location')          as page_location,
        (select value.string_value from unnest(event_params) where key = 'page_title')             as page_title,

        -- engagement
        (select value.int_value    from unnest(event_params) where key = 'engagement_time_msec')   as engagement_time_msec,
        (select value.string_value from unnest(event_params) where key = 'session_engaged')        as session_engaged,

        -- ecommerce
        ecommerce.transaction_id,
        ecommerce.purchase_revenue_in_usd                                                          as revenue_usd,

        -- acquisition
        traffic_source.source      as traffic_source,
        traffic_source.medium      as traffic_medium,
        traffic_source.name        as traffic_campaign,

        -- device
        device.category            as device_category,
        device.operating_system,
        device.browser,

        -- geo
        geo.country,
        geo.city

    from source
)

select * from flattened
