import { Router } from 'express';
import { asyncHandler } from '../middleware/error.js';
import { rows } from '../db/pool.js';

const router = Router();

// GET /crops -> crop master list
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const cropType = req.query.crop_type || null;
    const items = await rows(
      `SELECT crop_id, crop_name, crop_name_hindi, category, crop_type,
              avg_grow_days, water_need_mm, ideal_temp_min, ideal_temp_max,
              ideal_soil_types
       FROM crops
       WHERE ($1::text IS NULL OR crop_type = $1)
       ORDER BY crop_name`,
      [cropType],
    );
    res.json({ items });
  }),
);

export default router;
