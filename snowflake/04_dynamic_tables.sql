-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for International Patient Journey Analytics
-- ============================================================================
USE DATABASE PATIENT_JOURNEY;
USE SCHEMA CURATED;

-- PATIENT_LIFETIME_VALUE: CLV by patient segment and source country
-- Source: PATIENTS, JOURNEYS, TREATMENT_PACKAGES
CREATE OR REPLACE DYNAMIC TABLE CURATED.PATIENT_LIFETIME_VALUE
  TARGET_LAG = '5 minutes'
  WAREHOUSE = MEDTOUR_WH
AS
SELECT * FROM RAW.PATIENTS;
-- TODO: Replace with actual join/aggregation logic per demo

-- CONVERSION_FUNNEL: Inquiry-to-treatment conversion metrics by stage
-- Source: INQUIRIES, JOURNEYS
CREATE OR REPLACE DYNAMIC TABLE CURATED.CONVERSION_FUNNEL
  TARGET_LAG = '5 minutes'
  WAREHOUSE = MEDTOUR_WH
AS
SELECT * FROM RAW.INQUIRIES;
-- TODO: Replace with actual join/aggregation logic per demo

-- PACKAGE_PERFORMANCE: Package revenue, conversion, and satisfaction metrics
-- Source: TREATMENT_PACKAGES, JOURNEYS, PATIENT_REVIEWS
CREATE OR REPLACE DYNAMIC TABLE CURATED.PACKAGE_PERFORMANCE
  TARGET_LAG = '5 minutes'
  WAREHOUSE = MEDTOUR_WH
AS
SELECT * FROM RAW.TREATMENT_PACKAGES;
-- TODO: Replace with actual join/aggregation logic per demo

-- SOURCE_MARKET_TRENDS: Patient volume trends by source country for forecasting
-- Source: PATIENTS, INQUIRIES
CREATE OR REPLACE DYNAMIC TABLE CURATED.SOURCE_MARKET_TRENDS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = MEDTOUR_WH
AS
SELECT * FROM RAW.PATIENTS;
-- TODO: Replace with actual join/aggregation logic per demo

