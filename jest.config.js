module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testTimeout: 120000, // 120 seconds (each test suite starts its own validator)
  testMatch: ['**/examples/**/*.test.ts'],
};
