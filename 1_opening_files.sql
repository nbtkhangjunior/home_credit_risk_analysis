CREATE SCHEMA IF NOT EXISTS raw;

-- 1. application_train
CREATE OR REPLACE TABLE raw.application_train AS
SELECT *
FROM read_csv('application_train.csv');

-- 2. application_test
CREATE OR REPLACE TABLE raw.application_test AS
SELECT *
FROM read_csv('application_test.csv');

-- 3. bureau
CREATE OR REPLACE TABLE raw.bureau AS
SELECT *
FROM read_csv('bureau.csv');

-- 4. bureau_balance
CREATE OR REPLACE TABLE raw.bureau_balance AS
SELECT *
FROM read_csv('bureau_balance.csv');

-- 5. previous_application
CREATE OR REPLACE TABLE raw.previous_application AS
SELECT *
FROM read_csv('previous_application.csv');

-- 6. POS_CASH_balance
CREATE OR REPLACE TABLE raw.pos_cash_balance AS
SELECT *
FROM read_csv('POS_CASH_balance.csv');

-- 7. credit_card_balance
CREATE OR REPLACE TABLE raw.credit_card_balance AS
SELECT *
FROM read_csv('credit_card_balance.csv');

-- 8. installments_payments
CREATE OR REPLACE TABLE raw.installments_payments AS
SELECT *
FROM read_csv('installments_payments.csv');

-- 9. column descriptions / metadata
CREATE OR REPLACE TABLE raw.homecredit_columns_description AS
SELECT *
FROM read_csv('HomeCredit_columns_description.csv');

-- 10. sample submission
CREATE OR REPLACE TABLE raw.sample_submission AS
SELECT *
FROM read_csv('sample_submission.csv');