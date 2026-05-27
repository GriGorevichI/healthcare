![Python](https://img.shields.io/badge/Python-3.9%2B-blue)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811)
![VS Code](https://img.shields.io/badge/VS%20Code-Editor-007ACC)

![healthcare dash](/image/healthcare%20dash.png)

# Introduction 

This project analyzes **55,000+ patient records** from a healthcare system (2019-2024) to provide actionable insights for hospital administrators and healthcare providers. The goal of this project to identify trends in admissions, evaluate hospital performance, and understand which medical conditions affect different age groups. To make it comprehensive I splitted it into several business tasks:
| # | Question | Business Value |
|---|----------|----------------|
| 1 | How do admission volumes and billing amounts change month by month? | Resource planning, seasonal staffing |
| 2 | Which hospitals have the lowest costs, shortest stays, and best outcomes? | Performance benchmarking, cost optimization |
| 3 | What medical conditions are most common across different age groups? | Preventive care programs, targeted health campaigns |

### 🔗 Dashboard Access

🔗 **[View Dashboard on Power BI Service](https://app.powerbi.com/links/GvCGsaziHi?ctid=d5cbab6e-6db4-407a-b5fe-10287f99ad43&pbi_source=linkShare&bookmarkGuid=cd364d4b-804e-4d51-8601-0588a722cf38)**

> *Power BI Pro license required.* 

📁 **[Download .PBIX File](./powerbi/healthcare_dashboard.pbix)**

Check out SQL queries here: [sql folder](/healthcare/sql/02_healthcare_analysis.sql)

# Tools I used

| Tool | Purpose |
|------|---------|
| **Python 3.9** | Data cleaning and preprocessing |
| **Pandas** | Data cleaning and preprocessing |
| **Jupyter Notebook** | Interactive data cleaning environment |
| **PostgreSQL 16** | Data storage and SQL querying |
| **Power BI Desktop** | Dashboard creation and visualization |
| **Power BI Service** | Dashboard sharing and collaboration |
| **Git & GitHub** | Version control and project hosting |
| **VS Code** | SQL and Python environment |

# The analysis

PostgreSQL queries examine age-related disease correlations, hospital performance (recovery rate with minimal congestion), and treatment demand trends. The goal is to identify preventive care targets, benchmark clinic efficiency, and forecast investment needs based on seasonal and yearly patterns.

### 1. Monthly Admission Trends & Rolling Averages
Purpose: Tracks patient admission volumes and total billing amounts over time, while smoothing short-term fluctuations using a 3-month rolling average.
Key Business Value: Helps hospital administrators forecast capacity needs, plan staffing levels, and identify seasonal demand patterns.
Use case example: If December shows a spike in flu admissions, the rolling average will confirm whether this is a real trend or just a one-month anomaly.

```sql
CREATE VIEW administrative_stats AS
WITH monthly_data AS (
    SELECT 
        EXTRACT(YEAR FROM date_of_admission) AS year,
        EXTRACT(MONTH FROM date_of_admission) AS month,
        COUNT(*) AS admissions_volume,
        SUM(billing_amount) AS total_billing_usd
    FROM healthcare
    GROUP BY month, year   
),
not_rounded_rolling_avg AS (
    SELECT
        year,
        month,
        admissions_volume,
        total_billing_usd,
        AVG(admissions_volume) OVER (ORDER BY year, month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS rolling_avg_admissions,
        AVG(total_billing_usd) OVER (ORDER BY year, month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS rolling_avg_billing
    FROM monthly_data
)
SELECT
    nrra.year,
    nrra.month,
    TO_CHAR(TO_DATE(nrra.month::text, 'MM'), 'Month') AS month_name,
    nrra.admissions_volume,
    nrra.total_billing_usd,
    ROUND(nrra.rolling_avg_admissions, 2) AS rolling_avg_admissions,
    ROUND(nrra.rolling_avg_billing, 2) AS rolling_avg_billing
FROM not_rounded_rolling_avg nrra
ORDER BY nrra.year, nrra.month;
```

### Key Metrics

| Metric | Value | Insight |
|--------|-------|---------|
| Peak admission month | July 2020 (1,000 admissions) | Summer + post-pandemic reopening surge |
| Highest billing month | October 2019 ($25.7M) | Year-end insurance utilization |
| Lowest admission month | May 2019 (677 admissions) | Data ramp-up period |
| Average monthly admissions | ~915 | Baseline capacity benchmark |
| Average monthly billing | ~$23.8M | Baseline revenue benchmark |
| Admission trend (2019→2020) | +12% growth | Consistent year-over-year increase |

### Key Anomalies

| Period | Observation | Explanation |
|--------|-------------|-------------|
| March–May 2020 | Decline vs previous months | COVID-19 onset, elective procedures paused |
| July 2020 | Surge to 1,000 admissions | Post-lockdown pent-up demand |

### Recommendations & Actions

| Finding | Recommendation |
|---------|----------------|
| Summer months (Jun-Aug) peak at 950–1,000 admissions | Schedule additional staff, ensure bed capacity |
| Rolling avg billing stable at $23–24M | Good revenue predictability — maintain operations |
| Q3 (Jul-Sep) consistently high volume | Run preventive campaigns in Q2 to reduce admissions |
| 2020 summer surge (post-COVID rebound) | Build flexible capacity for unexpected demand spikes |

### 2. Hospital Performance Scorecard
Identifies hospitals that balance cost efficiency, short patient stays, and positive test outcomes. Ranks facilities by cost per day and tracks pass rates to benchmark clinical quality.

```sql
CREATE VIEW hospitals_ranks AS
 WITH hospital_summary AS(
    SELECT hospital,
        ROUND(AVG(length_of_stay), 1) AS avg_length_of_stay,
        COUNT(DISTINCT name) AS total_patients,
        ROUND(AVG(billing_amount), 0) AS avg_bill_usd,
        SUM(CASE WHEN test_results = 'Normal' 
            THEN 1 ELSE 0 END) AS total_positive_results,
        COUNT(test_results) AS total_results
    FROM healthcare
    WHERE hospital IS NOT NULL
        AND billing_amount IS NOT NULL
    GROUP BY hospital
    HAVING COUNT(DISTINCT name) >= 30
 )
    SELECT
        hospital,
        avg_length_of_stay,
        total_patients,
        avg_bill_usd,
        ROUND(100.0 * total_positive_results / total_results, 1)
            AS test_results_pass_rate,
        ROUND(0.01 * avg_bill_usd / avg_length_of_stay, 0) 
            AS cost_efficiency_score,
        RANK() OVER (ORDER BY   ROUND(avg_bill_usd / avg_length_of_stay, 0) ASC)
    FROM hospital_summary
    WHERE total_positive_results <> 0
        AND total_results <> 0; 
```

### Key Metrics

| Metric | Value | Insight |
|--------|-------|---------|
| Best cost efficiency | Smith Group (score 13) | Lowest cost per day of stay |
| Top test results pass rate | Group Smith (53.1%) | Highest quality outcomes |
| Most expensive hospital | Johnson PLC ($29,229 avg) | Premium pricing, lower efficiency rank (7) |
| Shortest avg stay | Smith Ltd (15.1 days) | Efficient discharge process |
| Longest avg stay | Smith PLC (17.6 days) | Possible complex cases or inefficiency |
| Avg length of stay range | 15.1 – 17.6 days | Consistent across all hospitals |
| Avg billing range | $22,406 – $29,229 | 30% variation between hospitals |

### Key Findings

| Finding | Insight |
|---------|---------|
| **Smith Group** ranks #1 (score 13) | Lowest cost per day — operational efficiency leader |
| **Group Smith** has highest pass rate (53.1%) | Best clinical outcomes despite mid-tier efficiency |
| **Johnson PLC** ranks last (score 18) | Highest cost ($29K) + lowest pass rate (24.3%) — needs operational review |
| Efficiency scores cluster (13-18) | Small spread suggests standardized care protocols |
| Pass rates vary widely (24%–53%) | Significant quality gap between hospitals |

### Recommendations

| Hospital | Issue | Recommendation |
|----------|-------|----------------|
| Johnson PLC | Highest cost + lowest pass rate | Clinical audit, cost optimization review |
| Smith PLC | High cost (28.6K), low efficiency rank (4) | Investigate cost drivers, benchmark vs Smith Group |
| Group Smith | Excellent outcomes (53.1% pass rate) | Study best practices, replicate across network |
| Smith Group | Best efficiency (score 13) | Document operational processes for others |
| All hospitals | Pass rates 24–53% | Standardize care protocols, share best practices |

### 3. Age Group & Condition
Identifies the top 3 most common medical conditions for each age group (Senior, Middle Age, Adult, Young Adult, Junior) and calculates average billing and length of stay per condition.

```sql
CREATE VIEW diseas_stats_age_groups AS
WITH age_groups AS( 
    SELECT name,
        EXTRACT(YEAR FROM date_of_admission) AS year,
        medical_condition,
        billing_amount,
        length_of_stay,
        CASE
            WHEN age >= 65 THEN 'Senior'
            WHEN age BETWEEN 51 AND 65 THEN 'Middle age'
            WHEN age BETWEEN 36 AND 50 THEN 'Adult'
            WHEN age BETWEEN 18 AND 35 THEN 'Young adult'
            ELSE 'Junior'
        END AS age_groups
    FROM healthcare
    WHERE age IS NOT NULL
 ),
    diseas_ranks AS(
    SELECT
        age_groups,
        year,
        medical_condition,
        COUNT(*) AS diseas_frquency,
        COUNT(DISTINCT name) AS count_diseas_patients,
        RANK() OVER(PARTITION BY age_groups, year ORDER BY COUNT(*) DESC)
            AS rank_condition_frequency
    FROM age_groups
    GROUP BY age_groups, medical_condition, year
    ORDER BY age_groups
),
    diseas_stats AS(
    SELECT age_groups,
        ROUND(AVG(billing_amount), 0) AS avg_bill_usd,
        ROUND(AVG(length_of_stay), 1) AS avg_length_of_stay,
        COUNT(DISTINCT name) AS total_group_patients
    FROM age_groups 
    GROUP BY age_groups
)
    SELECT r.age_groups,
        r.year,
        r.medical_condition,
        r.diseas_frquency,
        r.rank_condition_frequency,
        r.count_diseas_patients,
        s.total_group_patients,
        ROUND(100.0 * r.count_diseas_patients / s.total_group_patients, 2)
            AS percentage_patients_diseas,
        s.avg_bill_usd,
        s.avg_length_of_stay
    FROM diseas_ranks r
    LEFT JOIN diseas_stats s ON r.age_groups = s.age_groups
    WHERE r.rank_condition_frequency <= 3;
```

### Key Findings

| Finding | Insight |
|---------|---------|
| **Cancer** ranks #1 in 2019 and 2022 | Requires ongoing investment |
| **Obesity** surged to #1 in 2020 (476 cases, 4.15%) | Post-lockdown lifestyle impacts |
| **Arthritis** dominates 2021 and 2023 | Chronic condition management needed |
| **Diabetes** appears in top 3 every year | Persistent high demand — stable resource allocation |
| **Asthma** peaks in 2021 (408 cases, #2) | Potential environmental trigger that year |
| **Hypertension** appears in 2019 and 2023 | Biennial pattern — possibly screening cycles |

### Condition Trends (2019–2023)

| Condition | Peak Year | Peak Frequency | Trend |
|-----------|-----------|----------------|-------|
| Cancer | 2019, 2022 | 425 cases | Biennial spike (odd/even year pattern) |
| Obesity | 2020 | 476 cases | Declining since 2020 peak |
| Arthritis | 2021, 2023 | 432 cases | Increasing frequency |
| Diabetes | 2020 | 435 cases | Consistently in top 3 every year |
| Asthma | 2021 | 408 cases | One-year spike, then dropped |
| Hypertension | 2019, 2023 | 408 cases | Recurring every 2-3 years |


# Challenges 
| Challenge | Solution |
|-----------|----------|
| **Missing persistent patient identifier** | Used patient names as proxy for unique individuals (limitation documented) |
| **Duplicate 'Disharge Date' column with typo** | Removed duplicate column during pandas cleaning |
| **Date columns stored as text** | Converted to datetime using `pd.to_datetime()` |
| **Negative billing amounts (refunds/adjustments)** | Kept as valid business events, documented in analysis |


## 📊 Conclusions

### Limitations

- No persistent patient ID (used names as proxy)
- Synthetic data (validate with real data)
- COVID-19 anomaly documented in 2020 trends

### Final Takeaway

The healthcare system shows clear seasonal patterns, significant hospital performance variation, and persistent chronic conditions (Diabetes, Arthritis, Obesity) requiring targeted investment. Top-performing hospitals demonstrate that quality doesn't require high costs — operational efficiency and care protocols matter more.

Thank you for exploring my project!





