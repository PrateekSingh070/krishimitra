import { query, one, rows, withTransaction } from '../db/pool.js';
import { farmerEmail, sendEmail } from './notify.js';

// Port of db/plsql/pkg_alerts.{pks,pkb}.
// Default channel EMAIL (free). 'APP' = in-app only. 'SMS' is the optional paid
// path (not handled here). Alerts are rows in ALERTS; sendBatch delivers email
// + in-app and marks rows sent only on success.

export const SEVERITY = { LOW: 'LOW', MEDIUM: 'MEDIUM', HIGH: 'HIGH', CRITICAL: 'CRITICAL' };
export const CHANNEL = { SMS: 'SMS', EMAIL: 'EMAIL', APP: 'APP' };

// Create a single alert row (is_sent='N'); returns the new alert_id.
export async function generateAlert({
  alertType,
  farmerId,
  messageEn,
  messageHi,
  severity,
  channel = CHANNEL.EMAIL,
  client = null,
}) {
  const text = `INSERT INTO alerts (alert_type, farmer_id, message_en, message_hi, severity, is_sent, channel)
                VALUES ($1, $2, $3, $4, $5, 'N', $6) RETURNING alert_id`;
  const params = [alertType, farmerId, messageEn, messageHi, severity, channel];
  const res = client ? await client.query(text, params) : await query(text, params);
  return res.rows[0].alert_id;
}

// Fan an alert out to every active farmer in a district. Returns count inserted.
export async function generateAlertForDistrict({
  alertType,
  district,
  messageEn,
  messageHi,
  severity,
  channel = CHANNEL.EMAIL,
  client = null,
}) {
  const text = `INSERT INTO alerts (alert_type, farmer_id, message_en, message_hi, severity, is_sent, channel)
                SELECT $1, f.farmer_id, $2, $3, $4, 'N', $5
                FROM farmers f
                WHERE f.district = $6 AND f.is_active = 'Y'`;
  const params = [alertType, messageEn, messageHi, severity, channel, district];
  const res = client ? await client.query(text, params) : await query(text, params);
  return res.rowCount;
}

// Deliver one alert. EMAIL -> nodemailer; APP -> in-app only (always delivered);
// SMS -> not handled in the free path (returns false). Returns true when the
// alert can be marked sent.
async function deliverAlert(alert) {
  if (alert.channel === CHANNEL.EMAIL) {
    const email = await farmerEmail(alert.farmer_id);
    if (!email) return true; // no address -> in-app only still counts as delivered
    const subject = `KrishiMitra Alert [${alert.severity}]`;
    const body = `${alert.message_hi || ''}\n\n${alert.message_en || ''}`;
    return sendEmail({ to: email, subject, body });
  }
  if (alert.channel === CHANNEL.APP) {
    return true; // in-app only
  }
  return false; // SMS (optional/paid)
}

// Batch-dispatch pending alerts for a channel. Marks rows sent only on success.
// Returns the number marked sent.
export async function sendBatch({ channel = CHANNEL.EMAIL, batchSize = 1000 } = {}) {
  let total = 0;
  // Loop in commit-sized batches; SKIP LOCKED lets multiple workers parallelise.
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const sentIds = await withTransaction(async (client) => {
      const pending = await client.query(
        `SELECT alert_id, farmer_id, severity, message_en, message_hi, channel
         FROM alerts
         WHERE is_sent = 'N' AND channel = $1
         ORDER BY severity, created_at
         LIMIT $2
         FOR UPDATE SKIP LOCKED`,
        [channel, batchSize],
      );
      if (pending.rows.length === 0) return [];

      const delivered = [];
      for (const alert of pending.rows) {
        // eslint-disable-next-line no-await-in-loop
        const ok = await deliverAlert(alert).catch(() => false);
        if (ok) delivered.push(alert.alert_id);
      }
      if (delivered.length > 0) {
        await client.query(
          `UPDATE alerts SET is_sent = 'Y', sent_at = now()
           WHERE alert_id = ANY($1::bigint[])`,
          [delivered],
        );
      }
      return delivered;
    });

    if (sentIds.length === 0) break;
    total += sentIds.length;
    // If a full batch produced no deliverable rows we'd loop forever; the
    // FOR UPDATE SKIP LOCKED + is_sent flip guarantees progress, but guard
    // anyway by breaking when fewer than batchSize rows were processed.
    if (sentIds.length < batchSize) break;
  }
  return total;
}

// Alert history (newest first), optionally filtered by farmer.
export async function listAlerts(farmerId = null) {
  return rows(
    `SELECT alert_id, alert_type, farmer_id, message_en, message_hi,
            severity, is_sent, sent_at, channel, created_at
     FROM alerts
     WHERE ($1::bigint IS NULL OR farmer_id = $1)
     ORDER BY created_at DESC
     LIMIT 100`,
    [farmerId],
  );
}
