# Home Credit Default Risk — SQL Analytics & Credit Risk Modeling

An end-to-end **portfolio analysis** of credit repayment risk using **DuckDB/SQL and Python**. The project explores how applicant affordability, existing debt, repayment behavior, and historical credit utilization can be combined into a customer-level analytical dataset and used to **rank applications by repayment risk**.

The emphasis is on **relational data exploration, SQL feature engineering, data quality checks, and interpretable model evaluation**—not on building a production lending decision system.

## Project at a glance

| Item | Details |
| --- | --- |
| Dataset | [Home Credit Default Risk (Kaggle)](https://www.kaggle.com/competitions/home-credit-default-risk/data) |
| Tools | DuckDB, SQL, Python, pandas, NumPy, scikit-learn, statsmodels |
| Analytical dataset | **356,255 applications × 93 columns** |
| Labeled training split | **307,511 applications**; observed positive-target rate **8.07%** |
| Unlabeled test split | **48,744 applications** |
| Modeling inputs | **90 features** (84 numerical, 6 categorical), expanded to **250** after preprocessing |
| Best observed validation ROC-AUC | **0.7131** (HistGradientBoosting) |

In the source competition, `TARGET` indicates repayment difficulties. This README uses *default risk* as a shorthand for the binary prediction task; the results should not be interpreted as a real-world default probability or lending policy.

## Repository structure

```text
.
├── 1_opening_files.sql          # Import source CSV files into the raw schema
├── 2_dataset_summary.sql       # Profile tables, keys, and relationships
├── 3_Analytical_dataset.sql    # Build customer-level analytical features
├── 4_Quality_assurance.sql     # Check feature-table grain and assemble modeling data
├── 5_Anomaly_detection.sql     # Investigate unusual and missing data patterns
├── credit_risk_modeling.ipynb  # Python data checks, models, and validation results
└── README.md
```

## Analytical workflow

### 1. Data ingestion and relationship exploration

`1_opening_files.sql` loads the Home Credit CSV files into a DuckDB `raw` schema. `2_dataset_summary.sql` explores table sizes and candidate keys and checks relationships between application, credit bureau, previous loan, installment, POS/cash, and credit-card history tables. Checks include potential **orphan identifiers**, duplicated candidate keys, and mismatches between customer and previous-loan identifiers.

### 2. SQL feature engineering

`3_Analytical_dataset.sql` creates **11 analytical feature tables**, usually aggregated at the `SK_ID_CURR` (application/customer) level:

| Feature family | Examples |
| --- | --- |
| Applicant profile | Age, child burden |
| Affordability | Income per family member, annuity-to-income ratio, credit-to-income ratio |
| Employment | Employment tenure, employment-to-age ratio, missing/sentinel indicator |
| Existing indebtedness | Active bureau accounts, outstanding debt, debt-to-income ratio |
| Assets | Car/home ownership, housing-information completeness |
| Delinquency history | Late-payment rate, bureau status, POS and credit-card days-past-due patterns |
| Payment adequacy | Payment coverage, underpayment rate, shortfall, recent payment trends |
| Credit utilization | Utilization levels, 3/6/12-month windows, volatility, high-utilization streaks |

The SQL handles the special `DAYS_EMPLOYED = 365243` code as an unknown employment duration and computes time-window features from historical records.

### 3. Quality assurance and anomaly investigation

`4_Quality_assurance.sql` compares row counts with distinct customer keys, combines the feature tables into `modeling.home_credit_dataset`, checks the final row grain, and examines credit-card history coverage. `5_Anomaly_detection.sql` investigates missing/unusable card limits, default rates by card-history availability, employment sentinel values, negative bureau debt records, and unusual installment payment dates.

### 4. Modeling and validation in Python

`credit_risk_modeling.ipynb` contains data diagnostics and two classification models:

- **Data inspection:** missing values, numerical ranges, infinite/constant features, and selected domain checks.
- **Split:** 80/20 stratified train/validation split of the labeled applications (`random_state=42`).
- **Preprocessing:** median imputation, missingness indicators and scaling for numerical columns; constant-value imputation and one-hot encoding for categorical columns.
- **Models:** Logistic Regression and HistGradientBoostingClassifier.
- **Evaluation:** ROC-AUC, average precision, risk-decile tables, top-decile lift, and bootstrap confidence intervals (300 resamples). The notebook also includes exploratory coefficient/GLM analysis and permutation importance.

## Validation results

The metrics below come from the **saved notebook outputs**, using the same held-out validation set of **61,503 applications**.

| Metric | Logistic Regression | HistGradientBoosting |
| --- | ---: | ---: |
| ROC-AUC | 0.7084 | **0.7131** |
| Average precision | 0.1917 | **0.1995** |
| Top-decile observed positive-target rate | 22.79% | **23.57%** |
| Top-decile lift vs. validation base rate | 2.82× | **2.92×** |
| Share of positive cases captured in top decile | 28.24% | **29.20%** |
| Bootstrap 95% CI for ROC-AUC | 0.7002–0.7154 | 0.7048–0.7201 |

**Interpretation:** The highest-scored 10% of validation applications under HistGradientBoosting had an observed positive-target rate of about **23.57%**, versus approximately **8.07%** across the validation set. This corresponds to a **2.92× lift** and captures roughly **29.20%** of the positive cases in that top decile.

HistGradientBoosting showed **slightly higher validation metrics** than Logistic Regression in this experiment. No formal paired significance test of their difference was performed; the comparison is descriptive.

## How to explore or reproduce

1. Download the files from the [Home Credit Default Risk dataset page](https://www.kaggle.com/competitions/home-credit-default-risk/data). The CSVs are **not stored in this repository**.
2. Set up a persistent local DuckDB database, and make the CSVs accessible at the relative paths referenced in `1_opening_files.sql` (or adapt those paths locally).
3. Review the SQL files in the numbered order shown above. Run the `CREATE` statements needed to build the `raw`, `analytics`, and `modeling` objects. The SQL files also contain exploratory queries and are **not packaged as a one-command, fully automated pipeline**.
4. Install the notebook dependencies, for example:

   ```bash
   pip install duckdb pandas numpy scikit-learn statsmodels jupyter
   ```

5. Open `credit_risk_modeling.ipynb`. Its first cell currently uses an **environment-specific DuckDB connection** (`duckdb.connect(r"", read_only=True)`). Point this connection to the local persistent database containing `modeling.home_credit_dataset`, then run the notebook.

GitHub can also display the notebook's **saved outputs** without rerunning the analysis.

## Scope and limitations

- This is an **exploratory portfolio project**, not a validated credit-approval or production scoring system.
- Model performance is from **one stratified hold-out split**; there is no external validation, time-based backtest, or hyperparameter search benchmark.
- Historical data coverage varies by source. Credit-card-derived fields have substantial missingness, so absence of a recorded history should not automatically be interpreted as zero risk or zero utilization.
- The SQL scripts and notebook reflect an investigative workflow and may require local path adjustments or review of individual exploratory checks before rerunning from scratch.
- Exploratory model coefficients and permutation-importance output should **not** be read as causal effects or definitive drivers of credit risk. Calibration, fairness, and operational decision thresholds are outside the current scope.

## Data attribution

This project uses the **[Home Credit Default Risk](https://www.kaggle.com/competitions/home-credit-default-risk)** competition dataset. The data remains with its original provider; no original competition CSV files are redistributed in this repository.
