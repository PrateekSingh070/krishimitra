# INT-01 :: Weather Sync

| | |
|---|---|
| **Type** | Scheduled Orchestration |
| **Trigger** | Every 6 hours (`FREQ=HOURLY;INTERVAL=6`) |
| **Connections** | `OWM_REST` (invoke), `ATP_DB` (invoke) |
| **Target table** | `WEATHER_DATA` |

## Flow

```
Schedule (every 6h)
   -> Stage: read district list (ATP: SELECT DISTINCT district, state FROM farmers WHERE is_active='Y')
   -> For-Each district:
        -> Invoke OWM_REST GET /data/2.5/forecast?q={district},IN&appid={key}&units=metric
        -> Map response -> WEATHER_DATA row (see mappings/INT-01_weather.json)
        -> Invoke ATP_DB INSERT INTO WEATHER_DATA (...)
   -> On fault (scope handler): log + continue to next district
```

## Error handling
- REST invoke wrapped in a scope with a fault handler: non-200 / timeout is
  logged (OIC activity stream) and the loop continues (one bad district must not
  fail the whole run).
- ATP insert failures are retried once, then skipped.

## Notes
- `forecast_json` stores the raw 7-day forecast JSON for downstream alert rules.
- `source` is set to `OWM` (or `IMD` for the IMD variant of this integration).
- Mirrors the DB-side `JOB_WEATHER_SYNC` scheduler job, which can call this
  integration's exposed REST endpoint instead of holding its own schedule.
