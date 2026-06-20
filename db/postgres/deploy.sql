-- =============================================================================
-- KrishiMitra :: PostgreSQL master deploy (psql)
-- Usage:
--   psql "$DATABASE_URL" -f db/postgres/deploy.sql
-- (In the Supabase SQL editor, run 01 -> 02 -> 03 -> 04 in order instead.)
-- =============================================================================
\i 01_schema.sql
\i 02_indexes.sql
\i 03_triggers.sql
\i 04_seed.sql
