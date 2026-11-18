-- Runs once, only when the data directory is first initialised.
-- pg_stat_statements is NOT created here: it needs the library preloaded,
-- which is not the case for the temporary server used during init.
-- It is created by scripts/enable-extensions.sh once the real server is up.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
