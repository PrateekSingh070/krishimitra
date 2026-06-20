import pg from 'pg';
import { config } from '../config/index.js';
import { logger } from '../config/logger.js';

// PostgreSQL (Supabase) connection pool. Replaces the previous node-oracledb
// pool. Supabase requires TLS; `ssl.rejectUnauthorized=false` is the documented
// setting for the pooled connection string from managed providers.
const { Pool } = pg;

let pool = null;

export function getPool() {
  if (!pool) {
    throw new Error('Database pool not initialised. Call initPool() first.');
  }
  return pool;
}

export async function initPool() {
  if (pool) return pool;

  pool = new Pool({
    connectionString: config.db.url,
    max: config.db.poolMax,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
    ssl: config.db.ssl ? { rejectUnauthorized: false } : undefined,
  });

  pool.on('error', (err) => {
    logger.error({ err }, 'Unexpected idle PostgreSQL client error');
  });

  // Fail fast if the connection string is wrong.
  const client = await pool.connect();
  client.release();
  logger.info('PostgreSQL connection pool created');
  return pool;
}

export async function closePool() {
  if (!pool) return;
  try {
    await pool.end();
    pool = null;
    logger.info('PostgreSQL connection pool closed');
  } catch (err) {
    logger.error({ err }, 'Error closing PostgreSQL pool');
  }
}

// Run a parameterized query ($1, $2, ...). Returns the pg result object.
export async function query(text, params = []) {
  return getPool().query(text, params);
}

// Convenience: run a query and return rows only.
export async function rows(text, params = []) {
  const res = await getPool().query(text, params);
  return res.rows;
}

// Convenience: run a query and return the first row (or undefined).
export async function one(text, params = []) {
  const res = await getPool().query(text, params);
  return res.rows[0];
}

// Run fn(client) inside a transaction; commit on success, rollback on error.
export async function withTransaction(fn) {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackErr) {
      logger.error({ err: rollbackErr }, 'Error rolling back transaction');
    }
    throw err;
  } finally {
    client.release();
  }
}
