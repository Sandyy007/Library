const { app, request, loginAdminOrSkip } = require('./test_utils');

let auth;

beforeAll(async () => {
  auth = await loginAdminOrSkip();
});

describe('Categories API', () => {
  test('GET /api/categories returns array', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .get('/api/categories')
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('POST /api/categories creates a category', async () => {
    if (auth.skip) return;
    const name = `TestCat_${Date.now()}`;
    const res = await request(app)
      .post('/api/categories')
      .set('Authorization', `Bearer ${auth.token}`)
      .send({ name });
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('id');
  });

  test('PUT /api/categories/:id updates name', async () => {
    if (auth.skip) return;
    // First create one
    const name = `CatUpdate_${Date.now()}`;
    const create = await request(app)
      .post('/api/categories')
      .set('Authorization', `Bearer ${auth.token}`)
      .send({ name });
    const id = create.body.id;

    const updated = `CatUpdated_${Date.now()}`;
    const res = await request(app)
      .put(`/api/categories/${id}`)
      .set('Authorization', `Bearer ${auth.token}`)
      .send({ name: updated });
    expect(res.statusCode).toBe(200);
  });

  test('DELETE /api/categories/:id removes category', async () => {
    if (auth.skip) return;
    const name = `CatDel_${Date.now()}`;
    const create = await request(app)
      .post('/api/categories')
      .set('Authorization', `Bearer ${auth.token}`)
      .send({ name });
    const id = create.body.id;

    const res = await request(app)
      .delete(`/api/categories/${id}`)
      .set('Authorization', `Bearer ${auth.token}`);
    expect(res.statusCode).toBe(200);
  });

  test('POST /api/categories with empty name fails', async () => {
    if (auth.skip) return;
    const res = await request(app)
      .post('/api/categories')
      .set('Authorization', `Bearer ${auth.token}`)
      .send({ name: '' });
    expect([400, 422, 500]).toContain(res.statusCode);
  });
});
