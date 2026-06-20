import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/error.js';
import { validate } from '../middleware/validate.js';
import { rows } from '../db/pool.js';

const router = Router();

const idSchema = z.object({ farmerCropId: z.coerce.number().int().positive() });

// GET /recommendations/:farmerCropId -> stored ML predictions for a planting.
// Predictions are populated into ML_PREDICTIONS by the notebooks in ml/ (or an
// optional Python sidecar; see ml/README.md). This endpoint surfaces them.
router.get(
  '/:farmerCropId',
  validate(idSchema, 'params'),
  asyncHandler(async (req, res) => {
    const items = await rows(
      `SELECT prediction_id, farmer_crop_id, model_type, predicted_value,
              unit, confidence_pct, prediction_date, model_version
       FROM ml_predictions
       WHERE farmer_crop_id = $1
       ORDER BY prediction_date DESC`,
      [req.params.farmerCropId],
    );
    res.json({ items });
  }),
);

export default router;
