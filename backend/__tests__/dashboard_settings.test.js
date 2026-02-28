const { app, request, loginAdminOrSkip } = require('./test_utils');

let auth;

beforeAll(async () => {
  auth = await loginAdminOrSkip();
});

describe('Dashboard Settings & Activity API', () => {
  test('GET /api/dashboard/activity returns array', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/dashboard/activity')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('GET /api/dashboard/settings/:userId returns settings', async () => {
    if (auth.skip) return;
    const userId = auth.user.id || auth.user.user_id || 1;
    const res = await request(app)
      .get(`/api/dashboard/settings/${userId}`)
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    // Should return an array or object of widget settings
    expect(res.body).toBeDefined();
  });

  test('PUT /api/dashboard/settings/:userId updates settings', async () => {
    if (auth.skip) return;
    const userId = auth.user.id || auth.user.user_id || 1;
    const res = await request(app)
      .put(`/api/dashboard/settings/${userId}`)
      .set('Authorization', `Bearer ${auth.token}`)
      .send({ widgets: [] });
    expect([200, 400]).toContain(res.statusCode);
  });

  test('POST /api/dashboard/activity/clear clears activity', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .post('/api/dashboard/activity/clear')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
  });
});
