with weekly as (
    select * from {{ ref('fct_weekly_deaths') }}
),

-- CUMSUM (cumulative sum) anomaly detection
--flags sustained deviations from baseline
cumsum as (
    select 
        *,
        --CUMSUM stat: accumulates positive deviations from baseline
        --resets to 0 when below threshold
        sum(
            greatest(zscore_influenza - 0.5, 0)
        ) over (
            order by week_ending_date 
            rows between 7 preceding and current row 
        ) as cumsum_influenza,

        sum(
            greatest(zscore_pneumonia - 0.5, 0)
        ) over (
            order by week_ending_date 
            rows between 7 preceding and current row 
        ) as cumsum_pneumonia 
    from weekly 
    where zscore_influenza is not null 
),

final as (
    select 
        week_ending_date,
        mmwr_year,
        mmwr_week,
        flu_season_period,
        pct_influenza,
        pct_pneumonia,
        pct_covid,
        rolling_4w_pct_influenza,
        zscore_influenza,
        zscore_pneumonia,
        cumsum_influenza,
        cumsum_pneumonia,
        wow_change_influenza,

        --z-score based outbreak flags (sigle week spike)
        zscore_influenza > 2.0 as zscore_flag_influenza,
        zscore_pneumonia > 2.0 as zscore_flag_pneumonia,

        --CUMSUM based outbreak flags (sustained elevation)
        cumsum_influenza > 3.0 as cumsum_flag_influenza,
        cumsum_pneumonia > 3.0 as cumsum_flag_pneumoia,

        --combined outbreak alert
        case 
            when zscore_influenza > 3.0 
                or cumsum_influenza > 5.0 then 'high_alert'
            when zscore_influenza > 2.0
                or cumsum_influenza > 3.0 then 'elevated'
            when zscore_influenza > 3.0
                or cumsum_influenza > 1.0 then 'watch'
            else 'normal' 
        end as alert_level,

        --consecutive weeks above threshol
        sum(case when zscore_influenza > 1.0 then 1 else 0 end) over (
            order by week_ending_date 
            rows between 7 preceding and current row 
        ) as weeks_eleveated_last_8
    from cumsum 
)

select * from final