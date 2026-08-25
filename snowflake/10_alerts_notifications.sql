-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for International Patient Journey Analytics
-- ============================================================================
USE DATABASE PATIENT_JOURNEY;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_thailand_healthcare_patient_journey_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<YOUR_EMAIL>');

-- Alert: CONVERSION_DROP_ALERT
CREATE OR REPLACE ALERT APP.CONVERSION_DROP_ALERT
  WAREHOUSE = MEDTOUR_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Conversion rate significantly below baseline'
IF (EXISTS (
  SELECT 1 FROM CURATED.PATIENT_LIFETIME_VALUE
  WHERE 1=1 -- Condition: CONVERSION_RATE < 15% for any source-treatment pair (vs 25% baseline)
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_thailand_healthcare_patient_journey_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] International Patient Journey Analytics: Conversion rate significantly below baseline',
    'Conversion rate significantly below baseline'
  );

ALTER ALERT APP.CONVERSION_DROP_ALERT RESUME;

-- Alert: VIP_INQUIRY_ALERT
CREATE OR REPLACE ALERT APP.VIP_INQUIRY_ALERT
  WAREHOUSE = MEDTOUR_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'High-value patient inquiry — prioritize response'
IF (EXISTS (
  SELECT 1 FROM CURATED.PATIENT_LIFETIME_VALUE
  WHERE 1=1 -- Condition: ESTIMATED_VALUE > ฿2M for new inquiry
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_thailand_healthcare_patient_journey_EMAIL_INT',
    '<YOUR_EMAIL>',
    '[ALERT] International Patient Journey Analytics: High-value patient inquiry — prioritize response',
    'High-value patient inquiry — prioritize response'
  );

ALTER ALERT APP.VIP_INQUIRY_ALERT RESUME;

