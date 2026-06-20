import dns from 'node:dns';
// Prefer IPv4 for all outbound connections (SMTP relay, Supabase). Some networks
// route IPv6 (AAAA) poorly, causing ETIMEDOUT to smtp.gmail.com / Supabase.
dns.setDefaultResultOrder('ipv4first');

import { createApp } from './app.js';
import { config, assertConfig } from './config/index.js';
import { logger } from './config/logger.js';
import { initPool, closePool } from './db/pool.js';
import { startScheduler, stopScheduler } from './jobs/scheduler.js';

async function main() {
  assertConfig();
  await initPool();

  // Ingestion + dispatch cron jobs (weather/mandi/scheme/alerts). Gated by
  // ENABLE_JOBS so a second instance / read replica doesn't double-run them.
  if (config.ingest.enableJobs) {
    startScheduler();
  }

  const app = createApp();
  const server = app.listen(config.port, () => {
    logger.info(`KrishiMitra API listening on :${config.port} (${config.env})`);
  });

  const shutdown = async (signal) => {
    logger.info(`${signal} received, shutting down`);
    stopScheduler();
    server.close(async () => {
      await closePool();
      process.exit(0);
    });
    // Force-exit if graceful shutdown stalls.
    setTimeout(() => process.exit(1), 10000).unref();
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

main().catch((err) => {
  logger.error({ err }, 'Fatal startup error');
  process.exit(1);
});
