# Thailand International Patient Journey

**Thailand - Healthcare Patient Journey**
Use case: international patient appointment integrity, cancellations, payment guarantee declines and desk document controls

> Patient journey operations for 40 fictional international patient coordination desks of a fictional Thai private hospital group, in Bangkok, Phuket, Chiang Mai, Pattaya and Hua Hin. The demo covers dynamic tables, an appointment-cancellation classifier evaluated on a time-based holdout, a journey-issue forecast, payment guarantee decline rate anomaly detection, a Cortex Agent that cites SOPs, a live appointment booking feed with an alert, and an SPCS app. All data is aggregate desk-day counts: no patient-level records, no clinical data.

## Why Snowflake

- **Dynamic tables** turn desk-day rows into appointments, journey issues, cancelled appointments, late arrivals and pre-arrival checklist audit compliance; `run_core.py` reconciles them against RAW on every build
- **Appointment-cancellation classification** gives each desk a next-7-day probability, evaluated on a time-based holdout
- **Journey-issue forecast** projects 14 days of group-wide journey issues with prediction intervals, to plan coordinator cover
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, Search over SOPs) shows the SQL it ran and the SOPs it cited
- **Live bookings**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), feeding an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.DESKS` (40 rows) |
| Fact table | `RAW.DESK_DAILY` (3,600 desk-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `ISSUE_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.CANCEL_RISK_SCORES`, `ML.CANCEL_RISK_HOLDOUT_METRICS`, `ML.ISSUE_FORECAST`, `ML.GUARANTEE_DECLINE_ANOMALIES` |

Currency: THB. Cities: Bangkok, Phuket, Chiang Mai, Pattaya, Hua Hin.
Service lines: Health check-up, Dental, Orthopaedics, Cardiology, Fertility.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Issue-Free Appointment Rate | 96.69% |
| Journey Issues Raised | 562 |
| Cancelled Appointments | 176 |
| Issue Cancellation Rate | 31.3% |
| Late Arrivals | 70 |
| Package Value (THB M) | 2,087 |
| Appointments Booked | 16,968 |
| Checklist Audit Compliance | 76.6% |
| Desks Monitored | 40 |
| Compliance Document Coverage | 50.0% |
| Compliance Documents Pending | 22 |

Values are synthetic. The data is HASH-seeded, so a rebuild reproduces them; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPI cards, daily journey issues against cancelled appointments, issues and cancellations by issue type, and the desk table
2. Predictive: holdout metrics, risk bands, the 14-day journey-issue forecast and payment guarantee decline rate anomalies
3. Controls: pre-arrival checklist audit compliance, desk document coverage and pending documents, checklist audit compliance against cancelled appointments, then the action memo
4. Live Bookings: run `CALL APP.SIMULATE_BOOKINGS(20)` (Snowflake only) or `python aws/publish_bookings.py --count 20` (AWS build), then `EXECUTE ALERT APP.LIVE_BOOKING_ALERT`, and show the alert log and email
5. Ask AI: the Cortex Agent answers metric questions through the semantic view, cites SOPs from Cortex Search and shows its SQL
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- 96.69% of international patient appointments go through without a journey issue. The 562 journey issues are where the coordinators spend their time, and almost one in three (31.3%) ends as a cancelled appointment.
- Declined payment guarantees cause the most cancelled appointments (60 of 165 issues). The flight schedule disruptions in Phuket and Chiang Mai hit every desk in the city on one day and were all resolved.
- Pattaya desks have the most cancelled appointments (51); Chiang Mai has the fewest (18).
- On a time-based holdout the risk model reaches precision 0.32 and recall 0.30 at 0.5, against a 0.21 base rate. Use it to decide which desk gets a review first, not as a verdict on a desk.
- Flight schedule disruptions are left out of model training because the desk did not cause them.
- The demo covers administrative journey steps only; it makes no clinical, diagnostic or treatment claims.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
