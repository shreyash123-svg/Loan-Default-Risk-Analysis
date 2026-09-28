-- ============================================================
-- PROJECT: LOAN DEFAULT RISK ANALYSIS
-- ============================================================


-- ============================================================
-- STEP 1: CREATE TABLE STRUCTURE
-- ============================================================
drop table if exists loans;

CREATE TABLE loans (
    loan_amnt NUMERIC,
    grade VARCHAR(5),
    emp_length VARCHAR(20),
    annual_inc NUMERIC,
    loan_status VARCHAR(30),
    purpose VARCHAR(50),
    addr_state VARCHAR(5),
    is_default INTEGER
);


-- ============================================================
-- STEP 2: BASIC DATA CHECK
-- ============================================================

SELECT * FROM loans;

SELECT DISTINCT emp_length FROM loans;


-- ============================================================
-- STEP 3: EMPLOYMENT LENGTH ANALYSIS
-- ============================================================

SELECT 
    CASE 
        WHEN emp_length IN ('< 1 year', '1 year', '2 years') THEN 'new employees'
        WHEN emp_length IN ('3 years', '4 years', '5 years', '6 years') THEN 'mid experience'
        WHEN emp_length IN ('7 years', '8 years', '9 years', '10+ years') THEN 'experienced'
        ELSE 'unknown'
    END AS bucket,
    COUNT(*) AS total_loans,
    ROUND(AVG(is_default) * 100, 2) AS default_rate
FROM loans
GROUP BY bucket
ORDER BY default_rate DESC;


-- ============================================================
-- STEP 4: INCOME ANALYSIS
-- ============================================================

SELECT MIN(annual_inc), MAX(annual_inc), AVG(annual_inc) FROM loans;

SELECT 
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY annual_inc) AS p25,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY annual_inc) AS p50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY annual_inc) AS p75
FROM loans;

SELECT 
    CASE 
        WHEN annual_inc < 46000 THEN 'low income'
        WHEN annual_inc BETWEEN 46000 AND 92648 THEN 'mid income'
        WHEN annual_inc > 92648 THEN 'high income'
    END AS income_bracket,
    COUNT(*) AS total_loans,
    ROUND(AVG(is_default) * 100, 2) AS default_rate
FROM loans
GROUP BY income_bracket
ORDER BY default_rate DESC;


-- ============================================================
-- OVERALL BASELINE
-- ============================================================
SELECT COUNT(*) AS total_loans, ROUND(AVG(is_default)*100, 2) AS overall_default_rate
FROM loans;


-- ============================================================
-- STEP 5: LOAN PURPOSE ANALYSIS (NEXT STEP - PENDING)
-- ============================================================

select * from loans

select purpose, count(*) as total_loans,
round(avg(is_default)*100,2) as default_rate
from loans
group by purpose

-- ============================================================
-- STEP 6: GEOGRAPHY ANALYSIS (PENDING)
-- ============================================================

select addr_state, count(*) as total_loans,
round(avg(is_default)*100,2) as default_rate
from loans
group by addr_state
order by default_rate desc;
-- ============================================================
-- STEP 7: RISK SCORE (PENDING)
-- ============================================================
-- STEP 7: WEIGHTED RISK SCORE
-- ============================================================

SELECT 
    loan_amnt,
    grade,
    emp_length,
    annual_inc,
    purpose,
    addr_state,
    is_default,

    -- Purpose points (max weight: 30)
    CASE 
        WHEN purpose IN ('small_business','house','moving','medical') THEN 30
        WHEN purpose IN ('debt_consolidation','renewable_energy','other','major_purchase','home_improvement','vacation') THEN 15
        WHEN purpose IN ('credit_card','car') THEN 5
        ELSE 10
    END
    +
    -- Income points (max weight: 25)
    CASE 
        WHEN annual_inc < 46000 THEN 25
        WHEN annual_inc BETWEEN 46000 AND 92648 THEN 15
        WHEN annual_inc > 92648 THEN 5
    END
    +
    -- Geography points (medium weight: 15)
    CASE 
        WHEN addr_state IN ('NE','OK','SD','AR','LA','AL','MS','WY','KY','AK') THEN 15
        WHEN addr_state IN ('GA','CO','RI','WA','KS','VT','SC','ME','DC','OR','NH','WV') THEN 3
        ELSE 8
    END
    +
    -- Employment points (low weight: 10)
    CASE 
        WHEN emp_length IN ('< 1 year','1 year','2 years') THEN 7
        WHEN emp_length IN ('3 years','4 years','5 years','6 years') THEN 6
        WHEN emp_length IN ('7 years','8 years','9 years','10+ years') THEN 4
        ELSE 10
    END
    AS risk_score

FROM loans;
-- ============================================================
-- STEP 7b: RISK TIER 
-- ============================================================

SELECT *,
    CASE 
        WHEN risk_score >= 55 THEN 'High Risk - Manual Review'
        WHEN risk_score BETWEEN 35 AND 54 THEN 'Medium Risk - Monitor'
        ELSE 'Low Risk - Auto Approve'
    END AS risk_tier
FROM (
    SELECT 
        loan_amnt, grade, emp_length, annual_inc, purpose, addr_state, is_default,
        CASE 
            WHEN purpose IN ('small_business','house','moving','medical') THEN 30
            WHEN purpose IN ('debt_consolidation','renewable_energy','other','major_purchase','home_improvement','vacation') THEN 15
            WHEN purpose IN ('credit_card','car') THEN 5
            ELSE 10
        END
        +
        CASE 
            WHEN annual_inc < 46000 THEN 25
            WHEN annual_inc BETWEEN 46000 AND 92648 THEN 15
            WHEN annual_inc > 92648 THEN 5
        END
        +
        CASE 
            WHEN addr_state IN ('NE','OK','SD','AR','LA','AL','MS','WY','KY','AK') THEN 15
            WHEN addr_state IN ('GA','CO','RI','WA','KS','VT','SC','ME','DC','OR','NH','WV') THEN 3
            ELSE 8
        END
        +
        CASE 
            WHEN emp_length IN ('< 1 year','1 year','2 years') THEN 7
            WHEN emp_length IN ('3 years','4 years','5 years','6 years') THEN 6
            WHEN emp_length IN ('7 years','8 years','9 years','10+ years') THEN 4
            ELSE 10
        END AS risk_score
    FROM loans
) t;
-- 
SELECT risk_tier, COUNT(*) AS total_loans, ROUND(AVG(is_default)*100,2) AS actual_default_rate
FROM (
    SELECT *,
        CASE 
            WHEN risk_score >= 55 THEN 'High Risk - Manual Review'
            WHEN risk_score BETWEEN 35 AND 54 THEN 'Medium Risk - Monitor'
            ELSE 'Low Risk - Auto Approve'
        END AS risk_tier
    FROM (
        SELECT 
            loan_amnt, grade, emp_length, annual_inc, purpose, addr_state, is_default,
            CASE 
                WHEN purpose IN ('small_business','house','moving','medical') THEN 30
                WHEN purpose IN ('debt_consolidation','renewable_energy','other','major_purchase','home_improvement','vacation') THEN 15
                WHEN purpose IN ('credit_card','car') THEN 5
                ELSE 10
            END
            +
            CASE 
                WHEN annual_inc < 46000 THEN 25
                WHEN annual_inc BETWEEN 46000 AND 92648 THEN 15
                WHEN annual_inc > 92648 THEN 5
            END
            +
            CASE 
                WHEN addr_state IN ('NE','OK','SD','AR','LA','AL','MS','WY','KY','AK') THEN 15
                WHEN addr_state IN ('GA','CO','RI','WA','KS','VT','SC','ME','DC','OR','NH','WV') THEN 3
                ELSE 8
            END
            +
            CASE 
                WHEN emp_length IN ('< 1 year','1 year','2 years') THEN 7
                WHEN emp_length IN ('3 years','4 years','5 years','6 years') THEN 6
                WHEN emp_length IN ('7 years','8 years','9 years','10+ years') THEN 4
                ELSE 10
            END AS risk_score
        FROM loans
    ) t
) inner_query
GROUP BY risk_tier
ORDER BY actual_default_rate DESC;
-- ============================================================