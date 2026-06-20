import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import pinoHttp from 'pino-http';
import { config } from './config/index.js';
import { logger } from './config/logger.js';
import v1Routes from './routes/index.js';
import { notFound, errorHandler } from './middleware/error.js';

export function createApp() {
  const app = express();

  app.set('trust proxy', 1); // behind OCI Load Balancer / API Gateway
  app.use(helmet());
  app.use(cors());
  app.use(compression());
  // Larger limit accommodates base64 leaf images on POST /disease-scans/classify.
  app.use(express.json({ limit: '10mb' }));
  app.use(pinoHttp({ logger }));

  app.use(
    rateLimit({
      windowMs: config.rateLimit.windowMs,
      max: config.rateLimit.max,
      standardHeaders: true,
      legacyHeaders: false,
    }),
  );

  // Liveness/readiness probe (unauthenticated).
  app.get('/health', (_req, res) => res.json({ status: 'ok', env: config.env }));

  app.use('/api/v1', v1Routes);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}
