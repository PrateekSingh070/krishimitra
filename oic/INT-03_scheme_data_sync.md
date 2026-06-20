# INT-03 :: Scheme Data Sync

| | |
|---|---|
| **Type** | Scheduled Orchestration |
| **Trigger** | Weekly, Sunday 02:00 IST |
| **Connections** | `DATAGOV_REST` (invoke), `ATP_DB` (invoke) |
| **Target table** | `GOVERNMENT_SCHEMES` |

## Flow

```
Schedule (weekly Sun 02:00 IST)
   -> Invoke DATAGOV_REST GET /resource/{pmkisan_resource}?api-key={key}&format=json
   -> Invoke DATAGOV_REST GET /resource/{enam_resource}?api-key={key}&format=json
   -> Filter: active schemes only
   -> Map -> GOVERNMENT_SCHEMES (mappings/INT-03_scheme.json)
   -> For-Each scheme:
        -> ATP_DB MERGE (upsert) ON scheme_name
   -> ATP_DB UPDATE government_schemes SET is_active='N' WHERE deadline < SYSDATE
```

## Error handling
- Per-scheme upsert faults are logged and skipped; the run continues.
- A summary (inserted / updated / deactivated counts) is logged to the OIC
  activity stream.

## Notes
- `eligibility_json` is built from the source fields (min/max land, states,
  crops, income) into the JSON shape consumed by `PKG_SCHEME_MATCHER`.
- Auto-deactivation of past-deadline schemes happens at the end of the run.
