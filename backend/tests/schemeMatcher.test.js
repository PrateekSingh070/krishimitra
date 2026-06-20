import { jest } from '@jest/globals';

process.env.NODE_ENV = 'test';

// scoreMatch is pure, but the module imports the db pool + alerts; mock the
// pool so importing doesn't require a live PostgreSQL connection.
jest.unstable_mockModule('../src/db/pool.js', () => ({
  query: jest.fn(),
  rows: jest.fn(),
  one: jest.fn(),
  withTransaction: jest.fn(),
  getPool: jest.fn(),
}));

const { scoreMatch, ALERT_THRESHOLD } = await import('../src/services/schemeMatcher.js');

describe('scoreMatch', () => {
  const farmer = { land_acres: 3, state: 'UP' };

  it('returns 0 when eligibility is null', () => {
    expect(scoreMatch(farmer, [], null)).toBe(0);
  });

  it('scores full marks when all criteria are met', () => {
    const eligibility = { min_land: 1, max_land: 5, states: ['UP', 'MP'] };
    expect(scoreMatch(farmer, [], eligibility)).toBe(100);
  });

  it('scores partial when some criteria fail', () => {
    // max_land 2 fails (farmer has 3 acres); min_land + states pass -> 2/3.
    const eligibility = { min_land: 1, max_land: 2, states: ['UP'] };
    expect(scoreMatch(farmer, [], eligibility)).toBe(66.67);
  });

  it('matches an active crop from the crops criterion', () => {
    const eligibility = { crops: ['Wheat', 'Rice'] };
    expect(scoreMatch(farmer, ['WHEAT'], eligibility)).toBe(100);
    expect(scoreMatch(farmer, ['COTTON'], eligibility)).toBe(0);
  });

  it('exposes the alert threshold constant', () => {
    expect(ALERT_THRESHOLD).toBe(80);
  });
});
