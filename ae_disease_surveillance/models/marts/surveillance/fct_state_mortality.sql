with mortality as (
    select * from {{ ref('stg_surveillance__mortality_by_state') }}
),

state_level as (
    select *
    from mortality
    where geoid = 'State'
      and age = 'All'
),

with_rolling as (
    select
        *,

        avg(pct_pi) over (
            partition by state
            order by epiweek_date
            rows between 3 preceding and current row
        )                                   as rolling_4w_pct_pi,

        lag(pct_pi, 52) over (
            partition by state
            order by epiweek_date
        )                                   as pct_pi_prior_year,

        rank() over (
            partition by mmwr_year_week
            order by pct_pi desc
        )                                   as state_rank_this_week

    from state_level
),

final as (
    select
        state,
        season,
        mmwr_year_week,
        year,
        week,
        epiweek_date,
        pi_deaths,
        all_deaths,
        pct_pi,
        rolling_4w_pct_pi,
        pct_pi_prior_year,
        state_rank_this_week,

        round(pct_pi - pct_pi_prior_year, 3) as yoy_change_pct_pi,

        case
            when pct_pi > pct_pi_prior_year then 'above_prior_year'
            when pct_pi < pct_pi_prior_year then 'below_prior_year'
            else                                 'same_as_prior_year'
        end                                 as yoy_direction

    from with_rolling
)

select * from final
