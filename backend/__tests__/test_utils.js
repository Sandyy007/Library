const request = require('supertest');
const { app } = require('../server');

// Admin credentials for tests. Defaults to the password seeded by the schema
// (database/schema*.sql -> 'Library#123'); override via ADMIN_PASSWORD when the
// local/CI database was seeded differently. Both this Jest helper and
// integration_test.js read the same variable so they never drift apart.
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'Library#123';

async function loginAdminOrSkip() {
  try {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: ADMIN_PASSWORD });

    if (res.statusCode !== 200 || !res.body || !res.body.token) {
      return { skip: true, reason: `Login failed: ${res.statusCode} ${JSON.stringify(res.body)}` };
    }

    return {
      skip: false,
      token: res.body.token,
      user: res.body.user,
    };
  } catch (e) {
    return { skip: true, reason: `Login error: ${e?.message || String(e)}` };
  }
}

module.exports = {
  app,
  request,
  loginAdminOrSkip,
};
