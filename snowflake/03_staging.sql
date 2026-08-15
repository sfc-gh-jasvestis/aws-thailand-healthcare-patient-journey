-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for International Patient Journey Analytics
-- Country: THAILAND | Currency: THB
-- ============================================================================
USE DATABASE PATIENT_JOURNEY;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- HOSPITALS: 15 rows — Partner hospitals in Bangkok, Phuket, and Chiang Mai
-- PATIENTS: 45,000 rows — International patient records with demographics and source country
-- TREATMENT_PACKAGES: 200 rows — Medical tourism packages (cardiac, ortho, aesthetic, wellness, dental)
-- INQUIRIES: 120,000 rows — Patient inquiries via web, email, agents, and referrals
-- JOURNEYS: 85,000 rows — Patient journey touchpoints from inquiry to post-treatment
-- PATIENT_REVIEWS: 35,000 rows — Patient satisfaction reviews and NPS scores
-- REFERRAL_AGENTS: 350 rows — Medical tourism agents and facilitators by country
-- THAI_MEDTOUR_MARKET: 12 rows — Thailand medical tourism industry statistics
