CREATE DATABASE collections_assignment;
USE collections_assignment;

USE collections_assignment;

SELECT COUNT(*) AS payment_rows
FROM payments;

SELECT *
FROM payments
LIMIT 5;

DESCRIBE accounts;
DESCRIBE call_dispositions;
DESCRIBE payments;
DESCRIBE daily_targeting;

USE collections_assignment;


-- =========================================================
-- 1. BASIC DATA PROFILE
-- =========================================================

SELECT 'accounts' AS table_name, COUNT(*) AS "rows"
FROM accounts

UNION ALL

SELECT 'call_dispositions', COUNT(*)
FROM call_dispositions

UNION ALL

SELECT 'payments', COUNT(*)
FROM payments

UNION ALL

SELECT 'daily_targeting', COUNT(*)
FROM daily_targeting;


-- =========================================================
-- 2. PAYMENT DUPLICATE CHECK
-- =========================================================

SELECT
    payment_id,
    COUNT(DISTINCT account_id) AS accounts,
    COUNT(DISTINCT borrower_id) AS borrowers,
    COUNT(DISTINCT event_at) AS timestamps,
    COUNT(DISTINCT payment_reference) AS references_count,
    COUNT(DISTINCT amount) AS amounts,
    COUNT(DISTINCT payment_status) AS statuses,
    COUNT(DISTINCT payment_method) AS methods,
    COUNT(DISTINCT provider_id) AS providers
FROM payments
GROUP BY payment_id
HAVING COUNT(*) > 1
ORDER BY rows DESC;


-- =========================================================
-- 3. GOLDEN PAYMENTS
-- Keep one record per payment_id.
-- Prefer the record containing a payment_reference.
-- =========================================================

CREATE OR REPLACE VIEW gold_payments AS

WITH ranked AS (
    SELECT
        p.*,

        ROW_NUMBER() OVER (
            PARTITION BY payment_id
            ORDER BY
                CASE
                    WHEN payment_reference IS NOT NULL THEN 0
                    ELSE 1
                END,
                event_at
        ) AS rn

    FROM payments p
)

SELECT
    payment_id,
    account_id,
    borrower_id,
    event_at,
    payment_reference,
    amount,
    payment_status,
    payment_method,
    provider_id

FROM ranked
WHERE rn = 1;


-- Verify Golden Dataset
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT payment_id) AS unique_payment_ids
FROM gold_payments;


-- =========================================================
-- 4. RAW VS GOLDEN SUCCESSFUL RECOVERY
-- =========================================================

SELECT
    'RAW' AS dataset,
    SUM(
        CASE
            WHEN payment_status = 'SUCCESS'
            THEN amount
            ELSE 0
        END
    ) AS successful_recovery
FROM payments

UNION ALL

SELECT
    'GOLD',
    SUM(
        CASE
            WHEN payment_status = 'SUCCESS'
            THEN amount
            ELSE 0
        END
    )
FROM gold_payments;


-- =========================================================
-- 5. DUPLICATE PAYMENT FINANCIAL IMPACT
-- =========================================================

WITH raw_recovery AS (
    SELECT
        SUM(
            CASE
                WHEN payment_status = 'SUCCESS'
                THEN amount
                ELSE 0
            END
        ) AS recovery
    FROM payments
),

gold_recovery AS (
    SELECT
        SUM(
            CASE
                WHEN payment_status = 'SUCCESS'
                THEN amount
                ELSE 0
            END
        ) AS recovery
    FROM gold_payments
)

SELECT
    raw_recovery.recovery AS raw_recovery,
    gold_recovery.recovery AS dedup_recovery,

    raw_recovery.recovery
        - gold_recovery.recovery
        AS potential_duplicate_impact,

    ROUND(
        100 *
        (
            raw_recovery.recovery
            - gold_recovery.recovery
        )
        / NULLIF(raw_recovery.recovery, 0),
        2
    ) AS duplicate_share_pct

FROM raw_recovery
CROSS JOIN gold_recovery;


-- =========================================================
-- 6. MONTHLY RECOVERY
-- =========================================================

SELECT
    DATE_FORMAT(event_at, '%Y-%m') AS month,

    SUM(
        CASE
            WHEN payment_status = 'SUCCESS'
            THEN amount
            ELSE 0
        END
    ) AS recovery,

    COUNT(
        DISTINCT CASE
            WHEN payment_status = 'SUCCESS'
            THEN account_id
        END
    ) AS paying_accounts

FROM gold_payments

GROUP BY DATE_FORMAT(event_at, '%Y-%m')

ORDER BY month;


-- =========================================================
-- 7. TARGETING COVERAGE
-- Portfolio denominator = ALL accounts
-- =========================================================

WITH portfolio AS (
    SELECT COUNT(DISTINCT account_id) AS total_accounts
    FROM accounts
),

targeted AS (
    SELECT COUNT(DISTINCT account_id) AS targeted_accounts
    FROM daily_targeting
)

SELECT
    portfolio.total_accounts,
    targeted.targeted_accounts,

    ROUND(
        100 * targeted.targeted_accounts
        / NULLIF(portfolio.total_accounts, 0),
        2
    ) AS targeting_coverage_pct

FROM portfolio
CROSS JOIN targeted;


-- =========================================================
-- 8. RECOVERY PER TARGETED ACCOUNT
-- =========================================================

WITH targeted AS (
    SELECT DISTINCT
        account_id
    FROM daily_targeting
),

recovery AS (
    SELECT
        account_id,
        SUM(amount) AS recovery
    FROM gold_payments
    WHERE payment_status = 'SUCCESS'
    GROUP BY account_id
)

SELECT

    COUNT(DISTINCT t.account_id)
        AS targeted_accounts,

    SUM(COALESCE(r.recovery, 0))
        AS total_recovery,

    ROUND(
        SUM(COALESCE(r.recovery, 0))
        / NULLIF(COUNT(DISTINCT t.account_id), 0),
        2
    ) AS recovery_per_targeted_account

FROM targeted t

LEFT JOIN recovery r
    ON t.account_id = r.account_id;


-- =========================================================
-- 9. TARGETED VS PAYING ACCOUNTS
-- =========================================================

WITH targeted AS (
    SELECT DISTINCT
        account_id
    FROM daily_targeting
),

paying AS (
    SELECT DISTINCT
        account_id
    FROM gold_payments
    WHERE payment_status = 'SUCCESS'
)

SELECT
    COUNT(DISTINCT t.account_id) AS targeted_accounts,

    COUNT(DISTINCT p.account_id) AS paying_accounts,

    ROUND(
        100 *
        COUNT(DISTINCT p.account_id)
        / NULLIF(COUNT(DISTINCT t.account_id), 0),
        2
    ) AS targeted_to_paying_pct

FROM targeted t

LEFT JOIN paying p
    ON t.account_id = p.account_id;


-- =========================================================
-- 10. RECOVERY BY CAMPAIGN
-- =========================================================

WITH targeted AS (
    SELECT DISTINCT
        campaign_id,
        account_id
    FROM daily_targeting
),

recovery AS (
    SELECT
        account_id,
        SUM(amount) AS recovery
    FROM gold_payments
    WHERE payment_status = 'SUCCESS'
    GROUP BY account_id
)

SELECT
    t.campaign_id,

    COUNT(DISTINCT t.account_id)
        AS targeted_accounts,

    SUM(COALESCE(r.recovery, 0))
        AS recovery,

    COUNT(
        DISTINCT CASE
            WHEN r.recovery > 0
            THEN t.account_id
        END
    ) AS paying_accounts,

    ROUND(
        SUM(COALESCE(r.recovery, 0))
        / NULLIF(COUNT(DISTINCT t.account_id), 0),
        2
    ) AS recovery_per_targeted_account

FROM targeted t

LEFT JOIN recovery r
    ON t.account_id = r.account_id

GROUP BY t.campaign_id

ORDER BY recovery_per_targeted_account DESC;


-- =========================================================
-- 11. RECOVERY BY RECOMMENDED CHANNEL
-- =========================================================

WITH targeted AS (
    SELECT DISTINCT
        account_id,
        recommended_channel
    FROM daily_targeting
),

recovery AS (
    SELECT
        account_id,
        SUM(amount) AS recovery
    FROM gold_payments
    WHERE payment_status = 'SUCCESS'
    GROUP BY account_id
)

SELECT
    t.recommended_channel,

    COUNT(DISTINCT t.account_id)
        AS targeted_accounts,

    SUM(COALESCE(r.recovery, 0))
        AS recovery,

    COUNT(
        DISTINCT CASE
            WHEN r.recovery > 0
            THEN t.account_id
        END
    ) AS paying_accounts,

    ROUND(
        SUM(COALESCE(r.recovery, 0))
        / NULLIF(COUNT(DISTINCT t.account_id), 0),
        2
    ) AS recovery_per_targeted_account

FROM targeted t

LEFT JOIN recovery r
    ON t.account_id = r.account_id

GROUP BY t.recommended_channel

ORDER BY recovery_per_targeted_account DESC;


-- =========================================================
-- 12. RECOVERY BY RISK SEGMENT
-- =========================================================

WITH recovery AS (
    SELECT
        account_id,
        SUM(amount) AS recovery
    FROM gold_payments
    WHERE payment_status = 'SUCCESS'
    GROUP BY account_id
)

SELECT
    a.risk_segment,

    COUNT(DISTINCT a.account_id)
        AS accounts,

    SUM(COALESCE(r.recovery, 0))
        AS recovery,

    ROUND(
        SUM(COALESCE(r.recovery, 0))
        / NULLIF(COUNT(DISTINCT a.account_id), 0),
        2
    ) AS recovery_per_account

FROM accounts a

LEFT JOIN recovery r
    ON a.account_id = r.account_id

GROUP BY a.risk_segment

ORDER BY recovery DESC;


-- =========================================================
-- 13. RECOVERY BY DPD BUCKET
-- =========================================================

WITH recovery AS (
    SELECT
        account_id,
        SUM(amount) AS recovery
    FROM gold_payments
    WHERE payment_status = 'SUCCESS'
    GROUP BY account_id
)

SELECT

    CASE
        WHEN a.dpd BETWEEN 0 AND 30 THEN '0-30'
        WHEN a.dpd BETWEEN 31 AND 60 THEN '31-60'
        WHEN a.dpd BETWEEN 61 AND 90 THEN '61-90'
        ELSE '90+'
    END AS dpd_bucket,

    COUNT(DISTINCT a.account_id)
        AS accounts,

    SUM(COALESCE(r.recovery, 0))
        AS recovery,

    ROUND(
        SUM(COALESCE(r.recovery, 0))
        / NULLIF(COUNT(DISTINCT a.account_id), 0),
        2
    ) AS recovery_per_account

FROM accounts a

LEFT JOIN recovery r
    ON a.account_id = r.account_id

GROUP BY

    CASE
        WHEN a.dpd BETWEEN 0 AND 30 THEN '0-30'
        WHEN a.dpd BETWEEN 31 AND 60 THEN '31-60'
        WHEN a.dpd BETWEEN 61 AND 90 THEN '61-90'
        ELSE '90+'
    END

ORDER BY
    MIN(a.dpd);


-- =========================================================
-- 14. CALL DISPOSITION ANALYSIS
-- =========================================================

SELECT
    disposition_code,
    COUNT(*) AS disposition_count,
    COUNT(DISTINCT account_id) AS unique_accounts

FROM call_dispositions

GROUP BY disposition_code

ORDER BY disposition_count DESC;


-- =========================================================
-- 15. DISPOSITION VERSION ANALYSIS
-- =========================================================

SELECT
    disposition_version,
    COUNT(*) AS records,
    COUNT(DISTINCT account_id) AS unique_accounts

FROM call_dispositions

GROUP BY disposition_version

ORDER BY records DESC;


-- =========================================================
-- 16. MONTH-OVER-MONTH RECOVERY
-- Demonstrates LAG() window function
-- =========================================================

WITH monthly AS (

    SELECT
        DATE_FORMAT(event_at, '%Y-%m') AS month,

        SUM(
            CASE
                WHEN payment_status = 'SUCCESS'
                THEN amount
                ELSE 0
            END
        ) AS recovery

    FROM gold_payments

    GROUP BY DATE_FORMAT(event_at, '%Y-%m')
),

comparison AS (

    SELECT
        month,
        recovery,

        LAG(recovery) OVER (
            ORDER BY month
        ) AS previous_recovery

    FROM monthly
)

SELECT
    month,
    recovery,
    previous_recovery,

    ROUND(
        100 *
        (recovery - previous_recovery)
        / NULLIF(previous_recovery, 0),
        2
    ) AS mom_change_pct

FROM comparison

ORDER BY month;