import pino from 'pino';
import { config } from './index.js';

export const logger = pino({
  level: config.logLevel,
  // Redact anything that could leak PII / secrets from logs.
  redact: {
    paths: [
      'req.headers.authorization',
      'req.body.aadhaar',
      'req.body.aadhaar_raw',
      'password',
      '*.password',
    ],
    censor: '[REDACTED]',
  },
});
