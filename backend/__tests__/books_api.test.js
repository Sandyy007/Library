const { request, app, loginAdminOrSkip } = require('./test_utils');

describe('Books API', () => {
  let testBookId = null;

  test('can list books with pagination', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    const res = await request(app)
      .get('/api/books?page=1&limit=10')
      .set('Authorization', `Bearer ${login.token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('data');
    expect(res.body).toHaveProperty('pagination');
    expect(res.body.pagination).toHaveProperty('page', 1);
    expect(res.body.pagination).toHaveProperty('limit', 10);
    expect(res.body.pagination).toHaveProperty('total');
    expect(res.body.pagination).toHaveProperty('totalPages');
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  test('can create a new book', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    const newBook = {
      isbn: `TEST-${Date.now()}`,
      title: `Test Book ${Date.now()}`,
      author: 'Test Author',
      category: 'Technology',
      total_copies: 5,
      rack_number: 'T-1',
    };

    const res = await request(app)
      .post('/api/books')
      .set('Authorization', `Bearer ${login.token}`)
      .send(newBook);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('id');
    testBookId = res.body.id;
    
    // Verify the created book by fetching it
    const getRes = await request(app)
      .get(`/api/books/${testBookId}`)
      .set('Authorization', `Bearer ${login.token}`);
    expect(getRes.statusCode).toBe(200);
    expect(getRes.body).toHaveProperty('title', newBook.title);
  });

  test('can get a book by ID', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip || !testBookId) return;

    const res = await request(app)
      .get(`/api/books/${testBookId}`)
      .set('Authorization', `Bearer ${login.token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('id', testBookId);
  });

  test('can update a book', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip || !testBookId) return;

    const res = await request(app)
      .put(`/api/books/${testBookId}`)
      .set('Authorization', `Bearer ${login.token}`)
      .send({ title: 'Updated Test Book', author: 'Updated Author' });

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('message');
  });

  test('can search books', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    const res = await request(app)
      .get('/api/books?search=Test')
      .set('Authorization', `Bearer ${login.token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('data');
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  test('can filter books by category', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    const res = await request(app)
      .get('/api/books?category=Technology')
      .set('Authorization', `Bearer ${login.token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('data');
    // All returned books should have the category
    for (const book of res.body.data) {
      expect(book.category).toBe('Technology');
    }
  });

  test('can delete a book', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip || !testBookId) return;

    const res = await request(app)
      .delete(`/api/books/${testBookId}`)
      .set('Authorization', `Bearer ${login.token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('message');

    // Verify it's deleted
    const verifyRes = await request(app)
      .get(`/api/books/${testBookId}`)
      .set('Authorization', `Bearer ${login.token}`);

    expect(verifyRes.statusCode).toBe(404);
  });

  test('returns 404 for non-existent book', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    const res = await request(app)
      .get('/api/books/999999999')
      .set('Authorization', `Bearer ${login.token}`);

    expect(res.statusCode).toBe(404);
  });
});
