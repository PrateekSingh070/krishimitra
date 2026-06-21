import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, ApiError } from '../middleware/error.js';
import { validate } from '../middleware/validate.js';
import {
  registerFarmer,
  updateFarmer,
  getFarmer,
  deactivateFarmer,
} from '../services/farmerService.js';

const router = Router();

const SOIL_TYPES = ['Sandy', 'Loamy', 'Clay', 'Black', 'Silt', 'Peaty', 'Chalky'];

const registerSchema = z.object({
  name: z.string().min(1).max(100),
  phone: z.string().regex(/^[0-9]{10,15}$/, 'phone must be 10-15 digits'),
  pin: z.string().regex(/^[0-9]{4,6}$/, 'PIN must be 4-6 digits').optional(),
  email: z.string().email().max(150).optional(),
  // Raw Aadhaar is accepted over TLS, hashed in the app, and never persisted raw.
  aadhaar: z.string().regex(/^[0-9]{12}$/).optional(),
  state: z.string().max(50).optional(),
  district: z.string().max(50).optional(),
  village: z.string().max(100).optional(),
  land_acres: z.number().nonnegative().optional(),
  soil_type: z.enum(SOIL_TYPES).optional(),
  preferred_lang: z.enum(['hi', 'en']).optional(),
});

const updateSchema = registerSchema.partial().omit({ phone: true, pin: true, aadhaar: true });

const idSchema = z.object({ id: z.coerce.number().int().positive() });

// POST /farmers
router.post(
  '/',
  validate(registerSchema),
  asyncHandler(async (req, res) => {
    const farmerId = await registerFarmer(req.body);
    res.status(201).json({ farmer_id: farmerId });
  }),
);

// GET /farmers/:id
router.get(
  '/:id',
  validate(idSchema, 'params'),
  asyncHandler(async (req, res) => {
    const row = await getFarmer(req.params.id);
    if (!row) throw new ApiError(404, 'Farmer not found');
    res.json(row);
  }),
);

// PATCH /farmers/:id
router.patch(
  '/:id',
  validate(idSchema, 'params'),
  validate(updateSchema),
  asyncHandler(async (req, res) => {
    await updateFarmer(req.params.id, req.body);
    res.status(204).send();
  }),
);

// DELETE /farmers/:id  -> soft deactivate
router.delete(
  '/:id',
  validate(idSchema, 'params'),
  asyncHandler(async (req, res) => {
    await deactivateFarmer(req.params.id);
    res.status(204).send();
  }),
);

export default router;
