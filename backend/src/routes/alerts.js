import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/error.js';
import { validate } from '../middleware/validate.js';
import { requireRole } from '../middleware/auth.js';
import { listAlerts, sendBatch, CHANNEL } from '../services/alerts.js';

const router = Router();

// GET /alerts?farmer_id=  -> alert history (newest first)
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const farmerId = req.query.farmer_id ? Number(req.query.farmer_id) : null;
    res.json({ items: await listAlerts(farmerId) });
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
