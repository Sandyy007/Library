const { app, request } = require('./test_utils');

describe('Health API', () => {
  test('GET /api/health returns ok', async () => {
    const res = await request(app).get('/api/health');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('status', 'healthy');
  });

  test('GET /api/health/detailed returns status + db', async () => {
    const res = await request(app).get('/api/health/detailed');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('status');
    expect(res.body).toHaveProperty('database');
  });
});
