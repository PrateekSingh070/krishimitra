import nodemailer from 'nodemailer';
import { config } from '../config/index.js';
import { logger } from '../config/logger.js';
import { one } from '../db/pool.js';

// Port of db/plsql/pkg_notify.pkb. Email via a free SMTP relay (nodemailer);
// the in-app alert is the ALERTS row itself. If SMTP is unconfigured, email is
// skipped silently so the in-app alert remains the source of truth.

let transporter = null;

function getTransporter() {
  if (!config.smtp.host) return null;
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: config.smtp.host,
      port: config.smtp.port,
      secure: config.smtp.secure, // true for 465, false for 587 (STARTTLS)
      auth: config.smtp.user ? { user: config.smtp.user, pass: config.smtp.password } : undefined,
    });
  }
  return transporter;
}

// Look up a farmer's email address (null when missing / unknown).
export async function farmerEmail(farmerId) {
  const row = await one('SELECT email FROM farmers WHERE farmer_id = $1', [farmerId]);
  return row ? row.email : null;
}

// Send a plain-text email. Returns true if accepted by the relay (or skipped
// because SMTP is not configured); throws on a genuine send failure so the
// caller can leave the alert unsent for retry.
export async function sendEmail({ to, subject, body }) {
  const tx = getTransporter();
  if (!to || !tx || !config.smtp.sender) {
    return false; // not configured / no recipient -> rely on in-app alert
  }
  await tx.sendMail({
    from: config.smtp.sender,
    to,
    subject,
    text: body,
  });
  logger.debug({ to }, 'Alert email sent');
  return true;
}
