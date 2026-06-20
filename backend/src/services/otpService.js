import crypto from 'node:crypto';
import { config } from '../config/index.js';
import { logger } from '../config/logger.js';

// In-memory OTP store: phone -> { otp, expiresAt, attempts }
// Works fine for a single Render instance. Replace with Redis for multi-instance.
const store = new Map();

const OTP_TTL_MS = 5 * 60 * 1000; // 5 minutes
const MAX_ATTEMPTS = 5;

export function generateOtp() {
  return String(crypto.randomInt(100000, 999999));
}

export function storeOtp(phone, otp) {
  store.set(phone, {
    otp,
    expiresAt: Date.now() + OTP_TTL_MS,
    attempts: 0,
  });
}

export function verifyOtp(phone, otp) {
  const entry = store.get(phone);
  if (!entry) return { ok: false, reason: 'no_otp' };
  if (Date.now() > entry.expiresAt) {
    store.delete(phone);
    return { ok: false, reason: 'expired' };
  }
  entry.attempts += 1;
  if (entry.attempts > MAX_ATTEMPTS) {
    store.delete(phone);
    return { ok: false, reason: 'too_many_attempts' };
  }
  if (entry.otp !== String(otp)) return { ok: false, reason: 'wrong_otp' };
  store.delete(phone);
  return { ok: true };
}

// Send OTP via Fast2SMS (free, India-only).
// Falls back to console log when FAST2SMS_API_KEY is not set (dev mode).
export async function sendOtpSms(phone, otp) {
  const key = config.sms.fast2smsKey;

  if (!key) {
    logger.warn({ phone }, `[DEV] OTP for ${phone}: ${otp}`);
    return true;
  }

  const url = 'https://www.fast2sms.com/dev/bulkV2';
  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      authorization: key,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      route: 'otp',
      variables_values: otp,
      flash: 0,
      numbers: phone,
    }),
  });

  const json = await resp.json();
  if (!json.return) {
    // SMS failed (e.g. Fast2SMS website verification pending).
    // Fall back to log so OTP is still accessible during setup.
    logger.error({ phone, json }, 'Fast2SMS delivery failed — falling back to log');
    logger.warn({ phone }, `[FALLBACK] OTP for ${phone}: ${otp}`);
    return false;
  }
  return true;
}
