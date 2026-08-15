-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for International Patient Journey Analytics
-- ============================================================================
USE DATABASE PATIENT_JOURNEY;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.PATIENT_JOURNEY_AGENT
  COMMENT = 'International Patient Journey Analytics AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'PATIENT_JOURNEY.APP.MEDTOUR_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'PATIENT_JOURNEY.SEARCH.TREATMENT_PACKAGE_SEARCH', TOOL_DESCRIPTION => 'Search documents for Healthcare & Medical Tourism information')
  )
  SYSTEM_PROMPT = 'You are the Patient Journey Intelligence Agent for Thailand''s medical tourism network of 15 hospitals, helping optimize patient acquisition, package recommendations, and satisfaction.';
