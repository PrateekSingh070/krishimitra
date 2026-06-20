import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../middleware/error.js';
import { validate } from '../middleware/validate.js';
import { listActiveSchemes, listFarmerMatches, matchFarmer } from '../services/schemeMatcher.js';

const router = Router();

const farmerIdSchema = z.object({ farmerId: z.coerce.number().int().positive() });

// GET /schemes -> all active schemes
router.get(
  '/',
  asyncHandler(async (_req, res) => {
    res.json({ items: await listActiveSchemes() });
  }),
);

// GET /schemes/farmer/:farmerId -> personalised, ranked matches
router.get(
  '/farmer/:farmerId',
  validate(farmerIdSchema, 'params'),
  asyncHandler(async (req, res) => {
    res.json({ items: await listFarmerMatches(req.params.farmerId) });
  }),
);

// POST /schemes/farmer/:farmerId/match -> recompute matches on demand
router.post(
  '/farmer/:farmerId/match',
  validate(farmerIdSchema, 'params'),
  asyncHandler(async (req, res) => {
    const count = await matchFarmer(req.params.farmerId);
    res.json({ matched: count });
  }),
);

export default router;
