with forecasts as (
    select * from `ae-project-portfolio.surveillance_raw.influenza_forecasts`
),
final as (
    select 
        cast(forecast_date as date) as forecast_date,
        forecast_pct_influenza,
        forecast_lower,
        forecast_upper,
        model,
        target,
        horizon_weeks,
        created_at,

        --prediction interval width (measure of uncertainty)
        round(
            forecast_upper - forecast_lower,
            3
        ) as prediction_interval_width,

        --alert flag if forecast exceeds historical threshold
        case 
            when forecast_pct_influenza > 8.0 then 'high_alert'
            when forecast_pct_influenza > 5.0 then 'elevated'
            when forecast_pct_influenza > 3.0 then 'watch'
            else 'normal'
        end as forecast_alert_level 
    from forecasts 
)

select * from final