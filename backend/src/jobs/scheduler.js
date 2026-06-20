import cron from 'node-cron';
import { logger } from '../config/logger.js';
import { runWeatherSync } from './weatherSync.js';
import { runMandiSync } from './mandiSync.js';
import { runSchemeSync } from './schemeSync.js';
import { sweepAllMovements } from '../services/priceTracker.js';
import { matchAllFarmers } from '../services/schemeMatcher.js';
import { sendBatch } from '../services/alerts.js';

// Replaces db/plsql/jobs.sql (DBMS_SCHEDULER). Gated by ENABLE_JOBS so only one
// instance runs them. All times are server-local; deploy with TZ=Asia/Kolkata
// to match the original IST schedule.

const tasks = [];

function schedule(name, expr, fn) {
  const task = cron.schedule(
    expr,
    async () => {
      try {
        logger.info({ job: name }, 'job started');
        await fn();
      } catch (err) {
        logger.error({ err, job: name }, 'job failed');
      }
    },
    { scheduled: true },
  );
  tasks.push(task);
}

export function startScheduler() {
  schedule('weatherSync', '0 */6 * * *', runWeatherSync); // every 6 hours
  schedule('mandiSync', '0 6 * * *', () => runMandiSync()); // daily 06:00
  schedule('schemeSync', '0 3 * * 1', runSchemeSync); // weekly Mon 03:00
  schedule('schemeMatch', '0 1 * * *', matchAllFarmers); // daily 01:00
  schedule('priceSweep', '30 6 * * *', sweepAllMovements); // daily 06:30
  schedule('alertDispatch', '*/15 * * * *', () => sendBatch({ channel: 'EMAIL' })); // every 15m
  logger.info({ jobs: tasks.length }, 'Cron scheduler started');
}

export function stopScheduler() {
  for (const t of tasks) t.stop();
  tasks.length = 0;
}
