import { Router } from 'express';
import { asyncHandler, ApiError } from '../middleware/error.js';
import { one } from '../db/pool.js';
import { config } from '../config/index.js';

const router = Router();

// GET /weather?district=Pune&state=Maharashtra
// Returns latest weather + 7-day forecast for a district.
// Falls back to live Open-Meteo fetch if no DB record exists.
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { district, state } = req.query;
    if (!district) throw new ApiError(400, 'district query param is required');

    // Try DB first (populated by cron job).
    const row = await one(
      `SELECT temp_celsius, humidity_pct, rainfall_mm, wind_speed_kmh,
              forecast_json, recorded_at
       FROM weather_data
       WHERE district = $1
       ORDER BY recorded_at DESC
       LIMIT 1`,
      [district],
    );

    if (row && row.forecast_json) {
      return res.json({
        source: 'cache',
        district,
        state: state || null,
        recorded_at: row.recorded_at,
        current: {
          temp_celsius: row.temp_celsius,
          humidity_pct: row.humidity_pct,
          rainfall_mm: row.rainfall_mm,
          wind_speed_kmh: row.wind_speed_kmh,
        },
        daily: typeof row.forecast_json === 'string'
          ? JSON.parse(row.forecast_json)
          : row.forecast_json,
      });
    }

    // Live fetch from Open-Meteo (keyless, free).
    const geoUrl =
      `${config.ingest.openMeteoGeocodeUrl}?name=${encodeURIComponent(district)}` +
      '&count=1&country=IN&language=en&format=json';
    const geoResp = await fetch(geoUrl);
    const geoJson = await geoResp.json();
    const hit = geoJson.results && geoJson.results[0];
    if (!hit) throw new ApiError(404, `District "${district}" not found in geocoding database`);

    const fcUrl =
      `${config.ingest.openMeteoForecastUrl}?latitude=${hit.latitude}&longitude=${hit.longitude}` +
      '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation' +
      '&daily=precipitation_sum,temperature_2m_max,temperature_2m_min,weathercode' +
      '&forecast_days=7&timezone=Asia%2FKolkata';
    const fcResp = await fetch(fcUrl);
    const fcJson = await fcResp.json();
    const cur = fcJson.current || {};

    res.json({
      source: 'live',
      district,
      state: state || null,
      recorded_at: new Date().toISOString(),
      current: {
        temp_celsius: cur.temperature_2m ?? null,
        humidity_pct: cur.relative_humidity_2m ?? null,
        rainfall_mm: cur.precipitation ?? null,
        wind_speed_kmh: cur.wind_speed_10m ?? null,
      },
      daily: fcJson.daily || null,
    });
  }),
);

export default router;
