-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for International Patient Journey Analytics
-- ============================================================================
USE DATABASE PATIENT_JOURNEY;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.TREATMENT_PACKAGE_SEARCH
  ON PACKAGE_DESCRIPTION
  ATTRIBUTES TREATMENT_TYPE, HOSPITAL, PRICE_TIER
  WAREHOUSE = MEDTOUR_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.TREATMENT_PACKAGES
);
