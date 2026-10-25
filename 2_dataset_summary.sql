DESCRIBE raw.application_train;

-- Number of columns
SELECT
    COUNT(*) AS column_count
FROM
    information_schema.columns
WHERE
    table_schema = 'raw'
    AND table_name = 'application_train';

--- Check Primary key
SELECT
    Count(t.SK_ID_CURR) AS total_row,
    Count(DISTINCT t.SK_ID_CURR) AS non_null_rows,
    Count(t.SK_ID_CURR) - Count(DISTINCT t.SK_ID_CURR) AS missing_row
FROM
    raw.application_train t;

--- Check valid Target
SELECT
    Count(t."TARGET") - Count(*) AS missing_row_2
FROM
    raw.application_train t;

--- Check percentage Target
SELECT
    TARGET,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM
    raw.application_train t
GROUP BY
    t."TARGET"
ORDER BY
    t."TARGET";

SELECT
    table_name,
    estimated_size AS n_rows
FROM
    duckdb_tables()
WHERE
    schema_name = 'raw'
ORDER BY
    table_name;

--- Describe Application
SELECT
    t."TARGET" AS TARGET,
    COUNT(*) AS number_of_application,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM
    raw.application_train t
GROUP BY
    t."TARGET";

WITH
    total_application AS (
        SELECT
            tr.SK_ID_CURR AS Customer_id
        FROM
            raw.application_train tr
        UNION ALL
        SELECT
            te.SK_ID_CURR
        FROM
            raw.application_test te
    )
SELECT
    Count(*) AS total_rows,
    Count(DISTINCT ta.Customer_id) AS candidate_key
FROM
    total_application ta;

---Describe bureau
SELECT
    *
FROM
    raw.bureau b
LIMIT
    10;

SELECT
    Count(*) AS total_rows,
    Count(DISTINCT b.SK_ID_BUREAU) AS candidate_key
FROM
    raw.bureau b;

ELECT table_name,
COUNT(*) AS n_columns
FROM
    information_schema.columns
WHERE
    table_schema = 'raw'
GROUP BY
    table_name
ORDER BY
    table_name;

--- Each table row count (Not using DuckDB function)
SELECT
    'application_train' AS table_name,
    COUNT(*) AS n_rows
FROM
    raw.application_train
UNION ALL
SELECT
    'application_test',
    COUNT(*)
FROM
    raw.application_test
UNION ALL
SELECT
    'bureau',
    COUNT(*)
FROM
    raw.bureau
UNION ALL
SELECT
    'bureau_balance',
    COUNT(*)
FROM
    raw.bureau_balance
UNION ALL
SELECT
    'previous_application',
    COUNT(*)
FROM
    raw.previous_application
UNION ALL
SELECT
    'pos_cash_balance',
    COUNT(*)
FROM
    raw.pos_cash_balance
UNION ALL
SELECT
    'credit_card_balance',
    COUNT(*)
FROM
    raw.credit_card_balance
UNION ALL
SELECT
    'installments_payments',
    COUNT(*)
FROM
    raw.installments_payments;

--- Each table row count (Using Duckdb function)
SELECT
    table_name,
    estimated_size AS n_rows
FROM
    duckdb_tables()
WHERE
    schema_name = 'raw'
ORDER BY
    table_name;

--- Descriibe bureau
SELECT
    COUNT(*) AS n_rows,
    COUNT(DISTINCT SK_ID_CURR) AS n_clients,
    COUNT(DISTINCT SK_ID_BUREAU) AS n_bureau_credits
FROM
    raw.bureau;

SELECT
    COUNT(*) AS orphan_bureau_rows
FROM
    raw.bureau b
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            raw.application_train atr
        WHERE
            atr.SK_ID_CURR = b.SK_ID_CURR
    )
    AND NOT EXISTS (
        SELECT
            1
        FROM
            raw.application_test ate
        WHERE
            ate.SK_ID_CURR = b.SK_ID_CURR
    );

--- Desribe bureau_balance
SELECT
    *
FROM
    raw.bureau_balance bb
LIMIT
    20;

SELECT
    Count(*) AS total_rows,
    Count(DISTINCT bb.SK_ID_BUREAU) AS ID_rows
FROM
    raw.bureau_balance bb;

SELECT
    COUNT(*) AS n_rows,
    COUNT(DISTINCT (SK_ID_BUREAU, MONTHS_BALANCE)) AS n_distinct_bureau_month
FROM
    raw.bureau_balance;

SELECT
    COUNT(DISTINCT bb.SK_ID_BUREAU) AS orphan_bureau_ids,
FROM
    raw.bureau_balance bb
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            raw.bureau b
        WHERE
            b.SK_ID_BUREAU = bb.SK_ID_BUREAU
    );

WITH
    bb_ids AS (
        SELECT
            Count(DISTINCT bb.SK_ID_BUREAU) AS total_ID_rows
        FROM
            raw.bureau_balance bb
    ),
    orphan_bb AS (
        SELECT
            COUNT(DISTINCT bb.SK_ID_BUREAU) AS orphan_bureau_ids,
        FROM
            raw.bureau_balance bb
        WHERE
            NOT EXISTS (
                SELECT
                    1
                FROM
                    raw.bureau b
                WHERE
                    b.SK_ID_BUREAU = bb.SK_ID_BUREAU
            )
    )
SELECT
    b.total_ID_rows,
    o.orphan_bureau_ids,
    Round(100 * o.orphan_bureau_ids / b.total_ID_rows, 2) AS orphan_pct
FROM
    bb_ids b
    CROSS JOIN orphan_bb o;

--- Describe previous_application
SELECT
    *
FROM
    raw.previous_application pa
LIMIT
    10;

SELECT
    Count(DISTINCT pa.SK_ID_CURR) AS Current_ids,
    Count(DISTINCT pa.SK_ID_PREV) AS Previous_ids,
    Count(*) AS total_rows
FROM
    raw.previous_application pa;

WITH
    total_application AS (
        SELECT
            SK_ID_CURR AS IDs
        FROM
            raw.application_train
        UNION ALL
        SELECT
            SK_ID_CURR
        FROM
            raw.application_test
    )
SELECT
    Count(DISTINCT pa.SK_ID_CURR) - Count(DISTINCT ta.IDs)
FROM
    raw.previous_application pa
    JOIN total_application ta ON ta.IDs = pa.SK_ID_CURR;

---Describe previous_application
SELECT
    *
FROM
    raw.previous_application pa
LIMIT
    10;

SELECT
    Count(DISTINCT pa.SK_ID_CURR) AS Current_ids,
    Count(DISTINCT pa.SK_ID_PREV) AS Previous_ids,
    Count(*) AS total_rows
FROM
    raw.previous_application pa;

WITH
    total_application AS (
        SELECT
            SK_ID_CURR AS Current_id
        FROM
            raw.application_train
        UNION ALL
        SELECT
            SK_ID_CURR
        FROM
            raw.application_test
    )
SELECT
    COUNT(*) AS orphan_rows,
    COUNT(DISTINCT pa.SK_ID_CURR) AS orphan_curr_ids
FROM
    raw.previous_application pa
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            total_application ta
        WHERE
            ta.Current_id = pa.SK_ID_CURR
    );

--- Desribe POS_CASH_BALANCE
SELECT
    *
FROM
    raw.pos_cash_balance pcb
LIMIT
    10;

SELECT
    Count(DISTINCT pcb.SK_ID_CURR) AS current_ids,
    Count(DISTINCT pcb.SK_ID_PREV) AS pervious_ids,
    Count(DISTINCT (pcb.SK_ID_PREV, pcb.MONTHS_BALANCE)) AS monthly_previous_ids,
    Count(*) AS total_rows
FROM
    raw.pos_cash_balance pcb;

SELECT
    Count(*) AS orphan_rows,
    Count(DISTINCT pcb.SK_ID_PREV) AS orphan_previous_ids
FROM
    raw.pos_cash_balance pcb
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            raw.previous_application pa
        WHERE
            pa.SK_ID_PREV = pcb.SK_ID_PREV
    );

WITH
    total_application AS (
        SELECT
            ate.SK_ID_CURR AS Current_ids
        FROM
            raw.application_test ate
        UNION ALL
        SELECT
            atr.SK_ID_CURR
        FROM
            raw.application_train atr
    )
SELECT
    Count(*) AS orphan_rows,
    Count(DISTINCT pcb.SK_ID_CURR) AS specific_orphan_rows
FROM
    raw.pos_cash_balance pcb
WHERE
    NOT exists (
        SELECT
            1
        FROM
            total_application ta
        WHERE
            ta.Current_ids = pcb.SK_ID_CURR
    );

WITH
    total_application AS (
        SELECT
            ate.SK_ID_CURR AS Current_ids
        FROM
            raw.application_test ate
        UNION ALL
        SELECT
            atr.SK_ID_CURR
        FROM
            raw.application_train atr
    )
SELECT
    Count(DISTINCT pcb.SK_ID_CURR) AS orphan_rows
FROM
    raw.pos_cash_balance pcb
WHERE
    NOT exists (
        SELECT
            1
        FROM
            total_application ta
        WHERE
            pcb.SK_ID_CURR = ta.Current_ids
    );

WITH
    orphan_data AS (
        SELECT
            COUNT(DISTINCT pcb.SK_ID_PREV) AS orphan_rows
        FROM
            raw.pos_cash_balance pcb
        WHERE
            NOT EXISTS (
                SELECT
                    1
                FROM
                    raw.previous_application pa
                WHERE
                    pa.SK_ID_PREV = pcb.SK_ID_PREV
            )
    )
SELECT
    od.orphan_rows,
    COUNT(DISTINCT pcb.SK_ID_PREV) AS total_distinct,
    ROUND(
        od.orphan_rows * 100.0 / COUNT(DISTINCT pcb.SK_ID_PREV),
        2
    ) AS orphan_rate_pct
FROM
    orphan_data od,
    raw.pos_cash_balance pcb
GROUP BY
    od.orphan_rows;

SELECT
    COUNT(*) AS mismatched_rows,
    COUNT(DISTINCT pcb.SK_ID_PREV) AS mismatched_prev_ids
FROM
    raw.pos_cash_balance pcb
    JOIN raw.previous_application pa ON pcb.SK_ID_PREV = pa.SK_ID_PREV
WHERE
    pcb.SK_ID_CURR <> pa.SK_ID_CURR;

--- Describe installments_payment
SELECT
    *
FROM
    raw.installments_payments ip
LIMIT
    20;

SELECT
    Count(*) AS total_rows,
    Count(DISTINCT ip.SK_ID_CURR) AS current_ids,
    Count(DISTINCT ip.SK_ID_PREV) AS previous_ids,
    Count(
        DISTINCT (
            ip.SK_ID_PREV,
            ip.NUM_INSTALMENT_NUMBER,
            ip.NUM_INSTALMENT_VERSION,
            ip.DAYS_ENTRY_PAYMENT
        )
    ) AS candidate_keys,
FROM
    raw.installments_payments ip;

WITH
    duplicated_keys AS (
        SELECT
            SK_ID_PREV,
            NUM_INSTALMENT_NUMBER,
            NUM_INSTALMENT_VERSION,
            DAYS_ENTRY_PAYMENT
        FROM
            raw.installments_payments
        GROUP BY
            SK_ID_PREV,
            NUM_INSTALMENT_NUMBER,
            NUM_INSTALMENT_VERSION,
            DAYS_ENTRY_PAYMENT
        HAVING
            COUNT(*) > 1
    )
SELECT
    ip.*
FROM
    raw.installments_payments ip
    JOIN duplicated_keys dk ON ip.SK_ID_PREV = dk.SK_ID_PREV
    AND ip.NUM_INSTALMENT_NUMBER = dk.NUM_INSTALMENT_NUMBER
    AND ip.NUM_INSTALMENT_VERSION = dk.NUM_INSTALMENT_VERSION
    AND ip.DAYS_ENTRY_PAYMENT = dk.DAYS_ENTRY_PAYMENT
ORDER BY
    ip.SK_ID_PREV,
    ip.NUM_INSTALMENT_NUMBER,
    ip.NUM_INSTALMENT_VERSION,
    ip.DAYS_ENTRY_PAYMENT
LIMIT
    50;

SELECT
    Count(DISTINCT ip.SK_ID_PREV) AS orphan_values
FROM
    raw.installments_payments ip
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            raw.previous_application pa
        WHERE
            pa.SK_ID_PREV = ip.SK_ID_PREV
    );

WITH
    orphan_data AS (
        SELECT
            COUNT(DISTINCT ip.SK_ID_PREV) AS orphan_cnt
        FROM
            raw.installments_payments ip
        WHERE
            NOT EXISTS (
                SELECT
                    1
                FROM
                    raw.previous_application pa
                WHERE
                    pa.SK_ID_PREV = ip.SK_ID_PREV
            )
    ),
    total_data AS (
        SELECT
            COUNT(DISTINCT SK_ID_PREV) AS total_cnt
        FROM
            raw.installments_payments
    )
SELECT
    o.orphan_cnt,
    t.total_cnt,
    ROUND(100.0 * o.orphan_cnt / t.total_cnt, 2) AS orphan_pct
FROM
    orphan_data o
    CROSS JOIN total_data t;

SELECT
    pa.SK_ID_PREV,
    Count(*) AS number_of_ip
FROM
    raw.installments_payments ip
    JOIN raw.previous_application pa ON ip.SK_ID_PREV = pa.SK_ID_PREV
GROUP BY
    pa.SK_ID_PREV
HAVING
    Count(*) > 1
LIMIT
    10;

WITH
    total_application AS (
        SELECT
            t.SK_ID_CURR AS Current_ids
        FROM
            raw.application_test t
        UNION ALL
        SELECT
            t2.SK_ID_CURR
        FROM
            raw.application_train t2
    )
SELECT
    ta.Current_ids,
    Count(*) AS number_of_ip
FROM
    raw.installments_payments ip
    JOIN total_application ta ON ta.Current_ids = ip.SK_ID_CURR
GROUP BY
    ta.Current_ids
HAVING
    COUNT(*) > 1
LIMIT
    10;

CREATE SCHEMA IF NOT EXISTS intermediate;

CREATE OR REPLACE VIEW intermediate.total_application AS
SELECT
    SK_ID_CURR,
    'train' AS dataset_split
FROM
    raw.application_train
UNION ALL
SELECT
    SK_ID_CURR,
    'test' AS dataset_split
FROM
    raw.application_test;

SELECT
    Count(DISTINCT ip.SK_ID_CURR) AS orphan_rows
FROM
    raw.installments_payments ip
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            intermediate.total_application ta
        WHERE
            ta.SK_ID_CURR = ip.SK_ID_CURR
    );

SELECT
    Count(DISTINCT ip.SK_ID_PREV) AS oprhan_rows
FROM
    raw.installments_payments ip
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            raw.previous_application pa
        WHERE
            pa.SK_ID_PREV = ip.SK_ID_PREV
    );

WITH
    orphan_rows AS (
        SELECT
            Count(DISTINCT ip.SK_ID_PREV) AS oprhan_rows
        FROM
            raw.installments_payments ip
        WHERE
            NOT EXISTS (
                SELECT
                    1
                FROM
                    raw.previous_application pa
                WHERE
                    pa.SK_ID_PREV = ip.SK_ID_PREV
            )
    ),
    parent_rows AS (
        SELECT
            Count(DISTINCT ip.SK_ID_PREV) AS customer_prev_ids
        FROM
            raw.installments_payments ip
    )
SELECT
    ROUND(
        ors.oprhan_rows * 100.0 / NULLIF(pr.customer_prev_ids, 0),
        4
    ) AS orphan_pct
FROM
    parent_rows pr
    CROSS JOIN orphan_rows ors;

SELECT
    COUNT(*) AS mismatched_rows,
    COUNT(DISTINCT ip.SK_ID_PREV) AS mismatched_prev_ids
FROM
    raw.installments_payments ip
    JOIN raw.previous_application pa ON ip.SK_ID_PREV = pa.SK_ID_PREV
WHERE
    ip.SK_ID_CURR <> pa.SK_ID_CURR;

--- Describe credit_card_balance
SELECT
    *
FROM
    raw.credit_card_balance ccb
LIMIT
    10;

SELECT
    Count(*) AS total_rows,
    Count(DISTINCT (ccb.SK_ID_PREV, ccb.months_balance)) AS candidate_key
FROM
    raw.credit_card_balance ccb;

SELECT
    Count(DISTINCT ccb.SK_ID_CURR) AS orphan_rows
FROM
    raw.credit_card_balance ccb
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            intermediate.total_application ta
        WHERE
            ta.SK_ID_CURR = ccb.SK_ID_CURR
    );

SELECT
    Count(DISTINCT ccb.SK_ID_PREV) AS orphan_rows
FROM
    raw.credit_card_balance ccb
WHERE
    NOT EXISTS (
        SELECT
            1
        FROM
            raw.previous_application pa
        WHERE
            pa.SK_ID_PREV = ccb.SK_ID_PREV
    );

WITH
    orphan_rows AS (
        SELECT
            Count(DISTINCT ccb.SK_ID_PREV) AS orphan_rows
        FROM
            raw.credit_card_balance ccb
        WHERE
            NOT EXISTS (
                SELECT
                    1
                FROM
                    raw.previous_application pa
                WHERE
                    pa.SK_ID_PREV = ccb.SK_ID_PREV
            )
    ),
    previous_ids AS (
        SELECT
            Count(DISTINCT ccb.SK_ID_PREV) AS total_previous_ids
        FROM
            raw.credit_card_balance ccb
    )
SELECT
    Round(100 * ors.orphan_rows / pi.total_previous_ids, 2) AS pct_orphan
FROM
    previous_ids pi
    CROSS JOIN orphan_rows ors;

SELECT
    COUNT(*) AS mismatched_rows,
    COUNT(DISTINCT ccb.SK_ID_PREV) AS mismatched_prev_ids
FROM
    raw.credit_card_balance ccb
    JOIN raw.previous_application pa ON ccb.SK_ID_PREV = pa.SK_ID_PREV
WHERE
    ccb.SK_ID_CURR <> pa.SK_ID_CURR;