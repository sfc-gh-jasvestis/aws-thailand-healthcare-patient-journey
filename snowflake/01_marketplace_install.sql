-- ============================================================================
-- 01_MARKETPLACE_INSTALL.SQL — Install marketplace data for International Patient Journey Analytics
-- ============================================================================
USE DATABASE PATIENT_JOURNEY;
USE SCHEMA RAW;

-- Free listings to install from Snowflake Marketplace:
-- Install: Snowflake Public Data (Free)
--   https://app.snowflake.com/marketplace/listing/GZTSZ290BV255

-- Paid listing (mock): CEIC ASEAN Macro
--   Real data: https://app.snowflake.com/marketplace/listing/GZTSZRC7HPI
--   Using mock table: THAI_MEDTOUR_MARKET
CREATE TABLE IF NOT EXISTS RAW.THAI_MEDTOUR_MARKET (
  ID INT AUTOINCREMENT, DATA VARIANT, LOADED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

