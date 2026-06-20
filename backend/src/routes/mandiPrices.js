import { Router } from 'express';
import { asyncHandler } from '../middleware/error.js';
import { latestPrices, priceHistory } from '../services/priceTracker.js';

const router = Router();

// GET /mandi-prices?crop_id=&mandi=  -> latest price per crop+mandi
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const cropId = req.query.crop_id ? Number(req.query.crop_id) : null;
    const mandi = req.query.mandi || null;
    res.json({ items: await latestPrices(cropId, mandi) });
  }),
);

// GET /mandi-prices/history?crop_id=&mandi=&days=  -> time series for charts
router.get(
  '/history',
  asyncHandler(async (req, res) => {
    const cropId = req.query.crop_id ? Number(req.query.crop_id) : null;
    const mandi = req.query.mandi || null;
    const days = req.query.days ? Number(req.query.days) : 90;
    res.json({ items: await priceHistory(cropId, mandi, days) });
  }),
);

export default router;
