import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import pinoHttp from 'pino-http';
import { config } from './config/index.js';
import { logger } from './config/logger.js';
import v1Routes from './routes/index.js';
import authRoutes from './routes/auth.js';
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

  // Public auth routes (no JWT required).
  app.use('/api/auth', authRoutes);

  // Public self-registration endpoint (no JWT — new farmer has no token yet).
  // Handled before the authenticated v1 router.
  app.post('/api/v1/farmers', async (req, res, next) => {
    try {
      const { registerFarmer } = await import('./services/farmerService.js');
      const farmerId = await registerFarmer(req.body);
      res.status(201).json({ farmer_id: farmerId });
    } catch (err) {
      next(err);
    }
  });

  app.use('/api/v1', v1Routes);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}
