-- ============================================================================
-- International Patient Journey Analytics
-- Patient journey intelligence for Thailand's ฿140B medical tourism industry — Personalize drives package recommendations via Cortex Complete, SES delivers personalized communications through Notification Integration, and ML forecasts patient demand by source country.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS PATIENT_JOURNEY;
CREATE WAREHOUSE IF NOT EXISTS MEDTOUR_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE PATIENT_JOURNEY;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE MEDTOUR_WH;
