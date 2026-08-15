-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for International Patient Journey Analytics
-- ============================================================================
USE DATABASE PATIENT_JOURNEY;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.MEDTOUR_ANALYTICS
  COMMENT = 'Medical tourism patient journey, conversion, and revenue analytics'
AS
  TABLES (
    CURATED.PATIENT_LIFETIME_VALUE AS patient_lifetime_value,CURATED.CONVERSION_FUNNEL AS conversion_funnel,CURATED.PACKAGE_PERFORMANCE AS package_performance,CURATED.SOURCE_MARKET_TRENDS AS source_market_trends
  );
