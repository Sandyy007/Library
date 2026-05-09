const { app, request, loginAdminOrSkip } = require('./test_utils');

let auth;

beforeAll(async () => {
  auth = await loginAdminOrSkip();
});

describe('Reports & Dashboard API', () => {
  test('GET /api/dashboard/stats returns stats object', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/dashboard/stats')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('total_books');
    expect(res.body).toHaveProperty('total_members');
    expect(res.body).toHaveProperty('issued_books');
    expect(res.body).toHaveProperty('available_books');
    expect(typeof res.body.total_books).toBe('number');
  });

  test('GET /api/dashboard/alerts returns array', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/dashboard/alerts')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('kpis');
  });

  test('GET /api/dashboard/alerts low stock supports pagination', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/dashboard/alerts?low_stock_threshold=999999&low_stock_page=2&low_stock_limit=2')
      .set('Authorization', `Bearer ${auth.token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('lowStock');
    expect(res.body.lowStock).toHaveProperty('pagination');
    expect(res.body.lowStock.pagination).toMatchObject({ page: 2, limit: 2 });
    expect(Array.isArray(res.body.lowStock.items)).toBe(true);
    expect(res.body.lowStock.items.length).toBeLessThanOrEqual(2);
  });

  test('GET /api/reports/issued returns report', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/reports/issued')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('GET /api/reports/overdue returns report', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/reports/overdue')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('GET /api/reports/popular-books returns data', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/reports/popular-books')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('GET /api/reports/active-members returns data', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/reports/active-members')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('GET /api/reports/monthly-stats returns array', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/reports/monthly-stats')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('GET /api/reports/category-stats returns array', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/reports/category-stats')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });
});
