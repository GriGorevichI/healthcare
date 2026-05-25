/* ============================================================================
   PROJECT: Healthcare Analytics Dashboard
   AUTHOR: Grigorii Gorevich
   DATE: 2026
   TOOLS: Python (Pandas), PostgreSQL, Power BI
   DATASET: Healthcare Dataset (55,000+ patient records)

   QUERIES:
   1. Monthly Admission Trends with 3-Month Rolling Averages
   2. Hospital Performance Scorecard (cost, stay, outcomes)
   3. Age Group vs Medical Condition Heatmap

/* Query 1 "How do admission volumes and billing amounts
 change month by month, and what are the 3-month rolling
  trends? */
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

/* Query 2 Which hospitals have the best combination of low cost,
 short stays, and positive outcomes? */
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

/* Query 3 Which medical conditions are most common across different age groups,
 and what's the average billing per group? */
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
    
