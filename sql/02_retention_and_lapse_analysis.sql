-- 02_retention_and_lapse_analysis.sql
-- Retention by year, cohort retention, and lapsed donor analysis.
-- Run order: 2nd (after 01, with data loaded)

-- =====================================================
-- Retention Analysis
-- =====================================================

-- Step 3A: Year-over-year donor retention
-- Retention = share of last year's donors who gave again this year
-- Expected: 2023 = 29.4%, 2024 = 37.0%
-- Note: 2025 shows 0.0% because there is no 2026 data (ignore this row)

WITH yearly_donors AS (
    -- One row per donor per giving year
    SELECT DISTINCT
        donor_id,
        EXTRACT(YEAR FROM gift_date)::INT AS gift_year
    FROM gifts
),

retention AS (
    -- Self-join: match each donor-year to the same donor in the next year
    SELECT
        cur.gift_year,
        COUNT(DISTINCT cur.donor_id) AS donors_in_year,
        COUNT(DISTINCT nxt.donor_id) AS donors_who_returned
    FROM yearly_donors cur
    LEFT JOIN yearly_donors nxt
        ON cur.donor_id = nxt.donor_id
       AND nxt.gift_year = cur.gift_year + 1
    GROUP BY cur.gift_year
)

SELECT
    gift_year,
    donors_in_year,
    donors_who_returned,
    ROUND(100.0 * donors_who_returned / donors_in_year, 1) AS retention_pct
FROM retention
ORDER BY gift_year;

-- Step 3B: Cohort retention
-- Cohort = year of a donor's first gift
-- Expected: 2023 = 100 / 29.4 / 19.1, 2024 = 100 / 30.8, 2025 = 100

WITH first_gift AS (
    -- Cohort assignment
    SELECT
        donor_id,
        EXTRACT(YEAR FROM MIN(gift_date))::INT AS cohort_year
    FROM gifts
    GROUP BY donor_id
),

yearly_donors AS (
    -- One row per donor per giving year
    SELECT DISTINCT
        donor_id,
        EXTRACT(YEAR FROM gift_date)::INT AS gift_year
    FROM gifts
),

cohort_size AS (
    -- Donors per cohort
    SELECT
        cohort_year,
        COUNT(*) AS cohort_donors
    FROM first_gift
    GROUP BY cohort_year
),

cohort_activity AS (
    -- Active donors per cohort per year
    SELECT
        f.cohort_year,
        y.gift_year,
        COUNT(DISTINCT y.donor_id) AS active_donors
    FROM first_gift f
    JOIN yearly_donors y
        ON f.donor_id = y.donor_id
    GROUP BY f.cohort_year, y.gift_year
)

SELECT
    a.cohort_year,
    s.cohort_donors,
    a.gift_year,
    a.gift_year - a.cohort_year AS years_since_first,
    a.active_donors,
    ROUND(100.0 * a.active_donors / s.cohort_donors, 1) AS retention_pct
FROM cohort_activity a
JOIN cohort_size s
    ON a.cohort_year = s.cohort_year
ORDER BY a.cohort_year, a.gift_year;

-- =====================================================
-- Lapsed Donor Analysis
-- =====================================================

-- Step 3C: Lapsed donor ranking
-- Lapsed = gave in 2024, no gift in 2025
-- Ranked by lifetime giving, with running share of lapsed giving
-- Expected: 1,405 rows

WITH donor_totals AS (
    -- Lifetime giving per donor
    SELECT
        donor_id,
        COUNT(*)       AS gift_count,
        SUM(amount)    AS total_given,
        MAX(gift_date) AS last_gift_date
    FROM gifts
    GROUP BY donor_id
),

gave_2024 AS (
    SELECT DISTINCT donor_id
    FROM gifts
    WHERE EXTRACT(YEAR FROM gift_date) = 2024
),

gave_2025 AS (
    SELECT DISTINCT donor_id
    FROM gifts
    WHERE EXTRACT(YEAR FROM gift_date) = 2025
),

lapsed AS (
    -- Anti-join: 2024 donors with no 2025 match
    SELECT a.donor_id
    FROM gave_2024 a
    LEFT JOIN gave_2025 b
        ON a.donor_id = b.donor_id
    WHERE b.donor_id IS NULL
)

SELECT
    -- Window function: rank by total past giving
    RANK() OVER (ORDER BY t.total_given DESC) AS priority_rank,
    l.donor_id,
    d.donor_type,
    d.state,
    t.gift_count,
    t.total_given,
    t.last_gift_date,
    -- Window function: running share of all lapsed giving
    ROUND(
        100.0 * SUM(t.total_given) OVER (ORDER BY t.total_given DESC, l.donor_id)
        / SUM(t.total_given) OVER (),
        1
    ) AS cumulative_pct_of_lapsed_giving
FROM lapsed l
JOIN donor_totals t
    ON l.donor_id = t.donor_id
JOIN donors d
    ON l.donor_id = d.donor_id
ORDER BY priority_rank, l.donor_id;

-- Step 3C-2: Lapsed giving concentration (Pareto)
-- Donors needed to reach 50% and 80% of lapsed giving
-- Expected: 1,405 lapsed | 77 for 50% | 441 for 80% | $212,325 total

WITH donor_totals AS (
    SELECT donor_id, SUM(amount) AS total_given
    FROM gifts
    GROUP BY donor_id
),

lapsed AS (
    SELECT DISTINCT donor_id
    FROM gifts
    WHERE EXTRACT(YEAR FROM gift_date) = 2024
      AND donor_id NOT IN (
          SELECT donor_id FROM gifts
          WHERE EXTRACT(YEAR FROM gift_date) = 2025
      )
),

ranked AS (
    SELECT
        l.donor_id,
        t.total_given,
        ROW_NUMBER() OVER (ORDER BY t.total_given DESC, l.donor_id) AS donor_number,
        100.0 * SUM(t.total_given) OVER (ORDER BY t.total_given DESC, l.donor_id)
              / SUM(t.total_given) OVER () AS cumulative_pct
    FROM lapsed l
    JOIN donor_totals t ON l.donor_id = t.donor_id
)

SELECT
    COUNT(*) AS total_lapsed_donors,
    MIN(donor_number) FILTER (WHERE cumulative_pct >= 50) AS donors_to_reach_50pct,
    MIN(donor_number) FILTER (WHERE cumulative_pct >= 80) AS donors_to_reach_80pct,
    ROUND(SUM(total_given), 0) AS total_past_giving_of_lapsed
FROM ranked;