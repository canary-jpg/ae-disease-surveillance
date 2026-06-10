with source as (
    select * from {{ source('surveillance', 'weekly_deaths') }}
),

renamed as (
    select
        jurisdiction,
        cast(week_ending_date as date) as week_ending_date,
        mmwr_year,
        mmwr_week,
        total_deaths,
        pneumonia_deaths,
        influenza_deaths,
        covid_deaths,
        pni_deaths,
        pni_covid_deaths,

        --derived
        round(
            safe_divide(influenza_deaths, total_deaths) * 100,
            3
        ) as pct_influenza,

        round(
            safe_divide(pneumonia_deaths, total_deaths) * 100,
            3
        ) as pct_pneumonia,

        round(
            safe_divide(covid_deaths, total_deaths) * 100,
            3
            ) as pct_covid
    from source
    where mmwr_year > 0
        and jurisdiction is not null 
)

select * from renamed