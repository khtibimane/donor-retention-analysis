-- 01_schema_and_data_quality.sql
-- Creates the tables, loads the CSVs, and validates the data.
-- Run order: 1st (before 02 and 03)

-- Step 2A: Schema
CREATE TABLE donors (
    donor_id    VARCHAR(10) PRIMARY KEY,
    donor_type  VARCHAR(20),
    state       CHAR(2)
);

CREATE TABLE gifts (
    gift_id     VARCHAR(10) PRIMARY KEY,
    donor_id    VARCHAR(10) REFERENCES donors(donor_id),
    gift_date   DATE,
    amount      NUMERIC(10,2),
    campaign    VARCHAR(30),
    channel     VARCHAR(20)
);

-- Load donors.csv, then gifts.csv (pgAdmin Import/Export) before running the checks below

-- Step 2B: Data quality checks
-- Expected: 5,000 | 8,816 | 0 | 0 | 0 | 0

SELECT 'donors rows' AS check_name, COUNT(*) AS result FROM donors

UNION ALL
-- Row count
SELECT 'gifts rows', COUNT(*) FROM gifts

UNION ALL
-- Null check
SELECT 'null amounts or dates', COUNT(*) FROM gifts
WHERE amount IS NULL OR gift_date IS NULL

UNION ALL
-- Invalid values
SELECT 'amounts <= 0', COUNT(*) FROM gifts
WHERE amount <= 0

UNION ALL
-- Duplicate keys
SELECT 'duplicate gift IDs', COUNT(*) FROM (
    SELECT gift_id FROM gifts GROUP BY gift_id HAVING COUNT(*) > 1
) d

UNION ALL
-- Referential integrity (anti-join)
SELECT 'gifts with no matching donor', COUNT(*) FROM gifts g
LEFT JOIN donors d ON g.donor_id = d.donor_id
WHERE d.donor_id IS NULL;