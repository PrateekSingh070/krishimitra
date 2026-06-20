# INT-04 :: Farmer SMS Notification

| | |
|---|---|
| **Type** | Event-triggered (OCI Streaming consumer) |
| **Trigger** | New message on `krishimitra-alerts-stream` |
| **Connections** | `ALERTS_STREAM` (trigger), `ATP_DB` (invoke), `FAST2SMS_REST` (invoke) |
| **Target** | Fast2SMS bulk SMS + `ALERTS` update |

## Flow

```
Trigger: ALERTS_STREAM consume (consumer group 'oic-sms')
   -> Parse event { rule_id, params: { district, crop?, mandi? } }
   -> Render bilingual message from template (same templates as alert-dispatcher)
   -> ATP_DB SELECT farmer_id, phone FROM farmers WHERE district=:d AND is_active='Y'
   -> ATP_DB batch INSERT INTO alerts (...)               -- is_sent='N'
   -> For-Each batch of <=1000 phones:
        -> Invoke FAST2SMS_REST POST /dev/bulkV2 (route=q, language=unicode)
        -> ATP_DB UPDATE alerts SET is_sent='Y', sent_at=SYSTIMESTAMP WHERE alert_id IN (...)
```

## Error handling
- Fast2SMS non-200 -> the batch's alerts remain `is_sent='N'` and are retried on
  the next poll; the message is re-queued (no commit-on-get for failed batches).
- This integration is functionally equivalent to the `alert-dispatcher` OCI
  Function; choose one as the primary dispatcher and keep the other as a
  documented alternative. Both honour the 1000-recipients/call batch limit.

## Notes
- The DB-side `PKG_ALERTS.send_batch` covers the same "mark sent" semantics for
  alerts created by triggers (e.g. disease) rather than by stream events.
