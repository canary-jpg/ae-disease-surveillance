with source as (
    select * from {{ source('surveillance', 'mortality_by_state') }}
),

renamed as (
    select
        state,
        geoid,
        age,
        season,
        mmwr_year_week,
        year,
        week,
        pi_deaths,
        all_deaths,

        -- calculate pct_pi from raw counts since source column is 0
        round(
            safe_divide(pi_deaths, all_deaths) * 100,
            3
        )                                   as pct_pi,

        pct_complete,

        -- derive approximate date from year + week number
        date_add(
            date(cast(year as int64), 1, 1),
            interval (cast(week as int64) - 1) * 7 day
        )                                   as epiweek_date

    from source
    where year > 0
      and week > 0
)

select * from renamed