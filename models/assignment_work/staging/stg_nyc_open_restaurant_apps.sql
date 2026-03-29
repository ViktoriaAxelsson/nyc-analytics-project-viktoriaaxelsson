-- Clean and standardize Open Restaurant Applications data
-- One row per application record

WITH source AS (
    SELECT *
    FROM {{ source('raw', 'source_nyc_open_restaurant_apps') }}
),

cleaned AS (
    SELECT
        * EXCEPT (
            objectid,
            globalid,
            time_of_submission,
            latitude,
            longitude,
            zip,
            borough,
            restaurant_name,
            legal_business_name,
            doing_business_as_dba,
            approved_for_roadway_seating,
            approved_for_sidewalk_seating,
            seating_interest_sidewalk,
            sidewalk_dimensions_length,
            sidewalk_dimensions_width,
            sidewalk_dimensions_area,
            roadway_dimensions_length,
            roadway_dimensions_width,
            roadway_dimensions_area
        ),

        -- identifiers
        CAST(objectid AS STRING) AS application_id,
        CAST(globalid AS STRING) AS global_id,

        -- datetime
        CAST(time_of_submission AS TIMESTAMP) AS submitted_at,

        -- business names
        UPPER(TRIM(CAST(restaurant_name AS STRING))) AS restaurant_name,
        UPPER(TRIM(CAST(legal_business_name AS STRING))) AS legal_business_name,
        UPPER(TRIM(CAST(doing_business_as_dba AS STRING))) AS dba_name,

        -- coordinates
        CAST(latitude AS FLOAT64) AS latitude,
        CAST(longitude AS FLOAT64) AS longitude,

        -- dimensions
        CAST(sidewalk_dimensions_length AS FLOAT64) AS sidewalk_dimensions_length,
        CAST(sidewalk_dimensions_width AS FLOAT64) AS sidewalk_dimensions_width,
        CAST(sidewalk_dimensions_area AS FLOAT64) AS sidewalk_dimensions_area,
        CAST(roadway_dimensions_length AS FLOAT64) AS roadway_dimensions_length,
        CAST(roadway_dimensions_width AS FLOAT64) AS roadway_dimensions_width,
        CAST(roadway_dimensions_area AS FLOAT64) AS roadway_dimensions_area,

        -- simple flag cleanup
        UPPER(TRIM(CAST(approved_for_roadway_seating AS STRING))) AS approved_for_roadway_seating,
        UPPER(TRIM(CAST(approved_for_sidewalk_seating AS STRING))) AS approved_for_sidewalk_seating,
        UPPER(TRIM(CAST(seating_interest_sidewalk AS STRING))) AS seating_interest_sidewalk,

        -- zip cleanup
        CASE
            WHEN zip IS NULL THEN NULL
            WHEN UPPER(TRIM(CAST(zip AS STRING))) IN ('N/A', 'NA', 'UNKNOWN', '') THEN NULL
            WHEN REGEXP_CONTAINS(CAST(zip AS STRING), r'^\d{5}$') THEN CAST(zip AS STRING)
            WHEN REGEXP_CONTAINS(CAST(zip AS STRING), r'^\d{5}-\d{4}$') THEN CAST(zip AS STRING)
            ELSE NULL
        END AS zip,

        -- borough cleanup
        CASE
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(CAST(borough AS STRING))) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'Unknown'
        END AS borough,

        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source
    WHERE objectid IS NOT NULL
      AND time_of_submission IS NOT NULL

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY objectid
        ORDER BY time_of_submission DESC
    ) = 1
)

SELECT * FROM cleaned