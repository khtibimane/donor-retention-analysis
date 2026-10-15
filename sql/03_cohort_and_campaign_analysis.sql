-- 03_cohort_and_campaign_analysis.sql
-- Giving by cohort and year, and giving by campaign.
-- Run order: 3rd (after 01, with data loaded)

-- =====================================================
-- Cohort Giving Analysis
-- =====================================================

-- Step 3D: Giving and average gift by cohort and giving year
-- Cohort = year of a donor's first gift
-- Expected: 2023 cohort avg gift rises $141.35 -> $241.53 -> $267.26 (survivor effect)

WITH first_gift AS (
    -- Cohort assignment
    SELECT donor_id,
           EXTRACT(YEAR FROM MIN(gift_date))::INT AS cohort_year
    FROM gifts
    GROUP BY donor_id
)
SELECT
    f.cohort_year,
    EXTRACT(YEAR FROM g.gift_date)::INT AS gift_year,
    COUNT(*)                      AS gifts,
    COUNT(DISTINCT g.donor_id)    AS donors,
    ROUND(SUM(g.amount), 0)       AS total_giving,
    ROUND(AVG(g.amount), 2)       AS avg_gift
FROM gifts g
JOIN first_gift f ON g.donor_id = f.donor_id
GROUP BY f.cohort_year, EXTRACT(YEAR FROM g.gift_date)
ORDER BY f.cohort_year, gift_year;

-- =====================================================
-- Campaign Analysis
-- =====================================================

-- Step 3D-2: Giving and average gift by campaign
-- Window SUM gives each campaign's share of all giving
-- Expected: General Fund 53.6% | Year-End Appeal 29.3% | Spring Drive 11.3% | Disaster Relief 5.8%

SELECT
    campaign,
    COUNT(*)                   AS gifts,
    COUNT(DISTINCT donor_id)   AS donors,
    ROUND(SUM(amount), 0)      AS total_giving,
    ROUND(AVG(amount), 2)      AS avg_gift,
    ROUND(100.0 * SUM(amount) / SUM(SUM(amount)) OVER (), 1) AS pct_of_all_giving
FROM gifts
GROUP BY campaign
ORDER BY total_giving DESC;