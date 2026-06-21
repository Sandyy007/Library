const { app, request } = require('./test_utils');

describe('Health API', () => {
  test('GET /api/health returns ok', async () => {
    const res = await request(app).get('/api/health');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('status', 'healthy');
  });

  test('GET /api/health/detailed returns status + db', async () => {
    const res = await request(app).get('/api/health/detailed');
    // 200 when the DB is reachable, 503 when it is degraded/unreachable.
    // Both are valid responses for this endpoint depending on environment.
    expect([200, 503]).toContain(res.statusCode);
    expect(res.body).toHaveProperty('status');
    expect(res.body).toHaveProperty('database');
  });
});
