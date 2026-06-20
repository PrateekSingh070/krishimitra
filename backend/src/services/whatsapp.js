import { config } from '../config/index.js';
import { logger } from '../config/logger.js';

// WhatsApp Cloud API (Meta) — free tier, 1000 conversations/month.
// Requires: META_WHATSAPP_TOKEN, META_WHATSAPP_PHONE_ID
// Template must be pre-approved in Meta Business Manager.
// Docs: https://developers.facebook.com/docs/whatsapp/cloud-api

export async function sendWhatsAppAlert(phone, messageEn) {
  const token = config.whatsapp.token;
  const phoneId = config.whatsapp.phoneId;

  if (!token || !phoneId) {
    logger.warn({ phone }, 'WhatsApp not configured — skipping');
    return false;
  }

  // Normalise Indian phone to E.164 (+91XXXXXXXXXX)
  const e164 = phone.replace(/\D/g, '').replace(/^0/, '');
  const to = e164.startsWith('91') ? e164 : `91${e164}`;

  const body = {
    messaging_product: 'whatsapp',
    to,
    type: 'text',
    text: { body: messageEn },
  };

  try {
    const resp = await fetch(
      `https://graph.facebook.com/v19.0/${phoneId}/messages`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      },
    );
    const json = await resp.json();
    if (!resp.ok) {
      logger.error({ phone, json }, 'WhatsApp send failed');
      return false;
    }
    logger.info({ phone, id: json.messages?.[0]?.id }, 'WhatsApp message sent');
    return true;
  } catch (err) {
    logger.error({ err, phone }, 'WhatsApp request error');
    return false;
  }
}
