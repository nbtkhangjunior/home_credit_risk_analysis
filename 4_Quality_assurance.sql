WITH
    source_grains AS (
        SELECT
            'raw.application' AS source_table,
            COUNT(*) AS row_count,
            COUNT(DISTINCT SK_ID_CURR) AS unique_customers
        FROM
            raw.application
        UNION ALL
        SELECT
            'analytics.applicant',
            COUNT(*),
            COUNT(DISTINCT SK_ID_CURR)
        FROM
            analytics.applicant
        UNION ALL
        SELECT
            'analytics.affordability',
            COUNT(*),
            COUNT(DISTINCT SK_ID_CURR)
        FROM
            analytics.affordability
        UNION ALL
        SELECT
            'analytics.employment',
            COUNT(*),
            COUNT(DISTINCT SK_ID_CURR)
        FROM
            analytics.employment
        UNION ALL
        SELECT
            'analytics.existing_indebtedness',
            COUNT(*),
            COUNT(DISTINCT SK_ID_CURR)
        FROM
            analytics.existing_indebtedness
        UNION ALL
        SELECT
            'analytics.assets',
            COUNT(*),
            COUNT(DISTINCT SK_ID_CURR)
        FROM
            analytics.assets
        UNION ALL
        SELECT
            'analytics.delinquency_inst',
            COUNT(*),
            COUNT(DISTINCT SK_ID_CURR)
        FROM
            analytics.delinquency_inst
        UNION ALL
        SELECT
            'analytics.delinquency_bureau',
            COUNT(*),
            COUNT(DISTINCT SK_ID_CURR)
        FROM
            analytics.delinquency_bureau
        UNION ALL
        SELECT
            'analytics.delinquency_pos',
            COUNT(*),
            COUNT(DISTINCT SK_ID_CURR)
        FROM
            analytics.delinquency_pos
        UNION ALL
        SELECT
            'analytics.delinquency_cc',
            COUNT(*),
            COUNT(DISTINCT SK_ID_CURR)
        FROM
            analytics.delinquency_cc
        UNION ALL
        SELECT
            'analytics.payment_adequacy',
            COUNT(*),
            COUNT(DISTINCT SK_ID_CURR)
        FROM
            analytics.payment_adequacy
        UNION ALL
        SELECT
            'analytics.credit_utilization',
            COUNT(*),
            COUNT(DISTINCT SK_ID_CURR)
        FROM
            analytics.credit_utilization
    )
SELECT
    source_table,
    row_count,
    unique_customers,
    row_count - unique_customers AS duplicate_or_null_key_rows
FROM
    source_grains
ORDER BY
    source_table;

CREATE SCHEMA IF NOT EXISTS modeling;

CREATE OR REPLACE TABLE modeling.home_credit_dataset AS
SELECT
    ra.SK_ID_CURR,
    ra.TARGET,
    ra.dataset_split,
    aaf.* exclude (SK_ID_CURR, TARGET),
    aap.* EXCLUDE (SK_ID_CURR, TARGET),
    ae.* Exclude (SK_ID_CURR),
    aei.* Exclude (SK_ID_CURR),
    aas.* Exclude (SK_ID_CURR),
    adi.* Exclude (SK_ID_CURR),
    adb.* Exclude (SK_ID_CURR),
    adp.* Exclude (SK_ID_CURR),
    adc.* Exclude (SK_ID_CURR),
    apa.* Exclude (SK_ID_CURR),
    acu.* Exclude (SK_ID_CURR)
FROM
    raw.application ra
    LEFT JOIN analytics.affordability aaf ON aaf.SK_ID_CURR = ra.SK_ID_CURR
    LEFT JOIN analytics.applicant aap ON aap.SK_ID_CURR = ra.SK_ID_CURR
    LEFT JOIN analytics.employment ae ON ae.SK_ID_CURR = ra.SK_ID_CURR
    LEFT JOIN analytics.existing_indebtedness aei ON aei.SK_ID_CURR = ra.SK_ID_CURR
    LEFT JOIN analytics.assets aas ON aas.SK_ID_CURR = ra.SK_ID_CURR
    LEFT JOIN analytics.delinquency_inst adi ON adi.SK_ID_CURR = ra.SK_ID_CURR
    LEFT JOIN analytics.delinquency_bureau adb ON adb.SK_ID_CURR = ra.SK_ID_CURR
    LEFT JOIN analytics.delinquency_pos adp ON adp.SK_ID_CURR = ra.SK_ID_CURR
    LEFT JOIN analytics.delinquency_cc adc ON adc.SK_ID_CURR = ra.SK_ID_CURR
    LEFT JOIN analytics.payment_adequacy apa ON apa.SK_ID_CURR = ra.SK_ID_CURR
    LEFT JOIN analytics.credit_utilization acu ON acu.SK_ID_CURR = ra.SK_ID_CURR;

-- Check again 
SELECT
    (
        SELECT
            Count(*)
        FROM
            raw.application
    ) AS base_rows,
    Count(*) AS model_rows,
    Count(DISTINCT SK_ID_CURR) AS unique_customers,
    Count(*) - Count(DISTINCT SK_ID_CURR) AS missing_rows
FROM
    modeling.home_credit_dataset;

SELECT
    dataset_split,
    COUNT(*) AS rows_count,
    COUNT(TARGET) AS labeled_rows,
    SUM(
        CASE
            WHEN TARGET = 1 THEN 1
            ELSE 0
        END
    ) AS defaults_count,
    AVG(CAST(TARGET AS DOUBLE)) AS default_rate
FROM
    modeling.home_credit_dataset
GROUP BY
    dataset_split
ORDER BY
    dataset_split;

WITH
    cc_history AS (
        SELECT
            SK_ID_CURR,
            MAX(
                CASE
                    WHEN AMT_CREDIT_LIMIT_ACTUAL > 0 THEN 1
                    ELSE 0
                END
            ) AS has_valid_limit
        FROM
            raw.credit_card_balance ccb
        WHERE
            MONTHS_BALANCE <= 0
        GROUP BY
            SK_ID_CURR
    )
SELECT
    a.dataset_split,
    COUNT(*) AS total_customers,
    ROUND(
        100.0 * COUNT(*) FILTER(
            WHERE
                c.SK_ID_CURR IS NULL
        ) / COUNT(*),
        2
    ) AS pct_no_cc_history,
    ROUND(
        100.0 * COUNT(*) FILTER(
            WHERE
                c.SK_ID_CURR IS NOT NULL
                AND c.has_valid_limit = 0
        ) / COUNT(*),
        2
    ) AS pct_no_valid_limit,
    ROUND(
        100.0 * COUNT(*) FILTER(
            WHERE
                c.has_valid_limit = 1
        ) / COUNT(*),
        2
    ) AS pct_usable_history
FROM
    raw.application a
    LEFT JOIN cc_history c ON a.SK_ID_CURR = c.SK_ID_CURR
GROUP BY
    a.dataset_split;