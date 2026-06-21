import { Router } from 'express';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { one } from '../db/pool.js';
import { config } from '../config/index.js';
import { generateOtp, storeOtp, verifyOtp, sendOtpSms } from '../services/otpService.js';
import { ApiError } from '../middleware/error.js';
import { validate } from '../middleware/validate.js';
import { registerFarmer, verifyPin } from '../services/farmerService.js';

const router = Router();

function signFarmerToken(farmer) {
  if (!config.auth.secret) {
    throw new ApiError(500, 'JWT_SECRET is not configured on the server.');
  }

  return jwt.sign(
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
}

// POST /api/auth/login { phone, pin }
// Free login path: farmer enters mobile number + 4-6 digit PIN.
router.post(
  '/login',
  validate(z.object({
    phone: z.string().regex(/^[0-9]{10,15}$/, 'phone must be 10-15 digits'),
    pin: z.string().regex(/^[0-9]{4,6}$/, 'PIN must be 4-6 digits'),
  })),
  async (req, res, next) => {
    try {
      const { phone, pin } = req.body;
      const farmer = await one(
        `SELECT farmer_id, name, preferred_lang, pin_hash, pin_salt
         FROM farmers
         WHERE phone = $1 AND is_active = $2`,
        [phone, 'Y'],
      );

      if (!farmer || !verifyPin(pin, farmer.pin_hash, farmer.pin_salt)) {
        throw new ApiError(401, 'Invalid phone number or PIN');
      }

      res.json({
        token: signFarmerToken(farmer),
        farmer_id: farmer.farmer_id,
        name: farmer.name,
        lang: farmer.preferred_lang,
      });
    } catch (err) {
      next(err);
    }
  },
);

// POST /api/auth/request-otp  { phone }
// Generates a 6-digit OTP for both existing and new farmer phone numbers.
router.post(
  '/request-otp',
  validate(z.object({ phone: z.string().min(10).max(15) })),
  async (req, res, next) => {
    try {
      const { phone } = req.body;

      const otp = generateOtp();
      storeOtp(phone, otp);
      const smsSent = await sendOtpSms(phone, otp);

      res.json({
        message: smsSent
          ? `OTP sent to ${phone.slice(0, 5)}XXXXX`
          : `OTP generated (SMS unavailable — check server logs)`,
        expires_in: 300,
      });
    } catch (err) {
      next(err);
    }
  },
);

// POST /api/auth/verify-otp  { phone, otp }
// Verifies OTP and returns a signed JWT containing farmer_id.
// If the phone is new, create a minimal farmer profile automatically.
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

      let farmer = await one(
        'SELECT farmer_id, name, preferred_lang FROM farmers WHERE phone = $1 AND is_active = $2',
        [phone, 'Y'],
      );
      let isNewFarmer = false;

      if (!farmer) {
        const farmerId = await registerFarmer({
          name: `Farmer ${phone.slice(-4)}`,
          phone,
          preferred_lang: 'hi',
        });
        farmer = await one(
          'SELECT farmer_id, name, preferred_lang FROM farmers WHERE farmer_id = $1',
          [farmerId],
        );
        isNewFarmer = true;
      }

      res.json({
        token: signFarmerToken(farmer),
        farmer_id: farmer.farmer_id,
        name: farmer.name,
        lang: farmer.preferred_lang,
        is_new_farmer: isNewFarmer,
      });
    } catch (err) {
      next(err);
    }
  },
);

export default router;
