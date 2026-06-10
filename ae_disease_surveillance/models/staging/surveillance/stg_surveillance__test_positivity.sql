with source as (
    select * from {{ source('surveillance', 'test_positivity') }}
),

renamed as (
    select 
        cast(week_end as date) as week_end,
        pathogen,
        pct_positive,

        --extract year and week for joining
        extract(year from cast(week_end as date)) as year,
        extract(week from cast(week_end as date)) as week 
    from source 
    where week_end is not null 
        and pathogen is not null 
)

select * from renamed 

