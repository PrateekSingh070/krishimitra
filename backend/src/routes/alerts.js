import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/error.js';
import { validate } from '../middleware/validate.js';
import { requireRole } from '../middleware/auth.js';
import { listAlerts, sendBatch, generateAlert, CHANNEL } from '../services/alerts.js';

const router = Router();

// GET /alerts?farmer_id=  -> alert history (newest first)
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const farmerId = req.query.farmer_id ? Number(req.query.farmer_id) : null;
    res.json({ items: await listAlerts(farmerId) });
  }),
);

const createAlertSchema = z.object({
  farmer_id: z.number().int().positive(),
  alert_type: z.string().max(30).default('ADMIN'),
  severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).default('LOW'),
  message_en: z.string().max(2000),
  message_hi: z.string().max(2000).optional(),
});

// POST /alerts  -> create a single alert (admin)
router.post(
  '/',
  requireRole('admin'),
  validate(createAlertSchema),
  asyncHandler(async (req, res) => {
    const { farmer_id, alert_type, severity, message_en, message_hi } = req.body;
    await generateAlert({
      farmerId: farmer_id,
      alertType: alert_type,
      severity,
      messageEn: message_en,
      messageHi: message_hi || message_en,
    });
    res.status(201).json({ ok: true });
  }),
);

const dispatchSchema = z.object({
  channel: z.enum(['SMS', 'EMAIL', 'APP']).default('EMAIL'),
  batch_size: z.number().int().positive().max(5000).default(1000),
});

// POST /alerts/dispatch  -> deliver pending alerts (admin/ops only)
router.post(
  '/dispatch',
  requireRole('admin'),
  validate(dispatchSchema),
  asyncHandler(async (req, res) => {
    const dispatched = await sendBatch({
      channel: req.body.channel ?? CHANNEL.EMAIL,
      batchSize: req.body.batch_size,
    });
    res.json({ dispatched });
  }),
);

export default router;
