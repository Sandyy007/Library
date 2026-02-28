const { app, request, loginAdminOrSkip } = require('./test_utils');

let auth;

beforeAll(async () => {
  auth = await loginAdminOrSkip();
});

describe('Search & Recommendations API', () => {
  test('GET /api/search with query returns results', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/search?q=test')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('books');
    expect(res.body).toHaveProperty('members');
    expect(Array.isArray(res.body.books)).toBe(true);
    expect(Array.isArray(res.body.members)).toBe(true);
  });

  test('GET /api/search without query returns 400 or empty', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/search')
      .set('Authorization', `Bearer ${auth.token}`);
    // Should either error or return empty results
    expect([200, 400]).toContain(res.statusCode);
  });

  test('GET /api/search with empty string', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/search?q=')
      .set('Authorization', `Bearer ${auth.token}`);
    expect([200, 400]).toContain(res.statusCode);
  });

  test('GET /api/recommendations/:memberId returns array', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/recommendations/1')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('GET /api/recommendations with invalid member id', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/recommendations/999999')
      .set('Authorization', `Bearer ${auth.token}`);
    // Should return empty array or 200
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });
});
