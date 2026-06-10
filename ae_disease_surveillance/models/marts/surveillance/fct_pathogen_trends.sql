with test_pos as (
    select * from {{ ref('stg_surveillance__test_positivity') }}
),

with_rolling as (
    select 
        week_end,
        year,
        week,
        pathogen,
        pct_positive,

        --4 week rolling average
        avg(pct_positive) over (
            partition by pathogen 
            order by week_end 
            rows between 3 preceding and current row 
        ) as rolling_4w_pct_positive,

        --WoW change
        lag(pct_positive) over (
            partition by pathogen 
            order by week_end 
        ) as prev_week_pct_positive,

        --52 week baseline 
        avg(pct_positive) over (
            partition by pathogen 
            order by week_end 
            rows between 51 preceding and current row 
        ) as baseline_mean,

        stddev(pct_positive) over (
            partition by pathogen 
            order by week_end 
            rows between 51 preceding and current row 
        ) as baseline_std
    from test_pos

),

final as (
    select 
        week_end,
        year,
        week,
        pathogen,
        pct_positive,
        rolling_4w_pct_positive,
        prev_week_pct_positive,
        baseline_mean,
        baseline_std,
        round(pct_positive - prev_week_pct_positive, 2) as wow_change,
        round(
            safe_divide(
                pct_positive - baseline_mean,
                baseline_std 
            ), 3
        ) as zscore,

        case 
            when safe_divide(
                pct_positive - baseline_mean,
                baseline_std 
            ) > 2.0 then 'elevated'
            when safe_divide(
                pct_positive - baseline_mean,
                baseline_std
            ) > 1.0 then 'watch'
            else 'normal'
        end as signal_level 
    from with_rolling 
)

select * from final 