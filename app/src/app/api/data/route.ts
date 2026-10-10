import { NextResponse } from 'next/server';
import { demoPlatform } from '@/lib/platform';
import { executeQuery } from '@/lib/snowflake';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET() {
  try {
    const [kpis, trend, types, desks, freshness, risk, holdout, forecast, live, liveSummary, anomalies, alerts] = await Promise.all([
      executeQuery<{ TITLE: string; DISPLAY: string; STATUS: string }>(
        'SELECT TITLE, DISPLAY, STATUS FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER'),
      executeQuery<{ PERIOD: string; ISSUES: number | null; CANCELLED: number | null }>(`
        SELECT TO_CHAR(METRIC_DATE, 'YYYY-MM-DD') AS PERIOD,
               ISSUE_COUNT AS ISSUES, CANCELLED_COUNT AS CANCELLED
        FROM CURATED.TREND_ANALYSIS ORDER BY METRIC_DATE`),
      executeQuery<{ ISSUE_TYPE: string; ISSUES: number; CANCELLED: number }>(`
        SELECT ISSUE_TYPE, ISSUE_COUNT AS ISSUES, CANCELLED_COUNT AS CANCELLED
        FROM CURATED.ISSUE_SUMMARY ORDER BY CANCELLED_COUNT DESC, ISSUE_COUNT DESC`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, RISK_TIER, EVENT_COUNT, BOOKING_COUNT, ISSUE_COUNT,
               CANCELLED_COUNT, LATE_ARRIVAL_COUNT, ISSUE_CANCEL_PCT, CHECKLIST_AUDIT_PCT, ROUND(BOOKING_VALUE_THB / 1e6, 1) AS BOOKING_VALUE_THB_M
        FROM CURATED.PERFORMANCE_SUMMARY ORDER BY ENTITY_ID LIMIT 200`),
      executeQuery<{ RAW_WATERMARK: string | null; CURATED_WATERMARK: string | null }>(`
        SELECT (SELECT TO_CHAR(MAX(EVENT_DATE), 'YYYY-MM-DD') FROM RAW.DESK_DAILY) AS RAW_WATERMARK,
               (SELECT TO_CHAR(MAX(METRIC_DATE), 'YYYY-MM-DD') FROM CURATED.TREND_ANALYSIS) AS CURATED_WATERMARK`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(SCORED_AS_OF, 'YYYY-MM-DD') AS SCORED_AS_OF, CANCEL_PROB_7D, RISK_BAND
        FROM ML.CANCEL_RISK_SCORES ORDER BY CANCEL_PROB_7D DESC`),
      executeQuery<Record<string, string | number | null>>(
        'SELECT N, BASE_RATE, PRECISION_AT_50, RECALL_AT_50 FROM ML.CANCEL_RISK_HOLDOUT_METRICS'),
      executeQuery<Record<string, string | number | null>>(`
        SELECT TO_CHAR(FORECAST_DATE, 'YYYY-MM-DD') AS PERIOD, ISSUE_COUNT, LOWER_BOUND, UPPER_BOUND
        FROM ML.ISSUE_FORECAST ORDER BY FORECAST_DATE`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT DESK_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(AMOUNT_THB, 0) AS AMOUNT_THB,
               RESPONSE_MINUTES, STATUS, TO_CHAR(LOADED_AT, 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LOADED_AT
        FROM RAW.LIVE_BOOKINGS ORDER BY EVENT_TS DESC LIMIT 25`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT COUNT(*) AS N, COUNT_IF(STATUS = 'ISSUE') AS ISSUES,
               TO_CHAR(MAX(LOADED_AT), 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LAST_LOADED,
               ROUND(MEDIAN(DATEDIFF('second', SENT_TS, CONVERT_TIMEZONE('UTC', LOADED_AT)::TIMESTAMP_NTZ)), 0) AS MEDIAN_LAG_S
        FROM RAW.LIVE_BOOKINGS`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(EVENT_DATE, 'YYYY-MM-DD') AS EVENT_DATE, ROUND(GUARANTEE_DECLINE, 2) AS GUARANTEE_DECLINE,
               ROUND(EXPECTED, 2) AS EXPECTED, ROUND(UPPER_BOUND, 2) AS UPPER_BOUND
        FROM ML.GUARANTEE_DECLINE_ANOMALIES WHERE IS_ANOMALY ORDER BY EVENT_DATE DESC, ENTITY_ID LIMIT 50`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT DESK_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(AMOUNT_THB, 0) AS AMOUNT_THB,
               RESPONSE_MINUTES, SOP_HINT
        FROM APP.ALERT_LOG ORDER BY ALERTED_AT DESC, EVENT_TS DESC LIMIT 25`),
    ]);
    const numberOrNull = (value: unknown): number | null => {
      if (value === null || value === undefined) return null;
      const numeric = Number(value);
      if (!Number.isFinite(numeric)) throw new Error('Non-numeric measure in curated contract');
      return numeric;
    };
    const watermark = freshness[0]?.CURATED_WATERMARK ?? null;
    const ageDays = watermark ? (Date.now() - Date.parse(`${watermark}T00:00:00Z`)) / 86400000 : null;
    return NextResponse.json({
      platform: demoPlatform(),
      kpiCards: kpis.map((row) => ({ title: row.TITLE, value: row.DISPLAY, status: row.STATUS })),
      timeseries: trend.map((row) => ({ period: row.PERIOD, issues: numberOrNull(row.ISSUES), cancelled: numberOrNull(row.CANCELLED) })),
      categories: types.map((row) => ({ category: row.ISSUE_TYPE, issues: numberOrNull(row.ISSUES), cancelled: numberOrNull(row.CANCELLED) })),
      entities: desks.map((row) => ({
        id: row.ENTITY_ID, name: row.ENTITY_NAME, region: row.REGION, category: row.CATEGORY, tier: row.RISK_TIER,
        bookings: numberOrNull(row.BOOKING_COUNT), issues: numberOrNull(row.ISSUE_COUNT), cancelled: numberOrNull(row.CANCELLED_COUNT),
        late: numberOrNull(row.LATE_ARRIVAL_COUNT), cancelRate: numberOrNull(row.ISSUE_CANCEL_PCT),
        value: numberOrNull(row.BOOKING_VALUE_THB_M), checklistAudit: numberOrNull(row.CHECKLIST_AUDIT_PCT), events: numberOrNull(row.EVENT_COUNT),
      })),
      auditRisk: desks.map((row) => ({
        name: row.ENTITY_NAME, compliance: numberOrNull(row.CHECKLIST_AUDIT_PCT), cancelled: numberOrNull(row.CANCELLED_COUNT),
      })).filter((row) => row.compliance !== null && row.cancelled !== null),
      sourceWatermark: watermark,
      rawWatermark: freshness[0]?.RAW_WATERMARK ?? null,
      stale: ageDays === null || ageDays > 2,
      pipelineBehind: freshness[0]?.RAW_WATERMARK !== watermark,
      requestedAt: new Date().toISOString(),
      synthetic: true,
      risk: risk.map((row) => ({
        id: row.ENTITY_ID, scoredAsOf: row.SCORED_AS_OF,
        probability: numberOrNull(row.CANCEL_PROB_7D), band: row.RISK_BAND,
      })),
      holdout: holdout[0] ? {
        n: numberOrNull(holdout[0].N), baseRate: numberOrNull(holdout[0].BASE_RATE),
        precision: numberOrNull(holdout[0].PRECISION_AT_50), recall: numberOrNull(holdout[0].RECALL_AT_50),
      } : null,
      forecast: forecast.map((row) => ({
        period: row.PERIOD, value: numberOrNull(row.ISSUE_COUNT),
        lower: numberOrNull(row.LOWER_BOUND), upper: numberOrNull(row.UPPER_BOUND),
      })),
      modelStatus: holdout[0] ? 'holdout_evaluated' : 'missing',
      live: live.map((row) => ({
        id: row.DESK_ID, eventTs: row.EVENT_TS, amount: numberOrNull(row.AMOUNT_THB),
        response: numberOrNull(row.RESPONSE_MINUTES), status: row.STATUS, loadedAt: row.LOADED_AT,
      })),
      liveSummary: {
        n: numberOrNull(liveSummary[0]?.N), issues: numberOrNull(liveSummary[0]?.ISSUES),
        lastLoaded: liveSummary[0]?.LAST_LOADED ?? null, medianLagSeconds: numberOrNull(liveSummary[0]?.MEDIAN_LAG_S),
      },
      anomalies: anomalies.map((row) => ({
        id: row.ENTITY_ID, date: row.EVENT_DATE, declineRate: numberOrNull(row.GUARANTEE_DECLINE),
        expected: numberOrNull(row.EXPECTED), upper: numberOrNull(row.UPPER_BOUND),
      })),
      alerts: alerts.map((row) => ({
        id: row.DESK_ID, eventTs: row.EVENT_TS, amount: numberOrNull(row.AMOUNT_THB),
        response: numberOrNull(row.RESPONSE_MINUTES), hint: row.SOP_HINT,
      })),
    }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'Patient journey data is unavailable. Verify the core deployment and application role.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}
