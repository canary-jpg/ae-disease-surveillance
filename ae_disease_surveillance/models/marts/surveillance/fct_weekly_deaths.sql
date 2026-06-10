with weekly_deaths as (
    select * from {{ ref('stg_surveillance__weekly_deaths') }}
),

--get national totals only for baseline calculation
national as (
    select 
        week_ending_date,
        mmwr_year,
        mmwr_week,
        total_deaths,
        pneumonia_deaths,
        influenza_deaths,
        covid_deaths,
        pni_deaths,
        pni_covid_deaths,
        pct_influenza,
        pct_pneumonia,
        pct_covid
    from weekly_deaths 
    where jurisdiction = 'United States'
),

--rolling averages and z-scores for anomaly detection
with_rolling as (
    select 
        *,

        --4-week rolling averages
        avg(pct_influenza) over (
            order by week_ending_date 
            rows between 3 preceding and current row 
        ) as rolling_4w_pct_influenza,

        avg(pct_pneumonia) over (
            order by week_ending_date
            rows between 3 preceding and current row 
        ) as rolling_4w_pct_pneumonia,

        avg(pct_covid) over (
            order by week_ending_date 
            rows between 3 preceding and current row 
        ) as rolling_4w_pct_covid,

        --52 week rolling mean and stddev for z-score calculation
        avg(pct_influenza) over (
            order by week_ending_date 
            rows between 51 preceding and current row 
        ) as baseline_mean_influenza,

        stddev(pct_influenza) over (
            order by week_ending_date 
            rows between 51 preceding and current row 
        ) as baseline_std_influenza,

        avg(pct_pneumonia) over (
            order by week_ending_date 
            rows between 51 preceding and current row 
        ) as baseline_mean_pneumonia,

        stddev(pct_pneumonia) over (
            order by week_ending_date 
            rows between 51 preceding and current row 
        ) as baseline_std_pneumonia,

        --WoW change 
        lag(pct_influenza) over (
            order by week_ending_date
        ) as prev_week_pct_influenza,

        lag(pct_pneumonia) over (
            order by week_ending_date
        ) as prev_week_pct_pneumonia
    from national 
),

final as (
    select 
        week_ending_date,
        mmwr_year,
        mmwr_week,
        total_deaths,
        pneumonia_deaths,
        influenza_deaths,
        covid_deaths,
        pni_deaths,
        pni_covid_deaths,
        pct_influenza,
        pct_pneumonia,
        pct_covid,
        rolling_4w_pct_influenza,
        rolling_4w_pct_pneumonia,
        rolling_4w_pct_covid,
        baseline_mean_influenza,
        baseline_std_influenza,
        baseline_mean_pneumonia,
        baseline_std_pneumonia,

        --z-scores
        round(
            safe_divide(
                pct_influenza - baseline_mean_influenza,
                baseline_std_influenza
            ), 3
        ) as zscore_influenza,

        round(
            safe_divide(
                pct_pneumonia - baseline_mean_pneumonia,
                baseline_std_pneumonia
            ), 3
        ) as zscore_pneumonia,

        --WoW Change
        round(pct_influenza - prev_week_pct_influenza, 3) as wow_change_influenza,
        round(pct_pneumonia - prev_week_pct_pneumonia, 3) as wow_change_pneumonia,

        --season classification
        case
            when mmwr_week between 40 and 52 then 'early_season'
            when mmwr_week between 1 and 20 then 'peak_season'
            else 'off_season'
        end as flu_season_period
    from with_rolling
)

select * from final