# KrishiMitra :: Oracle Integration Cloud (OIC) — OPTIONAL / LEGACY

> **Not the default path.** OIC is a paid service. On the free default path these
> four integrations are replaced by native, ATP-side PL/SQL packages driven by
> `DBMS_SCHEDULER` (no OIC required):
>
> | OIC integration | Free replacement |
> |-----------------|------------------|
> | INT-01 Weather Sync | `db/plsql/pkg_weather_sync` (Open-Meteo, keyless) |
> | INT-02 Mandi Price Sync | `db/plsql/pkg_mandi_sync` (Agmarknet/data.gov.in) |
> | INT-03 Scheme Data Sync | `db/plsql/pkg_scheme_sync` (data.gov.in) |
> | INT-04 SMS Notification | `db/plsql/pkg_notify` (email) + in-app; SMS optional |
>
> The specs below are kept so you can reproduce the integrations in OIC if you
> later choose the paid path. See `FREE-TIER.md` for the full mapping.

Four integrations connect KrishiMitra to external data sources and SMS delivery.
OIC integrations are authored in the OIC visual designer and exported as binary
`.iar` archives, which cannot be hand-written in source control. This folder
therefore contains, per integration:

- a **design spec** (`INT-0x_*.md`) — trigger, adapters, flow, error handling;
- a **sample source payload** (`payloads/`) — what the external API returns;
- a **field mapping** (`mappings/`) — source -> `ATP` table columns;

so the integration can be reproduced 1:1 in the OIC designer, and the same
mappings can be reused by the alternative Node/Function ingestion paths.

| ID | Integration | Trigger | Source -> Target |
|----|-------------|---------|------------------|
| INT-01 | Weather Sync | Schedule, every 6h | OpenWeatherMap/IMD -> `WEATHER_DATA` |
| INT-02 | Mandi Price Sync | Schedule, daily 06:00 IST | Agmarknet (data.gov.in) -> `MANDI_PRICES` |
| INT-03 | Scheme Data Sync | Schedule, weekly Sun 02:00 IST | data.gov.in -> `GOVERNMENT_SCHEMES` |
| INT-04 | Farmer SMS Notification | Event (Streaming consumer) | `krishimitra-alerts-stream` -> Fast2SMS -> `ALERTS` update |

## Connections (configured once in OIC)

| Connection | Adapter | Notes |
|------------|---------|-------|
| `OWM_REST` | REST | OpenWeatherMap; API key from OIC connection security (Vault-backed) |
| `AGMARKNET_REST` | REST | data.gov.in resource API; api-key as query param from Vault |
| `DATAGOV_REST` | REST | PM-KISAN / eNAM scheme resources |
| `ATP_DB` | Oracle Autonomous DB | mTLS wallet; service `krishimitradb_high` |
| `ALERTS_STREAM` | OCI Streaming | consumer group `oic-sms` |
| `FAST2SMS_REST` | REST | bulk SMS; auth key from Vault |

No secrets are stored in this repo; all credentials live in OIC connection
security properties backed by OCI Vault.
