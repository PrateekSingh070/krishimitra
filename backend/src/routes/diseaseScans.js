import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, ApiError } from '../middleware/error.js';
import { validate } from '../middleware/validate.js';
import { one, rows } from '../db/pool.js';
import { uploadDiseaseImage } from '../services/storage.js';
import { classifyToPayload } from '../services/diseaseClassifier.js';

const router = Router();

const createSchema = z.object({
  farmer_id: z.number().int().positive(),
  farmer_crop_id: z.number().int().positive().optional(),
  image_url: z.string().url().max(500),
  disease_detected: z.string().max(200).optional(),
  confidence_score: z.number().min(0).max(100).optional(),
  severity: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']).optional(),
  treatment_advice: z.string().optional(),
  treatment_hindi: z.string().optional(),
  oci_vision_req: z.string().max(200).optional(),
});

const classifySchema = z.object({
  farmer_id: z.number().int().positive(),
  farmer_crop_id: z.number().int().positive().optional(),
  image_base64: z.string().min(1),
  content_type: z.string().max(50).optional(),
});

const idSchema = z.object({ id: z.coerce.number().int().positive() });

// Insert a scan row; the TRG_DISEASE_SCAN_ALERT trigger auto-creates an alert
// for HIGH/CRITICAL severities.
async function insertScan(b) {
  const row = await one(
    `INSERT INTO disease_scans (
       farmer_id, farmer_crop_id, image_url, disease_detected,
       confidence_score, severity, treatment_advice, treatment_hindi, oci_vision_req)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     RETURNING scan_id, farmer_id, farmer_crop_id, image_url, disease_detected,
               confidence_score, severity, treatment_advice, treatment_hindi, scan_timestamp`,
    [
      b.farmer_id,
      b.farmer_crop_id ?? null,
      b.image_url,
      b.disease_detected ?? null,
      b.confidence_score ?? null,
      b.severity ?? null,
      b.treatment_advice ?? null,
      b.treatment_hindi ?? null,
      b.oci_vision_req ?? null,
    ],
  );
  return row;
}

// POST /disease-scans  -> manual insert (results computed elsewhere)
router.post(
  '/',
  validate(createSchema),
  asyncHandler(async (req, res) => {
    const row = await insertScan(req.body);
    res.status(201).json({ scan_id: row.scan_id });
  }),
);

// POST /disease-scans/classify  -> upload image, run ONNX inference, store scan.
// Accepts a base64 image (the app-level JSON limit is raised to 10mb for this).
router.post(
  '/classify',
  validate(classifySchema),
  asyncHandler(async (req, res) => {
    const b = req.body;
    const contentType = b.content_type || 'image/jpeg';
    const base64 = b.image_base64.replace(/^data:[^;]+;base64,/, '');
    const buffer = Buffer.from(base64, 'base64');
    if (buffer.length === 0) throw new ApiError(400, 'image_base64 is empty or invalid');

    const imageUrl = await uploadDiseaseImage(buffer, {
      farmerId: b.farmer_id,
      contentType,
    });

    const payload = await classifyToPayload({
      farmerId: b.farmer_id,
      farmerCropId: b.farmer_crop_id ?? null,
      imageUrl,
      buffer,
    });

    const row = await insertScan(payload);
    res.status(201).json(row);
  }),
);

// GET /disease-scans/:id
router.get(
  '/:id',
  validate(idSchema, 'params'),
  asyncHandler(async (req, res) => {
    const row = await one(
      `SELECT scan_id, farmer_id, farmer_crop_id, image_url, disease_detected,
              confidence_score, severity, treatment_advice, treatment_hindi,
              scan_timestamp, oci_vision_req
       FROM disease_scans WHERE scan_id = $1`,
      [req.params.id],
    );
    if (!row) throw new ApiError(404, 'Scan not found');
    res.json(row);
  }),
);

// GET /disease-scans?farmer_id=
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const farmerId = req.query.farmer_id ? Number(req.query.farmer_id) : null;
    const items = await rows(
      `SELECT scan_id, farmer_id, farmer_crop_id, image_url, disease_detected,
              confidence_score, severity, scan_timestamp
       FROM disease_scans
       WHERE ($1::bigint IS NULL OR farmer_id = $1)
       ORDER BY scan_timestamp DESC
       LIMIT 100`,
      [farmerId],
    );
    res.json({ items });
  }),
);

export default router;
