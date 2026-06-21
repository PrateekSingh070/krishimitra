import { Router } from 'express';
import { asyncHandler, ApiError } from '../middleware/error.js';
import { one } from '../db/pool.js';
import { config } from '../config/index.js';

const router = Router();

const STATE_ALIASES = {
  'UTTAR PRADESH': 'UP',
  UP: 'UP',
  'MADHYA PRADESH': 'MP',
  MP: 'MP',
  MAHARASHTRA: 'MAHARASHTRA',
  PUNJAB: 'PUNJAB',
  BIHAR: 'BIHAR',
  RAJASTHAN: 'RAJASTHAN',
  DELHI: 'DELHI',
  'NCT OF DELHI': 'DELHI',
  HARYANA: 'HARYANA',
  GUJARAT: 'GUJARAT',
  KARNATAKA: 'KARNATAKA',
  'TAMIL NADU': 'TAMIL NADU',
  'WEST BENGAL': 'WEST BENGAL',
  ODISHA: 'ODISHA',
  ORISSA: 'ODISHA',
  TELANGANA: 'TELANGANA',
  'ANDHRA PRADESH': 'ANDHRA PRADESH',
  KERALA: 'KERALA',
  JHARKHAND: 'JHARKHAND',
  CHHATTISGARH: 'CHHATTISGARH',
  UTTARAKHAND: 'UTTARAKHAND',
  HIMACHAL: 'HIMACHAL PRADESH',
  'HIMACHAL PRADESH': 'HIMACHAL PRADESH',
};

function norm(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizeState(value) {
  const state = String(value || '').trim().toUpperCase();
  return STATE_ALIASES[state] || state;
}

function stateMatches(inputState, geocodeState) {
  if (!inputState) return true;
  return normalizeState(inputState) === normalizeState(geocodeState);
}

function parseDaily(value) {
  if (!value) return null;
  const daily = typeof value === 'string' ? JSON.parse(value) : value;
  if (daily?.weather_code && !daily.weathercode) {
    daily.weathercode = daily.weather_code;
  }
  return daily;
}

function hasForecast(daily) {
  return Boolean(daily && Array.isArray(daily.time) && daily.time.length > 0);
}

async function geocodeDistrict(district, state) {
  const geoUrl =
    `${config.ingest.openMeteoGeocodeUrl}?name=${encodeURIComponent(district)}` +
    '&count=10&country=IN&language=en&format=json';
  const geoResp = await fetch(geoUrl, { signal: AbortSignal.timeout(15000) });
  if (!geoResp.ok) return null;

  const geoJson = await geoResp.json();
  const hits = (geoJson.results || []).filter((hit) => hit.country_code === 'IN');
  if (hits.length === 0) return null;

  if (state) {
    const stateHit = hits.find((hit) => stateMatches(state, hit.admin1));
    if (stateHit) return stateHit;
    return null;
  }

  return hits[0];
}

async function fetchForecast(hit) {
  const fcUrl =
    `${config.ingest.openMeteoForecastUrl}?latitude=${hit.latitude}&longitude=${hit.longitude}` +
    '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation,weather_code' +
    '&daily=precipitation_sum,temperature_2m_max,temperature_2m_min,weather_code' +
    '&forecast_days=7&timezone=Asia%2FKolkata';
  const fcResp = await fetch(fcUrl, { signal: AbortSignal.timeout(15000) });
  if (!fcResp.ok) throw new ApiError(502, 'Weather provider is temporarily unavailable');

  const fcJson = await fcResp.json();
  const cur = fcJson.current || {};
  const daily = parseDaily(fcJson.daily);

  return {
    current: {
      temp_celsius: cur.temperature_2m ?? null,
      humidity_pct: cur.relative_humidity_2m ?? null,
      rainfall_mm: cur.precipitation ?? null,
      wind_speed_kmh: cur.wind_speed_10m ?? null,
      weather_code: cur.weather_code ?? null,
    },
    daily,
  };
}

function cacheResponse(row, district, state) {
  const daily = parseDaily(row.forecast_json);
  return {
    source: 'cache',
    district,
    state: state || row.state || null,
    recorded_at: row.recorded_at,
    current: {
      temp_celsius: row.temp_celsius,
      humidity_pct: row.humidity_pct,
      rainfall_mm: row.rainfall_mm,
      wind_speed_kmh: row.wind_speed_kmh,
      weather_code: daily?.weathercode?.[0] ?? daily?.weather_code?.[0] ?? null,
    },
    daily,
  };
}

// GET /weather?district=Pune&state=Maharashtra
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const district = String(req.query.district || '').trim();
    const state = String(req.query.state || '').trim();
    if (!district) throw new ApiError(400, 'district query param is required');

    const row = await one(
      `SELECT temp_celsius, humidity_pct, rainfall_mm, wind_speed_kmh,
              forecast_json, recorded_at, state
       FROM weather_data
       WHERE lower(district) = lower($1)
         AND ($2 = '' OR state IS NULL OR lower(state) = lower($2)
              OR lower(state) = lower($3))
       ORDER BY recorded_at DESC
       LIMIT 1`,
      [district, state, normalizeState(state)],
    );

    const cachedDaily = parseDaily(row?.forecast_json);
    if (row && hasForecast(cachedDaily)) {
      return res.json(cacheResponse(row, district, state));
    }

    try {
      const hit = await geocodeDistrict(district, state);
      if (!hit) throw new ApiError(404, `District "${district}" not found in geocoding database`);
      const forecast = await fetchForecast(hit);

      res.json({
        source: 'live',
        district: hit.name || district,
        state: hit.admin1 || state || null,
        recorded_at: new Date().toISOString(),
        current: forecast.current,
        daily: forecast.daily,
      });
    } catch (err) {
      if (row && hasForecast(cachedDaily)) {
        return res.json(cacheResponse(row, district, state));
      }
      throw err;
    }
  }),
);

export default router;
