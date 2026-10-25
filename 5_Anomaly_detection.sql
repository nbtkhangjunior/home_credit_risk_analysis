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
            raw.credit_card_balance
        WHERE
            MONTHS_BALANCE <= 0
        GROUP BY
            SK_ID_CURR
    )
SELECT
    a.dataset_split,
    COUNT(*) AS total_customers,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN c.SK_ID_CURR IS NULL THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS pct_no_cc_history,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN c.SK_ID_CURR IS NOT NULL
                AND c.has_valid_limit = 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS pct_no_valid_limit,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN c.has_valid_limit = 1 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS pct_usable_history
FROM
    raw.application a
    LEFT JOIN cc_history c ON a.SK_ID_CURR = c.SK_ID_CURR
GROUP BY
    a.dataset_split;

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
            raw.credit_card_balance
        WHERE
            MONTHS_BALANCE <= 0
        GROUP BY
            SK_ID_CURR
    ),
    customer_groups AS (
        SELECT
            a.SK_ID_CURR,
            a.TARGET,
            CASE
                WHEN c.SK_ID_CURR IS NULL THEN 'No CC History'
                WHEN c.has_valid_limit = 0 THEN 'No Valid Limit'
                ELSE 'Usable CC History'
            END AS cc_group
        FROM
            raw.application a
            LEFT JOIN cc_history c ON a.SK_ID_CURR = c.SK_ID_CURR
        WHERE
            a.dataset_split = 'train'
    )
SELECT
    cc_group,
    COUNT(*) AS customers,
    SUM(
        CASE
            WHEN TARGET = 1 THEN 1
            ELSE 0
        END
    ) AS defaults,
    ROUND(AVG(TARGET) * 100, 2) AS default_rate_pct
FROM
    customer_groups
GROUP BY
    cc_group
ORDER BY
    default_rate_pct DESC;

SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER(
        WHERE
            DAYS_EMPLOYED = 365243
    ) AS sentinel_count,
    ROUND(
        100.0 * COUNT(*) FILTER(
            WHERE
                DAYS_EMPLOYED = 365243
        ) / COUNT(*),
        2
    ) AS sentinel_pct,
    MIN(DAYS_EMPLOYED) AS min_employed,
    MAX(DAYS_EMPLOYED) AS max_employed
FROM
    raw.application
WHERE
    dataset_split = 'train';

SELECT
    CREDIT_ACTIVE,
    COUNT(*) AS negative_records,
    COUNT(DISTINCT SK_ID_CURR) AS affected_customers,
    MIN(AMT_CREDIT_SUM_DEBT) AS min_debt
FROM
    raw.bureau
WHERE
    AMT_CREDIT_SUM_DEBT < 0
GROUP BY
    CREDIT_ACTIVE;

SELECT
    CREDIT_ACTIVE,
    COUNT(*) AS total_records,
    COUNT(AMT_CREDIT_SUM_DEBT) AS valid_debt_records,
    SUM(
        CASE
            WHEN AMT_CREDIT_SUM_DEBT < 0 THEN 1
            ELSE 0
        END
    ) AS negative_records,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN AMT_CREDIT_SUM_DEBT < 0 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(AMT_CREDIT_SUM_DEBT), 0),
        2
    ) AS negative_pct
FROM
    raw.bureau
GROUP BY
    CREDIT_ACTIVE
ORDER BY
    negative_pct DESC;

SELECT
    COUNT(*) AS future_payment_records,
    COUNT(DISTINCT SK_ID_CURR) AS affected_customers
FROM
    raw.installments_payments
WHERE
    DAYS_INSTALMENT <= 0
    AND DAYS_ENTRY_PAYMENT > 0;