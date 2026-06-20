# INT-02 :: Mandi Price Sync

| | |
|---|---|
| **Type** | Scheduled Orchestration |
| **Trigger** | Daily 06:00 IST |
| **Connections** | `AGMARKNET_REST` (invoke), `ATP_DB` (invoke), `ALERTS_STREAM` (invoke, error path) |
| **Target table** | `MANDI_PRICES` |

## Flow

```
Schedule (daily 06:00 IST)
   -> Invoke AGMARKNET_REST GET /resource/{resource_id}?api-key={key}&format=json
        &filters[commodity]=...&limit=1000   (top 20 crops x 50 mandis)
   -> Map records -> MANDI_PRICES rows (mappings/INT-02_mandi.json)
   -> For-Each record:
        -> Resolve crop_id (ATP lookup by crop_name; skip unknown crops)
        -> Invoke ATP_DB INSERT INTO MANDI_PRICES (...)
        -> On insert fault: publish record to ALERTS_STREAM (dead-letter)
```

## Error handling
- **Dead-letter queue:** failed inserts are published to OCI Streaming
  (`krishimitra-alerts-stream`, key `mandi-dlq`) for later replay, per the spec.
- Unknown commodities (no matching `crops.crop_name`) are counted and logged,
  not failed.

## Notes
- After load, the DB job `JOB_PRICE_ALERT_SWEEP` (06:30 IST) re-evaluates
  `PKG_PRICE_TRACKER` rules; alternatively this integration can call
  `PKG_PRICE_TRACKER.record_price` which evaluates inline.
- `source` = `Agmarknet`.
