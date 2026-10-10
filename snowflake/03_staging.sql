-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.DESK_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.DESK_DAILY observation
    LEFT JOIN RAW.DESKS desk ON desk.ID = observation.ENTITY_ID
    WHERE desk.ID IS NULL OR observation.BOOKING_COUNT < 0
       OR observation.BOOKING_VALUE_THB < 0
       OR observation.CANCELLED_COUNT < 0 OR observation.CANCELLED_COUNT > observation.ISSUE_COUNT
       OR observation.ISSUE_COUNT > observation.BOOKING_COUNT
       OR observation.LATE_ARRIVAL > observation.CANCELLED_COUNT
       OR observation.CHECKLIST_AUDIT_DONE > observation.CHECKLIST_AUDIT_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
