import crypto from 'node:crypto';
import { query, one } from '../db/pool.js';
import { ApiError } from '../middleware/error.js';

// Port of db/plsql/pkg_farmer.pkb. Aadhaar is hashed (SHA-256) in the app and
// never persisted raw, matching the original DBMS_CRYPTO.HASH_SH256 behaviour.

export function hashAadhaar(raw) {
  if (!raw) return null;
  return crypto.createHash('sha256').update(raw, 'utf8').digest('hex');
}

export function hashPin(pin, salt = crypto.randomBytes(16).toString('hex')) {
  if (!pin) return { hash: null, salt: null };
  const hash = crypto.pbkdf2Sync(String(pin), salt, 120000, 32, 'sha256').toString('hex');
  return { hash, salt };
}

export function verifyPin(pin, hash, salt) {
  if (!pin || !hash || !salt) return false;
  const candidate = hashPin(pin, salt).hash;
  return crypto.timingSafeEqual(Buffer.from(candidate, 'hex'), Buffer.from(hash, 'hex'));
}

export async function registerFarmer(b) {
  try {
    if (!/^[0-9]{10,15}$/.test(String(b.phone || ''))) {
      throw new ApiError(400, 'phone must be 10-15 digits');
    }
    if (b.pin !== undefined && !/^[0-9]{4,6}$/.test(String(b.pin))) {
      throw new ApiError(400, 'PIN must be 4-6 digits');
    }

    const { hash: pinHash, salt: pinSalt } = hashPin(b.pin ?? String(b.phone).slice(-4));
    const row = await one(
      `INSERT INTO farmers (name, phone, email, aadhaar_hash, pin_hash, pin_salt, state, district,
                            village, land_acres, soil_type, preferred_lang, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 'Y')
       RETURNING farmer_id`,
      [
        b.name,
        b.phone,
        b.email ?? null,
        hashAadhaar(b.aadhaar),
        pinHash,
        pinSalt,
        b.state ?? null,
        b.district ?? null,
        b.village ?? null,
        b.land_acres ?? null,
        b.soil_type ?? null,
        b.preferred_lang ?? 'hi',
      ],
    );
    return row.farmer_id;
  } catch (err) {
    if (err.code === '23505' && err.constraint === 'uq_farmers_phone') {
      throw new ApiError(409, `A farmer with phone ${b.phone} already exists.`);
    }
    throw err;
  }
}

// Partial update; NULL fields are left unchanged (COALESCE mirrors NVL).
export async function updateFarmer(farmerId, b) {
  const res = await query(
    `UPDATE farmers SET
       name           = COALESCE($2, name),
       email          = COALESCE($3, email),
       state          = COALESCE($4, state),
       district       = COALESCE($5, district),
       village        = COALESCE($6, village),
       land_acres     = COALESCE($7, land_acres),
       soil_type      = COALESCE($8, soil_type),
       preferred_lang = COALESCE($9, preferred_lang)
     WHERE farmer_id = $1`,
    [
      farmerId,
      b.name ?? null,
      b.email ?? null,
      b.state ?? null,
      b.district ?? null,
      b.village ?? null,
      b.land_acres ?? null,
      b.soil_type ?? null,
      b.preferred_lang ?? null,
    ],
  );
  if (res.rowCount === 0) throw new ApiError(404, `Farmer ${farmerId} not found.`);
}

export async function getFarmer(farmerId) {
  return one(
    `SELECT farmer_id, name, phone, email, state, district, village,
            land_acres, soil_type, preferred_lang, is_active, created_at, updated_at
     FROM farmers WHERE farmer_id = $1`,
    [farmerId],
  );
}

export async function deactivateFarmer(farmerId) {
  const res = await query(
    `UPDATE farmers SET is_active = 'N' WHERE farmer_id = $1`,
    [farmerId],
  );
  if (res.rowCount === 0) throw new ApiError(404, `Farmer ${farmerId} not found.`);
}
