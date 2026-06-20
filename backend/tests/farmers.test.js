import { jest } from '@jest/globals';

// Run with auth disabled and in test mode before any app module loads.
process.env.AUTH_DISABLED = 'true';
process.env.NODE_ENV = 'test';

// Mock the farmer service so the route is tested without a live database.
const registerFarmer = jest.fn();
const updateFarmer = jest.fn();
const getFarmer = jest.fn();
const deactivateFarmer = jest.fn();
jest.unstable_mockModule('../src/services/farmerService.js', () => ({
  registerFarmer,
  updateFarmer,
  getFarmer,
  deactivateFarmer,
  hashAadhaar: () => null,
}));

// Avoid pulling heavy native deps (pg/onnx/supabase) into the test process.
jest.unstable_mockModule('../src/db/pool.js', () => ({
  initPool: jest.fn(),
  closePool: jest.fn(),
  query: jest.fn(),
  rows: jest.fn().mockResolvedValue([]),
  one: jest.fn(),
  withTransaction: jest.fn(),
  getPool: jest.fn(),
}));

const request = (await import('supertest')).default;
const { createApp } = await import('../src/app.js');

const app = createApp();

describe('POST /api/v1/farmers', () => {
  beforeEach(() => {
    registerFarmer.mockReset();
  });

  it('registers a farmer and returns the new id', async () => {
    registerFarmer.mockResolvedValueOnce(1042);

    const res = await request(app)
      .post('/api/v1/farmers')
      .send({ name: 'Ramesh', phone: '9876543210', state: 'UP', land_acres: 3 });

    expect(res.status).toBe(201);
    expect(res.body).toEqual({ farmer_id: 1042 });
    expect(registerFarmer).toHaveBeenCalledTimes(1);
  });

  it('rejects an invalid phone with 400', async () => {
    const res = await request(app)
      .post('/api/v1/farmers')
      .send({ name: 'Ramesh', phone: 'not-a-number' });

    expect(res.status).toBe(400);
    expect(res.body.error.status).toBe(400);
    expect(registerFarmer).not.toHaveBeenCalled();
  });
});

describe('GET /health', () => {
  it('returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});
