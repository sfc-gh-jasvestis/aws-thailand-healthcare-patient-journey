-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-booking alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_BOOKINGS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic journey-issue knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.ISSUE_DOCS AS
WITH types AS (
  SELECT DISTINCT r.ISSUE_TYPE, a.CATEGORY
  FROM RAW.DESK_DAILY r JOIN RAW.DESKS a ON a.ID = r.ENTITY_ID
  WHERE r.CANCELLED_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, ISSUE_TYPE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  ISSUE_TYPE,
  CATEGORY || ' - ' || ISSUE_TYPE || ' journey issue handling' AS TITLE,
  'Synthetic demo SOP for international patient coordination (administrative steps only, no clinical guidance). Service line: ' || CATEGORY || '. Journey issue type: ' || ISSUE_TYPE || '. '
  || 'Step 1: log a journey case in the coordination system, notify the desk supervisor, and hold the appointment slot until a coordinator triages the case. '
  || 'Step 2: ' || CASE
       WHEN ISSUE_TYPE = 'Payment guarantee declined' THEN 'ask the insurer or assistance company for the written reason, send any missing administrative documents, offer a self-pay deposit quote as an alternative, and confirm the outcome within two working days.'
       WHEN ISSUE_TYPE = 'Package quote dispute' THEN 'resend the itemised package quote, explain what is included and excluded, and escalate to the desk supervisor when the gap with the expected price stays above 10%.'
       WHEN ISSUE_TYPE = 'Interpreter unavailable' THEN 'check the interpreter roster at nearby desks in the same group, offer a remote interpreter or a different appointment slot, and confirm the language support in writing.'
       WHEN ISSUE_TYPE = 'Pre-arrival records incomplete' THEN 'send the patient the list of missing administrative items through the agreed secure channel, set a deadline before travel, and rebook the slot only after the items are received.'
       WHEN ISSUE_TYPE = 'Visa support letter delay' THEN 'confirm the appointment details needed for the letter, issue the letter from the desk template, and give the patient a revised travel date in writing if the visa timeline slips.'
       ELSE 'review the issue against the desk booking history and escalate to the regional coordination manager if the cause is unclear.'
     END
  || ' Step 3: keep the case open and schedule a desk review when, after triage, the desk payment guarantee decline rate is above 20% or the average inquiry response time is above 6 hours. '
  || 'Step 4: close the case with the outcome; for a cancelled appointment or a late arrival, send the patient an update and add the case to the weekly desk operations report.' AS CONTENT
FROM types;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.ISSUE_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, ISSUE_TYPE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, ISSUE_TYPE, CONTENT FROM SEARCH.ISSUE_DOCS);

-- ---------- Payment guarantee decline rate anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.GUARANTEE_DECLINE_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, GUARANTEE_DECLINE_PCT::FLOAT AS GUARANTEE_DECLINE
FROM RAW.DESK_DAILY;
CREATE OR REPLACE VIEW ML.GUARANTEE_DECLINE_TRAIN AS
SELECT * FROM ML.GUARANTEE_DECLINE_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.GUARANTEE_DECLINE_SERIES);
CREATE OR REPLACE VIEW ML.GUARANTEE_DECLINE_DETECT AS
SELECT * FROM ML.GUARANTEE_DECLINE_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.GUARANTEE_DECLINE_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.GUARANTEE_DECLINE_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.GUARANTEE_DECLINE_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'GUARANTEE_DECLINE',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.GUARANTEE_DECLINE_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS GUARANTEE_DECLINE, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.GUARANTEE_DECLINE_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.GUARANTEE_DECLINE_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'GUARANTEE_DECLINE'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.PATIENT_JOURNEY_ANALYTICS
  TABLES (
    desks AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'coordination desks', 'international patient desks')
      COMMENT = 'One row per desk (city and service line), 90-day aggregate totals',
    risk AS ML.CANCEL_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day appointment-cancellation probability per desk',
    issues AS CURATED.ISSUE_SUMMARY PRIMARY KEY (ISSUE_TYPE)
      COMMENT = 'Journey issues, cancelled appointments and late arrivals by issue type, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Desk group totals per day'
  )
  RELATIONSHIPS (risk_desk AS risk (ENTITY_ID) REFERENCES desks)
  FACTS (
    desks.issues_f AS ISSUE_COUNT,
    desks.cancelled_f AS CANCELLED_COUNT,
    desks.late_f AS LATE_ARRIVAL_COUNT,
    desks.bookings_f AS BOOKING_COUNT,
    desks.value_f AS BOOKING_VALUE_THB,
    desks.audit_due_f AS CHECKLIST_AUDIT_DUE,
    desks.audit_done_f AS CHECKLIST_AUDIT_DONE,
    risk.cancel_prob_f AS CANCEL_PROB_7D,
    issues.type_issues_f AS ISSUE_COUNT,
    issues.type_cancelled_f AS CANCELLED_COUNT,
    issues.type_late_f AS LATE_ARRIVAL_COUNT,
    issues.type_value_f AS EXPOSED_VALUE_THB,
    daily.day_issues_f AS ISSUE_COUNT,
    daily.day_cancelled_f AS CANCELLED_COUNT,
    daily.day_value_f AS BOOKING_VALUE_THB
  )
  DIMENSIONS (
    desks.desk_id AS ENTITY_ID WITH SYNONYMS = ('desk', 'coordination desk', 'entity'),
    desks.desk_name AS ENTITY_NAME,
    desks.city AS REGION WITH SYNONYMS = ('city', 'region', 'location')
      COMMENT = 'Thai city of the coordination desk',
    desks.category AS CATEGORY WITH SYNONYMS = ('service line', 'specialty', 'category'),
    desks.risk_tier AS RISK_TIER COMMENT = 'Desk operating risk tier 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    issues.issue_type AS ISSUE_TYPE WITH SYNONYMS = ('issue', 'journey issue type', 'issue reason'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    desks.desk_count AS COUNT(desks.desk_id) WITH SYNONYMS = ('number of desks', 'number of entities', 'how many desks'),
    desks.clean_booking_rate_pct AS 100 * (SUM(desks.bookings_f) - SUM(desks.issues_f)) / NULLIF(SUM(desks.bookings_f), 0)
      WITH SYNONYMS = ('issue-free appointment rate', 'clean booking rate')
      COMMENT = 'Appointments without a journey issue / appointments booked',
    desks.issue_cancellation_pct AS 100 * SUM(desks.cancelled_f) / NULLIF(SUM(desks.issues_f), 0)
      COMMENT = 'Cancelled appointments / journey issues raised',
    desks.issues_raised AS SUM(desks.issues_f) WITH SYNONYMS = ('journey issues', 'booking issues'),
    desks.cancelled_bookings_total AS SUM(desks.cancelled_f) WITH SYNONYMS = ('cancellations', 'cancelled', 'cancelled appointments'),
    desks.late_arrivals AS SUM(desks.late_f) WITH SYNONYMS = ('late arrivals', 'missed arrival dates'),
    desks.bookings_taken AS SUM(desks.bookings_f) WITH SYNONYMS = ('bookings', 'appointment bookings', 'appointments booked'),
    desks.total_booking_value_thb AS SUM(desks.value_f) WITH SYNONYMS = ('booking value', 'package value', 'package value in THB'),
    desks.checklist_audit_compliance_pct AS 100 * SUM(desks.audit_done_f) / NULLIF(SUM(desks.audit_due_f), 0)
      COMMENT = 'Pre-arrival checklist audits completed / audits due',
    risk.avg_cancel_prob AS AVG(risk.cancel_prob_f),
    issues.type_issues AS SUM(issues.type_issues_f),
    issues.type_cancelled AS SUM(issues.type_cancelled_f),
    issues.type_late AS SUM(issues.type_late_f),
    issues.type_cancel_share_pct AS 100 * SUM(issues.type_cancelled_f) / NULLIF(SUM(issues.type_issues_f), 0),
    daily.daily_issues AS SUM(daily.day_issues_f),
    daily.daily_cancelled AS SUM(daily.day_cancelled_f),
    daily.daily_booking_value_thb AS SUM(daily.day_value_f)
  )
  COMMENT = 'Synthetic Thailand international patient journey analytics, aggregate desk data (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.PATIENT_JOURNEY_AGENT
  COMMENT = 'Patient journey assistant over synthetic aggregate data for fictional Thai coordination desks'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic and aggregate; give no clinical advice. Give desk IDs and numbers with units (THB, %)."
  orchestration: "Use patient_journey_analyst for bookings, booking value in THB, journey issues, cancelled appointments, late arrivals, issue-free appointment rate, checklist audit compliance, desks, cities, service lines, issue types and cancellation risk. Use sop_search for journey-issue handling procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: patient_journey_analyst
      description: "Appointments booked, package value in THB, journey issues, cancelled appointments, late arrivals, issue-free appointment rate, checklist audit compliance, issue types and appointment-cancellation risk scores by desk, city and service line"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic journey-issue handling SOPs (administrative) by service line and issue type"
tool_resources:
  patient_journey_analyst:
    semantic_view: __DEMO_DB__.APP.PATIENT_JOURNEY_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.ISSUE_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-booking alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), DESK_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, AMOUNT_THB FLOAT, RESPONSE_MINUTES FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION TH_HEALTHCARE_PATIENT_JOURNEY_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (DESK_ID, EVENT_TS, AMOUNT_THB, RESPONSE_MINUTES, SOP_HINT)
    SELECT p.DESK_ID, p.EVENT_TS, p.AMOUNT_THB, p.RESPONSE_MINUTES,
           'Check ' || r.CATEGORY || ' journey-issue SOPs; current risk band ' || COALESCE(s.RISK_BAND, 'n/a')
    FROM RAW.LIVE_BOOKINGS p
    JOIN RAW.DESKS r ON r.ID = p.DESK_ID
    LEFT JOIN ML.CANCEL_RISK_SCORES s ON s.ENTITY_ID = p.DESK_ID
    WHERE p.STATUS = 'ISSUE'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.DESK_ID = p.DESK_ID AND l.EVENT_TS = p.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('TH_HEALTHCARE_PATIENT_JOURNEY_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Journey issue alert',
      'New live journey issues logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_BOOKING_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_BOOKINGS p
    WHERE p.STATUS = 'ISSUE'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.DESK_ID = p.DESK_ID AND l.EVENT_TS = p.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.ISSUE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.CANCEL_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.CANCEL_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.CANCEL_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'RISK_TIER', RISK_TIER, 'DESK_AGE_YEARS', DESK_AGE_YEARS,
             'GUARANTEE_DECLINE_PCT', GUARANTEE_DECLINE_PCT, 'AVG_INQUIRY_RESPONSE_HRS', AVG_INQUIRY_RESPONSE_HRS,
             'GUARANTEE_DECLINE_7D', GUARANTEE_DECLINE_7D, 'CANCELLED_30D', CANCELLED_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:CANCEL::FLOAT, 4) AS CANCEL_PROB_7D,
         CASE WHEN PRED:probability:CANCEL::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:CANCEL::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
