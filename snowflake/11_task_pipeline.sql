-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for International Patient Journey Analytics
-- ============================================================================
USE DATABASE PATIENT_JOURNEY;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_GENERATE_RECOMMENDATIONS
  WAREHOUSE = MEDTOUR_WH
  SCHEDULE = 'USING CRON 0 8 * * * UTC'
  COMMENT = 'Generate personalized package recommendations for new inquiries'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_SEND_FOLLOWUPS
  WAREHOUSE = MEDTOUR_WH
  AFTER APP.TASK_GENERATE_RECOMMENDATIONS
  COMMENT = 'Send personalized follow-up communications via Notification Integration'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_REFRESH_FORECASTS
  WAREHOUSE = MEDTOUR_WH
  SCHEDULE = 'USING CRON 0 3 * * 1 UTC'
  COMMENT = 'Refresh patient demand forecasts by source country'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_REFRESH_FORECASTS RESUME;
ALTER TASK APP.TASK_SEND_FOLLOWUPS RESUME;
ALTER TASK APP.TASK_GENERATE_RECOMMENDATIONS RESUME;
