import { Router } from 'express';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { one } from '../db/pool.js';
import { config } from '../config/index.js';
import { generateOtp, storeOtp, verifyOtp, sendOtpSms } from '../services/otpService.js';
import { ApiError } from '../middleware/error.js';
import { validate } from '../middleware/validate.js';

const router = Router();

// POST /api/auth/request-otp  { phone }
// Generates a 6-digit OTP, stores it, and sends via SMS.
router.post(
  '/request-otp',
  validate(z.object({ phone: z.string().min(10).max(15) })),
  async (req, res, next) => {
    try {
      const { phone } = req.body;

      // Only registered farmers can log in.
      const farmer = await one('SELECT farmer_id, name FROM farmers WHERE phone = $1 AND is_active = $2', [
        phone,
        'Y',
      ]);
      if (!farmer) throw new ApiError(404, 'Phone number not registered. Contact your Krishi Mitra to register.');

      const otp = generateOtp();
      storeOtp(phone, otp);
      await sendOtpSms(phone, otp);

      res.json({ message: `OTP sent to ${phone.slice(0, 5)}XXXXX`, expires_in: 300 });
    } catch (err) {
      next(err);
    }
  },
);

// POST /api/auth/verify-otp  { phone, otp }
// Verifies OTP and returns a signed JWT containing farmer_id.
router.post(
  '/verify-otp',
  validate(z.object({ phone: z.string().min(10).max(15), otp: z.string().length(6) })),
  async (req, res, next) => {
    try {
      const { phone, otp } = req.body;
      const result = verifyOtp(phone, otp);

      if (!result.ok) {
        const messages = {
          no_otp: 'OTP not requested. Please request a new OTP first.',
          expired: 'OTP has expired. Please request a new one.',
          wrong_otp: 'Incorrect OTP. Please try again.',
          too_many_attempts: 'Too many wrong attempts. Please request a new OTP.',
        };
        throw new ApiError(401, messages[result.reason] || 'OTP verification failed.');
      }

      const farmer = await one(
        'SELECT farmer_id, name, preferred_lang FROM farmers WHERE phone = $1 AND is_active = $2',
        [phone, 'Y'],
      );
      if (!farmer) throw new ApiError(404, 'Farmer not found.');

      if (!config.auth.secret) {
        throw new ApiError(500, 'JWT_SECRET is not configured on the server.');
      }

      const token = jwt.sign(
        {
          sub: String(farmer.farmer_id),
          farmer_id: farmer.farmer_id,
          name: farmer.name,
          lang: farmer.preferred_lang,
          roles: ['farmer'],
        },
        config.auth.secret,
        { expiresIn: '30d' },
      );

      res.json({
        token,
        farmer_id: farmer.farmer_id,
        name: farmer.name,
        lang: farmer.preferred_lang,
      });
    } catch (err) {
      next(err);
    }
  },
);

export default router;
