CREATE SCHEMA IF NOT EXISTS analytics;

CREATE OR REPLACE VIEW raw.application AS
SELECT
    *,
    'train' AS dataset_split
FROM
    raw.application_train
UNION ALL
BY NAME
SELECT
    *,
    'test' AS dataset_split
FROM
    raw.application_test;

SELECT
    *
FROM
    raw.application
LIMIT
    10;

SUMMARIZE raw.application;

SELECT
    column_name,
    null_percentage,
    ROUND(
        (null_percentage / 100.0) * (
            SELECT
                COUNT(*)
            FROM
                raw.application
        )
    ) AS null_count
FROM
    (
        SUMMARIZE raw.application
    )
WHERE
    null_percentage > 0
ORDER BY
    null_percentage DESC;

CREATE OR REPLACE TABLE analytics.applicant AS
SELECT
    SK_ID_CURR,
    dataset_split AS target,
    - DAYS_BIRTH / 365.25 AS age_years,
    CNT_CHILDREN / GREATEST(CNT_FAM_MEMBERS - CNT_CHILDREN, 1) AS child_burden
FROM
    raw.application;

CREATE OR REPLACE TABLE analytics.affordability AS
SELECT
    SK_ID_CURR,
    dataset_split AS target,
    - DAYS_REGISTRATION / 365.25 AS registration_years,
    AMT_INCOME_TOTAL / CNT_FAM_MEMBERS AS income_per_person,
    (AMT_INCOME_TOTAL - AMT_ANNUITY) / AMT_INCOME_TOTAL AS residual_income_ratio,
    AMT_ANNUITY / AMT_INCOME_TOTAL AS annuity_ratio,
    LN(1 + AMT_INCOME_TOTAL) AS log_income,
    AMT_CREDIT / AMT_INCOME_TOTAL AS personal_leverage,
    AMT_GOODS_PRICE / AMT_INCOME_TOTAL AS goods_income_ratio
FROM
    raw.application;

SELECT
    *
FROM
    analytics.affordability
LIMIT
    10;

CREATE OR REPLACE TABLE analytics.employment AS
SELECT
    SK_ID_CURR,
    NAME_INCOME_TYPE,
    OCCUPATION_TYPE,
    ORGANIZATION_TYPE,
    CASE
        WHEN DAYS_EMPLOYED = 365243 THEN NULL
        ELSE - DAYS_EMPLOYED / 365.25
    END AS employment_years,
    CASE
        WHEN DAYS_EMPLOYED = 365243 THEN NULL
        ELSE (- DAYS_EMPLOYED) / NULLIF(- DAYS_BIRTH, 0)
    END AS employment_age_ratio,
    CASE
        WHEN DAYS_EMPLOYED = 365243 THEN 1
        ELSE 0
    END AS employment_unknown_flag,
FROM
    raw.application;

CREATE OR REPLACE TABLE analytics.existing_indebtedness AS
SELECT
    ra.SK_ID_CURR,
    COUNT(rb.SK_ID_BUREAU) AS bur_account_count,
    SUM(
        CASE
            WHEN rb.CREDIT_ACTIVE = 'Active' THEN 1
            ELSE 0
        END
    ) AS bur_active_count,
    SUM(
        CASE
            WHEN rb.CREDIT_ACTIVE = 'Active' THEN rb.AMT_CREDIT_SUM_DEBT
            ELSE 0
        END
    ) AS bur_active_debt,
    SUM(rb.AMT_CREDIT_SUM_DEBT) AS bur_total_debt,
    SUM(rb.AMT_CREDIT_SUM) AS bur_total_credit,
    SUM(rb.AMT_CREDIT_SUM_OVERDUE) AS bur_total_overdue,
    SUM(rb.AMT_CREDIT_SUM_LIMIT) AS bur_total_limit,
    MAX(rb.AMT_CREDIT_SUM_DEBT) AS bur_max_debt,
    - MIN(rb.DAYS_CREDIT) AS bur_oldest_credit_days,
    - MAX(rb.DAYS_CREDIT) AS bur_days_since_last_credit,
    SUM(
        CASE
            WHEN rb.DAYS_CREDIT >= -365 THEN 1
            ELSE 0
        END
    ) AS bur_new_credit_12m,
    SUM(rb.AMT_CREDIT_SUM_DEBT) / NULLIF(ra.AMT_INCOME_TOTAL, 0) AS debt_to_annual_income,
    SUM(rb.AMT_CREDIT_SUM_DEBT) / NULLIF(SUM(rb.AMT_CREDIT_SUM), 0) AS debt_credit,
    SUM(rb.AMT_CREDIT_SUM_OVERDUE) / NULLIF(SUM(rb.AMT_CREDIT_SUM_DEBT), 0) AS overdue_debt,
    MAX(rb.AMT_CREDIT_SUM_DEBT) / SUM(rb.AMT_CREDIT_SUM_DEBT) AS debt_largest_share,
    MAX(rb.AMT_CREDIT_SUM) AS bur_max_credit,
    MAX(rb.AMT_CREDIT_SUM) / SUM(rb.AMT_CREDIT_SUM) AS credit_largest_share,
    MAX(rb.AMT_CREDIT_SUM_OVERDUE) AS bur_max_overdue_amount,
    SUM(
        CASE
            WHEN rb.CREDIT_ACTIVE = 'Active' THEN rb.AMT_CREDIT_SUM_DEBT
            ELSE 0
        END
    ) / NULLIF(
        SUM(
            CASE
                WHEN rb.CREDIT_ACTIVE = 'Active' THEN 1
                ELSE 0
            END
        ),
        0
    ) AS bur_debt_per_active,
FROM
    raw.application ra
    LEFT JOIN raw.bureau rb ON ra.SK_ID_CURR = rb.SK_ID_CURR
GROUP BY
    ra.SK_ID_CURR,
    ra.AMT_INCOME_TOTAL;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT SK_ID_CURR) AS unique_customers
FROM
    analytics.existing_indebtedness;

CREATE OR REPLACE TABLE analytics.assets AS
SELECT
    SK_ID_CURR,
    FLAG_OWN_REALTY,
    FLAG_OWN_CAR,
    OWN_CAR_AGE,
    TOTALAREA_MODE,
    LIVINGAREA_AVG,
    NAME_HOUSING_TYPE,
    (
        CASE
            WHEN FLAG_OWN_REALTY = 'Y' THEN 1
            ELSE 0
        END + CASE
            WHEN FLAG_OWN_CAR = 'Y' THEN 1
            ELSE 0
        END
    ) AS asset_count,
    (
        CASE
            WHEN TOTALAREA_MODE IS NOT NULL THEN 1
            ELSE 0
        END + CASE
            WHEN LIVINGAREA_AVG IS NOT NULL THEN 1
            ELSE 0
        END + CASE
            WHEN APARTMENTS_AVG IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS housing_info_count,
    (
        CASE
            WHEN TOTALAREA_MODE IS NULL THEN 1
            ELSE 0
        END + CASE
            WHEN LIVINGAREA_AVG IS NULL THEN 1
            ELSE 0
        END + CASE
            WHEN APARTMENTS_AVG IS NULL THEN 1
            ELSE 0
        END
    ) / 3.0 AS housing_info_missing_rate
FROM
    raw.application;

CREATE OR REPLACE TABLE analytics.delinquency_inst AS
SELECT
    SK_ID_CURR,
    AVG(
        CASE
            WHEN DAYS_ENTRY_PAYMENT > DAYS_INSTALMENT THEN 1.0
            ELSE 0.0
        END
    ) AS inst_late_rate,
    MAX(GREATEST(DAYS_INSTALMENT - DAYS_ENTRY_PAYMENT, 0)) AS max_early_days,
    MAX(GREATEST(DAYS_ENTRY_PAYMENT - DAYS_INSTALMENT, 0)) AS max_late_days,
FROM
    raw.installments_payments
WHERE
    DAYS_INSTALMENT <= 0
    AND DAYS_ENTRY_PAYMENT <= 0
GROUP BY
    SK_ID_CURR;

SELECT
    MONTHS_BALANCE,
    COUNT(*)
FROM
    raw.bureau_balance
GROUP BY
    MONTHS_BALANCE;

CREATE OR REPLACE TABLE analytics.delinquency_bureau AS
SELECT
    rb.SK_ID_CURR,
    AVG(
        CASE
            WHEN rbb.STATUS IN ('1', '2', '3', '4', '5') THEN 1.0
            WHEN rbb.STATUS = '0' THEN 0.0
        END
    ) AS dpd_month_rate,
    MAX(
        CASE
            WHEN rbb.STATUS IN ('0', '1', '2', '3', '4', '5') THEN CAST(rbb.STATUS AS INTEGER)
            ELSE NULL
        END
    ) AS max_dpd_status
FROM
    raw.bureau rb
    JOIN raw.bureau_balance rbb ON rb.SK_ID_BUREAU = rbb.SK_ID_BUREAU
WHERE
    rbb.MONTHS_BALANCE <= 0
GROUP BY
    rb.SK_ID_CURR;

CREATE OR REPLACE TABLE analytics.delinquency_pos AS
WITH
    base_metrics AS (
        SELECT
            SK_ID_CURR,
            AVG(
                CASE
                    WHEN MONTHS_BALANCE >= -12
                    AND SK_DPD > 0 THEN 1.0
                    WHEN MONTHS_BALANCE >= -12
                    AND SK_DPD = 0 THEN 0.0
                END
            ) AS pos_dpd_rate_12m,
            AVG(
                CASE
                    WHEN MONTHS_BALANCE >= -6
                    AND SK_DPD > 0 THEN 1.0
                    WHEN MONTHS_BALANCE >= -6
                    AND SK_DPD = 0 THEN 0.0
                END
            ) AS pos_dpd_rate_6m,
            AVG(
                CASE
                    WHEN SK_DPD > 0 THEN 1.0
                    WHEN SK_DPD = 0 THEN 0.0
                END
            ) AS pos_dpd_rate,
            MAX(SK_DPD) AS pos_max_dpd
        FROM
            raw.POS_CASH_balance
        WHERE
            MONTHS_BALANCE <= 0
        GROUP BY
            SK_ID_CURR
    )
SELECT
    SK_ID_CURR,
    POS_DPD_RATE,
    POS_MAX_DPD,
    POS_DPD_RATE_12M,
    POS_DPD_RATE_6M,
    POS_DPD_RATE_6M - POS_DPD_RATE_12M AS pos_diff_dpd_rate_6m_12m
FROM
    base_metrics;

CREATE OR REPLACE TABLE analytics.delinquency_cc AS
WITH
    base_metrics AS (
        SELECT
            SK_ID_CURR,
            AVG(
                CASE
                    WHEN MONTHS_BALANCE >= -12
                    AND SK_DPD > 0 THEN 1.0
                    WHEN MONTHS_BALANCE >= -12
                    AND SK_DPD = 0 THEN 0.0
                END
            ) AS cc_dpd_rate_12m,
            AVG(
                CASE
                    WHEN MONTHS_BALANCE >= -6
                    AND SK_DPD > 0 THEN 1.0
                    WHEN MONTHS_BALANCE >= -6
                    AND SK_DPD = 0 THEN 0.0
                END
            ) AS cc_dpd_rate_6m,
            AVG(
                CASE
                    WHEN SK_DPD > 0 THEN 1.0
                    WHEN SK_DPD = 0 THEN 0.0
                END
            ) AS cc_dpd_rate,
            MAX(SK_DPD) AS cc_max_dpd
        FROM
            raw.credit_card_balance
        WHERE
            MONTHS_BALANCE <= 0
        GROUP BY
            SK_ID_CURR
    )
SELECT
    SK_ID_CURR,
    CC_DPD_RATE,
    CC_MAX_DPD,
    CC_DPD_RATE_12M,
    CC_DPD_RATE_6M,
    CC_DPD_RATE_6M - CC_DPD_RATE_12M AS cc_diff_dpd_rate_6m_12m
FROM
    base_metrics;

CREATE OR REPLACE TABLE analytics.payment_adequacy AS
WITH
    installment_level AS (
        SELECT
            SK_ID_CURR,
            SK_ID_PREV,
            NUM_INSTALMENT_NUMBER,
            MAX(DAYS_INSTALMENT) AS due_day,
            MAX(AMT_INSTALMENT) AS scheduled_amount,
            SUM(
                CASE
                    WHEN DAYS_ENTRY_PAYMENT <= 0 THEN AMT_PAYMENT
                    ELSE 0
                END
            ) AS paid_amount
        FROM
            raw.installments_payments
        WHERE
            DAYS_INSTALMENT <= 0
        GROUP BY
            SK_ID_CURR,
            SK_ID_PREV,
            NUM_INSTALMENT_NUMBER
    ),
    base_metrics AS (
        SELECT
            SK_ID_CURR,
            COUNT(*) AS inst_obs_count,
            SUM(PAID_AMOUNT) / NULLIF(SUM(SCHEDULED_AMOUNT), 0) AS pay_coverage,
            AVG(
                CASE
                    WHEN PAID_AMOUNT < SCHEDULED_AMOUNT THEN 1.0
                    ELSE 0.0
                END
            ) AS pay_underpay_rate,
            SUM(GREATEST(SCHEDULED_AMOUNT - PAID_AMOUNT, 0)) / NULLIF(SUM(SCHEDULED_AMOUNT), 0) AS pay_shortfall_ratio,
            MAX(GREATEST(SCHEDULED_AMOUNT - PAID_AMOUNT, 0)) AS pay_max_shortfall,
            SUM(
                CASE
                    WHEN DUE_DAY >= -180 THEN PAID_AMOUNT
                END
            ) / NULLIF(
                SUM(
                    CASE
                        WHEN DUE_DAY >= -180 THEN SCHEDULED_AMOUNT
                    END
                ),
                0
            ) AS pay_coverage_6m,
            SUM(
                CASE
                    WHEN DUE_DAY >= -365 THEN PAID_AMOUNT
                END
            ) / NULLIF(
                SUM(
                    CASE
                        WHEN DUE_DAY >= -365 THEN SCHEDULED_AMOUNT
                    END
                ),
                0
            ) AS pay_coverage_12m,
            AVG(
                CASE
                    WHEN DUE_DAY >= -180
                    AND PAID_AMOUNT < SCHEDULED_AMOUNT THEN 1.0
                    WHEN DUE_DAY >= -180 THEN 0.0
                END
            ) AS pay_underpay_rate_6m,
            STDDEV_SAMP(PAID_AMOUNT / NULLIF(SCHEDULED_AMOUNT, 0)) AS pay_coverage_std
        FROM
            installment_level
        GROUP BY
            SK_ID_CURR
    )
SELECT
    *,
    PAY_COVERAGE_6M - PAY_COVERAGE AS pay_coverage_trend
FROM
    base_metrics;

CREATE OR REPLACE TABLE analytics.credit_utilization AS
WITH
    per_card_month AS (
        SELECT
            SK_ID_CURR,
            SK_ID_PREV,
            MONTHS_BALANCE,
            AMT_BALANCE,
            AMT_CREDIT_LIMIT_ACTUAL,
            CASE
                WHEN AMT_CREDIT_LIMIT_ACTUAL > 0 THEN AMT_BALANCE / AMT_CREDIT_LIMIT_ACTUAL
            END AS util_card,
            CASE
                WHEN AMT_CREDIT_LIMIT_ACTUAL > 0 THEN GREATEST(AMT_BALANCE - AMT_CREDIT_LIMIT_ACTUAL, 0) / AMT_CREDIT_LIMIT_ACTUAL
            END AS overlimit_card
        FROM
            raw.credit_card_balance
        WHERE
            MONTHS_BALANCE <= 0
    ),
    per_month AS (
        SELECT
            SK_ID_CURR,
            MONTHS_BALANCE,
            AVG(UTIL_CARD) AS util_month,
            SUM(AMT_BALANCE) AS balance_month,
            MAX(OVERLIMIT_CARD) AS overlimit_month
        FROM
            per_card_month
        GROUP BY
            SK_ID_CURR,
            MONTHS_BALANCE
    ),
    base_metrics AS (
        SELECT
            SK_ID_CURR,
            AVG(UTIL_MONTH) AS cc_util_mean,
            MEDIAN(UTIL_MONTH) AS cc_util_median,
            ARG_MAX(UTIL_MONTH, MONTHS_BALANCE) AS cc_util_last,
            QUANTILE_CONT(UTIL_MONTH, 0.75) AS cc_util_p75,
            AVG(
                CASE
                    WHEN UTIL_MONTH > 0.8 THEN 1.0
                    WHEN UTIL_MONTH IS NOT NULL THEN 0.0
                END
            ) AS cc_util_gt80_rate,
            AVG(
                CASE
                    WHEN UTIL_MONTH > 0.9 THEN 1.0
                    WHEN UTIL_MONTH IS NOT NULL THEN 0.0
                END
            ) AS cc_util_gt90_rate,
            AVG(
                CASE
                    WHEN BALANCE_MONTH > 0 THEN 1.0
                    WHEN BALANCE_MONTH IS NOT NULL THEN 0.0
                END
            ) AS cc_positive_balance_rate,
            MAX(UTIL_MONTH) AS cc_util_max,
            QUANTILE_CONT(UTIL_MONTH, 0.95) AS cc_util_p95,
            MAX(OVERLIMIT_MONTH) AS cc_max_overlimit_ratio,
            AVG(
                CASE
                    WHEN MONTHS_BALANCE >= -3 THEN UTIL_MONTH
                END
            ) AS cc_util_mean_3m,
            AVG(
                CASE
                    WHEN MONTHS_BALANCE >= -6 THEN UTIL_MONTH
                END
            ) AS cc_util_mean_6m,
            AVG(
                CASE
                    WHEN MONTHS_BALANCE >= -12 THEN UTIL_MONTH
                END
            ) AS cc_util_mean_12m,
            REGR_SLOPE(UTIL_MONTH, MONTHS_BALANCE) AS cc_util_slope,
            STDDEV_SAMP(UTIL_MONTH) AS cc_util_std,
            MAX(UTIL_MONTH) - MIN(UTIL_MONTH) AS cc_util_range,
            STDDEV_SAMP(BALANCE_MONTH) / NULLIF(AVG(BALANCE_MONTH), 0) AS cc_balance_cv,
            SUM(
                CASE
                    WHEN UTIL_MONTH > 0.8 THEN 1
                    ELSE 0
                END
            ) AS n_months_util_gt80
        FROM
            per_month
        GROUP BY
            SK_ID_CURR
    ),
    months_gt80 AS (
        SELECT
            SK_ID_CURR,
            MONTHS_BALANCE,
            MONTHS_BALANCE - ROW_NUMBER() OVER (
                PARTITION BY
                    SK_ID_CURR
                ORDER BY
                    MONTHS_BALANCE
            ) AS group_80
        FROM
            per_month
        WHERE
            UTIL_MONTH > 0.8
    ),
    consec_gt80 AS (
        SELECT
            SK_ID_CURR,
            GROUP_80,
            COUNT(*) AS consec_months
        FROM
            months_gt80
        GROUP BY
            SK_ID_CURR,
            GROUP_80
    ),
    max_consec_gt80 AS (
        SELECT
            SK_ID_CURR,
            MAX(CONSEC_MONTHS) AS max_consec_util_gt80
        FROM
            consec_gt80
        GROUP BY
            SK_ID_CURR
    ),
    months_gt90 AS (
        SELECT
            SK_ID_CURR,
            MONTHS_BALANCE,
            MONTHS_BALANCE - ROW_NUMBER() OVER (
                PARTITION BY
                    SK_ID_CURR
                ORDER BY
                    MONTHS_BALANCE
            ) AS group_90
        FROM
            per_month
        WHERE
            UTIL_MONTH > 0.9
    ),
    consec_gt90 AS (
        SELECT
            SK_ID_CURR,
            GROUP_90,
            COUNT(*) AS consec_months
        FROM
            months_gt90
        GROUP BY
            SK_ID_CURR,
            GROUP_90
    ),
    max_consec_gt90 AS (
        SELECT
            SK_ID_CURR,
            MAX(CONSEC_MONTHS) AS max_consec_util_gt90
        FROM
            consec_gt90
        GROUP BY
            SK_ID_CURR
    )
SELECT
    b.*,
    b.CC_UTIL_MEAN_3M - b.CC_UTIL_MEAN AS cc_util_3m_minus_lifetime,
    b.CC_UTIL_MEAN_6M - b.CC_UTIL_MEAN_12M AS cc_util_6m_minus_12m,
    COALESCE(s80.MAX_CONSEC_UTIL_GT80, 0) AS max_consec_util_gt80,
    COALESCE(s90.MAX_CONSEC_UTIL_GT90, 0) AS max_consec_util_gt90
FROM
    base_metrics b
    LEFT JOIN max_consec_gt80 s80 ON b.SK_ID_CURR = s80.SK_ID_CURR
    LEFT JOIN max_consec_gt90 s90 ON b.SK_ID_CURR = s90.SK_ID_CURR;