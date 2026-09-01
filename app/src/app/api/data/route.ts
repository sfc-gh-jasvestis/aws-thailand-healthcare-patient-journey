import { NextResponse } from 'next/server';
import { executeQuery } from '@/lib/snowflake';

// Always hit Snowflake - never serve a cached build-time response.
export const dynamic = 'force-dynamic';
export const revalidate = 0;

/**
 * This demo has a bespoke curated model (CURATED.HOSPITAL_PERFORMANCE), not the
 * generic PERFORMANCE_SUMMARY / TREND_ANALYSIS pair used by most SEA demos, so
 * it needs its own route. Keys returned match what page.tsx binds to.
 */
export async function GET() {
  try {
    const [kpiRows, trendRows, regionRows, detailRows, typeRows, entityRows] = await Promise.all([
      executeQuery<Record<string, number>>(`
        SELECT COUNT(DISTINCT HOSPITAL_ID)     AS TOTAL_HOSPITALS,
               SUM(TOTAL_ENCOUNTERS)           AS TOTAL_ENCOUNTERS,
               SUM(ED_VISITS)                  AS TOTAL_ED_VISITS,
               SUM(ADMISSIONS)                 AS TOTAL_ADMISSIONS,
               ROUND(AVG(AVG_WAIT_MINS), 1)    AS AVG_WAIT_MINS,
               ROUND(AVG(ED_AVG_WAIT_MINS), 1) AS AVG_ED_WAIT_MINS,
               ROUND(AVG(AVG_LOS_HOURS), 1)    AS AVG_LOS_HOURS,
               ROUND(AVG(LWBS_RATE_PCT), 2)    AS AVG_LWBS_RATE,
               ROUND(AVG(ACUITY_HIGH_PCT), 1)  AS AVG_ACUITY_HIGH
        FROM CURATED.HOSPITAL_PERFORMANCE
      `),

      executeQuery<{ PERIOD: string; VALUE: number }>(`
        SELECT TO_CHAR(METRIC_DATE, 'Mon DD') AS PERIOD,
               ROUND(AVG(AVG_WAIT_MINS), 1)   AS VALUE
        FROM CURATED.HOSPITAL_PERFORMANCE
        GROUP BY METRIC_DATE
        ORDER BY METRIC_DATE
      `),

      executeQuery<{ CATEGORY: string; COUNT: number }>(`
        SELECT REGION AS CATEGORY, ROUND(AVG(AVG_WAIT_MINS), 1) AS COUNT
        FROM CURATED.HOSPITAL_PERFORMANCE
        GROUP BY REGION
        ORDER BY COUNT DESC
      `),

      executeQuery<{ X: string; Y: number }>(`
        SELECT TO_CHAR(METRIC_DATE, 'Dy DD') AS X,
               ROUND(AVG(ED_AVG_WAIT_MINS), 1) AS Y
        FROM CURATED.HOSPITAL_PERFORMANCE
        WHERE METRIC_DATE >= DATEADD('day', -7, (SELECT MAX(METRIC_DATE) FROM CURATED.HOSPITAL_PERFORMANCE))
        GROUP BY METRIC_DATE
        ORDER BY METRIC_DATE
      `),

      // Public vs private is the real insight in this dataset.
      executeQuery<{ LABEL: string; VALUE: number }>(`
        SELECT HOSPITAL_TYPE AS LABEL, SUM(TOTAL_ENCOUNTERS) AS VALUE
        FROM CURATED.HOSPITAL_PERFORMANCE
        GROUP BY HOSPITAL_TYPE
        ORDER BY VALUE DESC
      `),

      executeQuery<{ ID: string; NAME: string; REGION: string; HOSPITAL_TYPE: string; VALUE: number; LWBS: number }>(`
        SELECT HOSPITAL_ID AS ID, HOSPITAL_NAME AS NAME, REGION, HOSPITAL_TYPE,
               ROUND(AVG(AVG_WAIT_MINS), 1) AS VALUE,
               ROUND(AVG(LWBS_RATE_PCT), 2) AS LWBS
        FROM CURATED.HOSPITAL_PERFORMANCE
        GROUP BY HOSPITAL_ID, HOSPITAL_NAME, REGION, HOSPITAL_TYPE
        ORDER BY VALUE DESC
      `),
    ]);

    const k = kpiRows[0] || {};

    return NextResponse.json({
      kpis: k,
      // Ordered to match the KPI cards rendered in page.tsx.
      kpiCards: [
        { title: 'Avg Wait Time', value: `${k.AVG_WAIT_MINS ?? '—'} min`, status: 'danger' },
        { title: 'ED Avg Wait', value: `${k.AVG_ED_WAIT_MINS ?? '—'} min`, status: 'danger' },
        { title: 'Avg Length of Stay', value: `${k.AVG_LOS_HOURS ?? '—'} hrs`, status: 'neutral' },
        { title: 'Total Encounters', value: Number(k.TOTAL_ENCOUNTERS || 0).toLocaleString(), status: 'neutral' },
        { title: 'LWBS Rate', value: `${k.AVG_LWBS_RATE ?? '—'}%`, status: 'warning' },
        { title: 'High Acuity', value: `${k.AVG_ACUITY_HIGH ?? '—'}%`, status: 'neutral' },
        { title: 'Hospitals Monitored', value: String(k.TOTAL_HOSPITALS ?? '—'), status: 'neutral' },
      ],
      timeseries: trendRows.map((r) => ({ period: r.PERIOD, value: Number(r.VALUE) })),
      categories: regionRows.map((r) => ({ category: r.CATEGORY, count: Number(r.COUNT) })),
      detail: detailRows.map((r) => ({ x: r.X, y: Number(r.Y) })),
      breakdown: typeRows.map((r) => ({ label: r.LABEL, value: Number(r.VALUE) })),
      entities: entityRows.map((r) => {
        const wait = Number(r.VALUE) || 0;
        return {
          id: r.ID,
          name: r.NAME,
          region: r.REGION,
          type: r.HOSPITAL_TYPE,
          // Thai public tertiary waits run far longer than private; band accordingly.
          status: wait > 240 ? 'Critical' : wait > 120 ? 'Watch' : 'Healthy',
          value: wait,
          lwbs: Number(r.LWBS),
        };
      }),
      updatedAt: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Data fetch error:', error);
    return NextResponse.json(
      { error: 'Failed to fetch data', details: String(error) },
      { status: 500 }
    );
  }
}
