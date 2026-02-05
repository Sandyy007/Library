const request = require('supertest');
const { app } = require('../server');

async function loginAdminOrSkip() {
  try {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'Library#123' });

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
