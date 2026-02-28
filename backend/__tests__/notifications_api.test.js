const { app, request, loginAdminOrSkip } = require('./test_utils');

let auth;

beforeAll(async () => {
  auth = await loginAdminOrSkip();
});

describe('Notifications API', () => {
  test('GET /api/notifications returns array', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/notifications')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('GET /api/notifications/count returns count object', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/notifications/count')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('count');
    expect(typeof res.body.count).toBe('number');
  });

  test('PUT /api/notifications/read-all succeeds', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .put('/api/notifications/read-all')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
  });

  test('PUT /api/notifications/:id/read with invalid id', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .put('/api/notifications/999999/read')
      .set('Authorization', `Bearer ${auth.token}`);
    // Should succeed (no-op) or return a sensible status
    expect([200, 404]).toContain(res.statusCode);
  });

  test('DELETE /api/notifications/:id with invalid id', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .delete('/api/notifications/999999')
      .set('Authorization', `Bearer ${auth.token}`);
    expect([200, 404]).toContain(res.statusCode);
  });
});
