import { Router } from 'express';
import farmers from './farmers.js';
import crops from './crops.js';
import diseaseScans from './diseaseScans.js';
import mandiPrices from './mandiPrices.js';
import alerts from './alerts.js';
import schemes from './schemes.js';
import recommendations from './recommendations.js';
import { authenticate } from '../middleware/auth.js';

const router = Router();

// All v1 routes require a valid JWT (or AUTH_DISABLED=true in dev).
router.use(authenticate);

router.use('/farmers', farmers);
router.use('/crops', crops);
router.use('/disease-scans', diseaseScans);
router.use('/mandi-prices', mandiPrices);
router.use('/alerts', alerts);
router.use('/schemes', schemes);
router.use('/recommendations', recommendations);

export default router;
