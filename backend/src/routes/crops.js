import { Router } from 'express';
import { asyncHandler } from '../middleware/error.js';
import { rows } from '../db/pool.js';

const router = Router();

// GET /crops -> crop master list
router.get(
  '/',
  asyncHandler(async (_req, res) => {
    const items = await rows(
      `SELECT crop_id, crop_name, crop_name_hindi, category,
              avg_grow_days, water_need_mm, ideal_temp_min, ideal_temp_max,
              ideal_soil_types
       FROM crops
       ORDER BY crop_name`,
    );
    res.json({ items });
  }),
);

export default router;
