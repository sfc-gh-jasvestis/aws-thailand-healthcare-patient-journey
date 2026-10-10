-- Synthetic desk-day observations for the international patient service desks
-- of a fictional Thai private hospital group. A desk is one fictional
-- international patient coordination desk in one Thai city for one service
-- line. Every row is an aggregate count per desk per day: there are no
-- patient-level records, no clinical data and no outcomes of care.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild
-- is reproducible: per-desk cancellation propensity, checklist drift between
-- pre-arrival checklist audits, missed audits, service-line weighted journey
-- issue types, issues resolved without cancellation, and two city-wide flight
-- schedule disruptions.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.DESKS AS
WITH desks AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DESK_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT DESK_INDEX,
         MOD(ABS(HASH(DESK_INDEX, 'thpjrn-age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(DESK_INDEX, 'thpjrn-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(DESK_INDEX, 'thpjrn-audit')), 1000000) / 1e6 AS U_AUDIT,
         MOD(ABS(HASH(DESK_INDEX, 'thpjrn-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(DESK_INDEX, 'thpjrn-tier')), 1000000) / 1e6 AS U_TIER
  FROM desks
)
SELECT 'DSK-' || LPAD(DESK_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic desk ' || LPAD(DESK_INDEX::VARCHAR, 4, '0') AS NAME,
       -- 5 and 8 are coprime, so 40 desks cover every city and service-line slot once.
       CASE MOD(DESK_INDEX, 5) WHEN 0 THEN 'Bangkok' WHEN 1 THEN 'Phuket'
            WHEN 2 THEN 'Chiang Mai' WHEN 3 THEN 'Pattaya' ELSE 'Hua Hin' END AS REGION,
       CASE MOD(DESK_INDEX, 8) WHEN 0 THEN 'Health check-up' WHEN 1 THEN 'Health check-up'
            WHEN 2 THEN 'Health check-up' WHEN 3 THEN 'Dental' WHEN 4 THEN 'Dental'
            WHEN 5 THEN 'Orthopaedics' WHEN 6 THEN 'Cardiology' ELSE 'Fertility' END AS CATEGORY,
       DESK_INDEX,
       1 + FLOOR(U_TIER * 3) AS RISK_TIER,
       ROUND(0.5 + U_AGE * 11.5, 1) AS DESK_AGE_YEARS,
       -- Base daily probability of a cancelled appointment 0.6%-3%; ~13% of desks
       -- are chronically weak (x3).
       (0.006 + U_RATE * 0.024) * IFF(U_RATE > 0.87, 3, 1) AS BASE_CANCEL_RATE,
       7 * (1 + FLOOR(U_AUDIT * 3)) AS CHECKLIST_AUDIT_INTERVAL_DAYS,
       0.5 + U_DISCIPLINE * 0.5 AS CHECKLIST_AUDIT_COMPLETION_PROB,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.DESK_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), city_events AS (
  -- Two city-wide flight schedule disruptions; every desk in the city raises a
  -- journey issue that is resolved once flights are rebooked.
  SELECT * FROM VALUES (31, 'Phuket'), (58, 'Chiang Mai') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT s.ID AS ENTITY_ID, s.DESK_INDEX, s.CATEGORY, s.REGION, s.DESK_AGE_YEARS,
         s.BASE_CANCEL_RATE, s.CHECKLIST_AUDIT_INTERVAL_DAYS, s.CHECKLIST_AUDIT_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + s.DESK_INDEX * 3, s.CHECKLIST_AUDIT_INTERVAL_DAYS) AS DAYS_SINCE_AUDIT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thpjrn-cancel')), 1000000) / 1e6 AS U_CANCEL,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thpjrn-detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thpjrn-resolve')), 1000000) / 1e6 AS U_RESOLVE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thpjrn-type')), 1000000) / 1e6 AS U_TYPE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thpjrn-done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thpjrn-volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thpjrn-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'thpjrn-late')), 1000000) / 1e6 AS U_LATE,
         e.REGION IS NOT NULL AS CITY_EVENT
  FROM RAW.DESKS s CROSS JOIN days d
  LEFT JOIN city_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = s.REGION
), audit AS (
  SELECT *,
         IFF(DAYS_SINCE_AUDIT = 0, 1, 0) AS CHECKLIST_AUDIT_DUE,
         IFF(DAYS_SINCE_AUDIT = 0 AND U_DONE < CHECKLIST_AUDIT_COMPLETION_PROB, 1, 0) AS CHECKLIST_AUDIT_DONE,
         -- Checklist drift (bookings missing pre-arrival items) rises between
         -- checklist audits; weak audit discipline carries it over.
         DAYS_SINCE_AUDIT / CHECKLIST_AUDIT_INTERVAL_DAYS + (1 - CHECKLIST_AUDIT_COMPLETION_PROB) AS DRIFT
  FROM base
), cancels AS (
  SELECT *,
         CASE WHEN U_CANCEL < LEAST(0.5, BASE_CANCEL_RATE * (0.4 + 1.6 * DRIFT) * (1 + 2 / (2 + DESK_AGE_YEARS))) / 4 THEN 2
              WHEN U_CANCEL < LEAST(0.5, BASE_CANCEL_RATE * (0.4 + 1.6 * DRIFT) * (1 + 2 / (2 + DESK_AGE_YEARS))) THEN 1
              ELSE 0 END AS CANCEL_RISK_COUNT
  FROM audit
), issues AS (
  SELECT *,
         -- About 80% of at-risk bookings raise an issue and end cancelled; the
         -- rest arrive late without an issue.
         IFF(CITY_EVENT, 0, IFF(U_DETECT < 0.8, CANCEL_RISK_COUNT, 0)) AS CANCELLED_COUNT,
         -- Issues resolved without cancellation: higher for longer journeys.
         IFF(CITY_EVENT, 1, IFF(U_RESOLVE < CASE CATEGORY WHEN 'Cardiology' THEN 0.17
                                                           WHEN 'Orthopaedics' THEN 0.14
                                                           WHEN 'Fertility' THEN 0.16 ELSE 0.08 END, 1, 0)) AS RESOLVED_COUNT
  FROM cancels
), measured AS (
  SELECT *,
         CANCELLED_COUNT + RESOLVED_COUNT AS ISSUE_COUNT,
         CASE CATEGORY WHEN 'Health check-up' THEN 6.5 WHEN 'Dental' THEN 5 WHEN 'Orthopaedics' THEN 3
                       WHEN 'Cardiology' THEN 2.5 ELSE 1.5 END
           * (0.7 + 0.6 * U_VOLUME) * (1 + 0.5 * CANCEL_RISK_COUNT) AS BOOKING_RAW,
         CASE CATEGORY WHEN 'Health check-up' THEN 38000 WHEN 'Dental' THEN 65000
                       WHEN 'Orthopaedics' THEN 420000 WHEN 'Cardiology' THEN 560000 ELSE 290000 END
           * (0.85 + 0.3 * U_NOISE) AS AVG_PRICE_THB
  FROM issues
), counted AS (
  -- A journey issue always belongs to an appointment booked that day.
  SELECT *, GREATEST(ISSUE_COUNT, ROUND(BOOKING_RAW)) AS BOOKING_COUNT FROM measured
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       BOOKING_COUNT,
       ROUND(BOOKING_COUNT * AVG_PRICE_THB, 0) AS BOOKING_VALUE_THB,
       ISSUE_COUNT, CANCELLED_COUNT,
       IFF(CANCELLED_COUNT > 0 AND U_LATE < 0.5, 1, 0) AS LATE_ARRIVAL,
       CASE WHEN ISSUE_COUNT = 0 THEN 'None'
            WHEN CITY_EVENT THEN 'Flight schedule disruption'
            WHEN CATEGORY = 'Health check-up' THEN IFF(U_TYPE < 0.45, 'Payment guarantee declined', IFF(U_TYPE < 0.8, 'Package quote dispute', 'Interpreter unavailable'))
            WHEN CATEGORY = 'Dental' THEN IFF(U_TYPE < 0.5, 'Payment guarantee declined', 'Package quote dispute')
            WHEN CATEGORY = 'Orthopaedics' THEN IFF(U_TYPE < 0.45, 'Pre-arrival records incomplete', IFF(U_TYPE < 0.8, 'Payment guarantee declined', 'Visa support letter delay'))
            WHEN CATEGORY = 'Cardiology' THEN IFF(U_TYPE < 0.4, 'Pre-arrival records incomplete', IFF(U_TYPE < 0.75, 'Visa support letter delay', 'Payment guarantee declined'))
            ELSE IFF(U_TYPE < 0.5, 'Interpreter unavailable', IFF(U_TYPE < 0.75, 'Visa support letter delay', 'Package quote dispute')) END AS ISSUE_TYPE,
       CHECKLIST_AUDIT_DUE, CHECKLIST_AUDIT_DONE,
       ROUND(5 + 6 * DRIFT + 9 * CANCEL_RISK_COUNT + U_NOISE * 3, 2) AS GUARANTEE_DECLINE_PCT,
       ROUND(2 + 3 * DRIFT + 4 * CANCEL_RISK_COUNT + U_NOISE * 1.5, 1) AS AVG_INQUIRY_RESPONSE_HRS,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM counted;

-- Desk document coverage (snapshot).
CREATE TABLE RAW.COMPLIANCE_DOCUMENTS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Health check-up' THEN 'Package price sheet'
                     WHEN 'Dental' THEN 'Insurer guarantee agreement'
                     WHEN 'Orthopaedics' THEN 'Airport transfer partner contract'
                     WHEN 'Cardiology' THEN 'Interpreter roster'
                     ELSE 'Coordinator training record' END AS DOC_TYPE,
       1 + MOD(ABS(HASH(ID, 'thpjrn-req')), 4) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'thpjrn-file')), 5) AS ON_FILE_QTY,
       IFF(MOD(ABS(HASH(ID, 'thpjrn-file')), 5) < 1 + MOD(ABS(HASH(ID, 'thpjrn-req')), 4),
           MOD(ABS(HASH(ID, 'thpjrn-pending')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.DESKS;
