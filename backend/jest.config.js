export default {
  testEnvironment: 'node',
  // ESM project: tests use node --experimental-vm-modules (see npm test script).
  transform: {},
  testMatch: ['**/tests/**/*.test.js'],
};
