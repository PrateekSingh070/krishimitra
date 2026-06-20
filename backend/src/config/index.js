import dotenv from 'dotenv';

dotenv.config();

const toInt = (val, fallback) => {
  const n = Number.parseInt(val ?? '', 10);
  return Number.isNaN(n) ? fallback : n;
};

const toBool = (val, fallback = false) => {
  if (val === undefined || val === null || val === '') return fallback;
  return String(val).toLowerCase() === 'true';
};

export const config = {
  env: process.env.NODE_ENV || 'development',
  port: toInt(process.env.PORT, 3000),
  logLevel: process.env.LOG_LEVEL || 'info',

  db: {
    // Supabase connection string, e.g.
    // postgresql://postgres:<pwd>@db.<ref>.supabase.co:5432/postgres
    url: process.env.DATABASE_URL,
    poolMax: toInt(process.env.DB_POOL_MAX, 10),
    // Supabase/managed Postgres requires TLS; disable only for local plain pg.
    ssl: toBool(process.env.DB_SSL, true),
  },

  // Supabase project credentials (Storage / optional Auth).
  supabase: {
    url: process.env.SUPABASE_URL || '',
    anonKey: process.env.SUPABASE_ANON_KEY || '',
    serviceRole: process.env.SUPABASE_SERVICE_ROLE || '',
    diseaseBucket: process.env.SUPABASE_DISEASE_BUCKET || 'disease-scans',
  },

  // Email alerts via any free SMTP relay (Gmail app password, Brevo, etc.).
  smtp: {
    host: process.env.SMTP_HOST || '',
    port: toInt(process.env.SMTP_PORT, 587),
    secure: toBool(process.env.SMTP_SECURE, false),
    user: process.env.SMTP_USER || '',
    password: process.env.SMTP_PASSWORD || '',
    sender: process.env.SMTP_SENDER || process.env.SMTP_USER || '',
  },

  // External free data sources for the ingestion jobs.
  ingest: {
    enableJobs: toBool(process.env.ENABLE_JOBS, false),
    openMeteoForecastUrl:
      process.env.OPEN_METEO_FORECAST_URL || 'https://api.open-meteo.com/v1/forecast',
    openMeteoGeocodeUrl:
      process.env.OPEN_METEO_GEOCODE_URL || 'https://geocoding-api.open-meteo.com/v1/search',
    dataGovApiKey: process.env.DATAGOV_API_KEY || '',
    dataGovBaseUrl: process.env.DATAGOV_BASE_URL || 'https://api.data.gov.in/resource',
    agmarknetResourceId:
      process.env.AGMARKNET_RESOURCE_ID || '9ef84268-d588-465a-a308-a864a43d0070',
    schemeResourceId: process.env.SCHEME_RESOURCE_ID || '',
  },

  // Disease classification model artifacts (local dir or downloaded at boot).
  ml: {
    artifactsDir: process.env.ML_ARTIFACTS_DIR || 'ml-artifacts',
    modelFile: process.env.DISEASE_MODEL_FILE || 'disease_mobilenetv3.onnx',
    labelsFile: process.env.DISEASE_LABELS_FILE || 'class_labels.json',
    lookupFile: process.env.DISEASE_LOOKUP_FILE || 'disease_lookup.json',
  },

  // SMS delivery via Fast2SMS (free, India). Leave blank to print OTP to logs.
  sms: {
    fast2smsKey: process.env.FAST2SMS_API_KEY || '',
  },

  // WhatsApp Cloud API (Meta) — free 1000 conversations/month.
  // Get token + phone number ID from developers.facebook.com/apps
  whatsapp: {
    token: process.env.META_WHATSAPP_TOKEN || '',
    phoneId: process.env.META_WHATSAPP_PHONE_ID || '',
  },

  auth: {
    disabled: toBool(process.env.AUTH_DISABLED, false),
    secret: process.env.JWT_SECRET || '',
    jwksUri: process.env.JWT_JWKS_URI || '',
    issuer: process.env.JWT_ISSUER || '',
    audience: process.env.JWT_AUDIENCE || '',
  },

  rateLimit: {
    windowMs: toInt(process.env.RATE_LIMIT_WINDOW_MS, 15 * 60 * 1000),
    max: toInt(process.env.RATE_LIMIT_MAX, 300),
  },
};

// Fail fast on missing critical config unless we are clearly in test mode.
export function assertConfig() {
  if (config.env === 'test') return;
  const missing = [];
  if (!config.db.url) missing.push('DATABASE_URL');
  if (!config.auth.disabled && !config.auth.secret && !config.auth.jwksUri) {
    missing.push('JWT_SECRET or JWT_JWKS_URI (or set AUTH_DISABLED=true for dev)');
  }
  if (missing.length) {
    throw new Error(
      `Missing required configuration: ${missing.join(', ')}. ` +
        'Set them in backend/.env (see .env.example / SUPABASE-SETUP.md).',
    );
  }
}
