# Demo Script: International Patient Journey Analytics
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake unifies international patient data across 15 hospitals, generates AI-powered treatment package recommendations, and automates personalized outreach — replacing fragmented systems with unified patient intelligence"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Dr. Sirichai Kanjanawasee** | Chief Medical Tourism Officer | React App (SPCS) | Patient acquisition cost, treatment package revenue, source market mix, patient satisfaction |
| **Ornuma Setthabutr** | Patient Experience Director | Amazon QuickSight | Patient journey touchpoints, inquiry-to-treatment conversion, post-treatment follow-up, package personalization |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 8 tables | HOSPITALS (15), PATIENTS (45000), TREATMENT_PACKAGES (200), INQUIRIES (120000), JOURNEYS (85000), PATIENT_REVIEWS (35000), REFERRAL_AGENTS (350), THAI_MEDTOUR_MARKET (12) |
| **CURATED** | 4 Dynamic Tables | PATIENT_LIFETIME_VALUE, CONVERSION_FUNNEL, PACKAGE_PERFORMANCE, SOURCE_MARKET_TRENDS |
| **ML** | ML.FORECAST + ML.ANOMALY_DETECTION | Forecasting + anomaly detection |
| **AI** | COMPLETE, AI_SENTIMENT, AI_CLASSIFY | Classification + extraction |
| **Search** | Cortex Search | 200 documents indexed |
| **Agent** | PATIENT_JOURNEY_AGENT | Semantic View + Search tools |


---

## The Story

Thailand welcomes 3.5 million medical tourists annually generating ฿140B — but fragmented patient data across 15 hospitals means personalization opportunities are missed and conversion rates are declining. AI-powered package recommendations, demand forecasting, and automated outreach capture ฿480M in additional revenue potential.

---

## Script

### [0:00–0:45] EXECUTIVE COCKPIT

**Show**: Executive Cockpit tab

> "Medical tourism revenue: ฿4.2B this year across 15 hospitals. Average revenue per patient: ฿320K."

**Action**: Point at revenue by source market treemap

### [0:45–1:30] AI PACKAGE RECOMMENDATIONS

**Show**: AI Package Recommendations tab

> "Cortex Complete generates personalized package recommendations for each patient inquiry."

**Action**: Show recommendation engine interface

### [1:30–2:15] DEMAND FORECASTING

**Show**: Demand Forecasting tab

> "ML.FORECAST predicts patient volume by source country 90 days ahead."

**Action**: Show demand forecast by top 5 source countries

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Dr. Sirichai asks: 'What should we do to recover aesthetic conversion rates?'"

**Action**: Type: 'Why is aesthetic conversion declining?'

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Seven Snowflake capabilities, six AWS services."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **Cortex Complete for treatment package recommendations** — Only demo generating personalized medical tourism package recommendations considering clinical + preference data
2. **ML.FORECAST for patient demand by source country** — 90-day demand forecasting enabling hospital capacity planning
3. **Notification Integration for patient communications** — Automated multilingual patient outreach (Thai, English, Arabic, Burmese)
4. **Thai medical tourism context** — 15 hospitals (Bumrungrad, Bangkok Dusit Medical, etc.) with realistic source market data
5. **Conversion funnel optimization** — AI identifies drop-off points in the inquiry-to-treatment patient journey
6. **Patient lifetime value via Dynamic Tables** — Real-time CLV calculation driving acquisition and retention investment


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM PATIENT_JOURNEY.RAW.PATIENTS` → 45000
- [ ] `SELECT COUNT(*) FROM PATIENT_JOURNEY.RAW.INQUIRIES` → 120000
- [ ] `SELECT COUNT(*) FROM PATIENT_JOURNEY.CURATED.CONVERSION_FUNNEL WHERE CONVERSION_RATE < 0.15` → >5

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM PATIENT_JOURNEY.ML.PATIENT_DEMAND_FORECAST_RESULTS` → >0
- [ ] `SELECT SUM(CASE WHEN IS_ANOMALY THEN 1 ELSE 0 END) FROM PATIENT_JOURNEY.ML.CONVERSION_ANOMALY_RESULTS` → >=3

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM PATIENT_JOURNEY.AI.PACKAGE_RECOMMENDATIONS` → >5000

