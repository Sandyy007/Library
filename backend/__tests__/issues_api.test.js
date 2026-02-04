const { request, app, loginAdminOrSkip } = require('./test_utils');

describe('Issues API', () => {
  let testIssueId = null;
  let testBookId = null;
  let testMemberId = null;

  beforeAll(async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    // Create a test book
    const bookRes = await request(app)
      .post('/api/books')
      .set('Authorization', `Bearer ${login.token}`)
      .send({
        isbn: `ISSUE-TEST-${Date.now()}`,
        title: `Issue Test Book ${Date.now()}`,
        author: 'Issue Test Author',
        category: 'Fiction',
        total_copies: 3,
      });
    testBookId = bookRes.body?.id;

    // Create a test member
    const memberRes = await request(app)
      .post('/api/members')
      .set('Authorization', `Bearer ${login.token}`)
      .send({
        name: `Issue Test Member ${Date.now()}`,
        email: `issue_test_${Date.now()}@test.com`,
        phone: '1111111111',
        member_type: 'student',
        membership_date: new Date().toISOString().split('T')[0],
      });
    testMemberId = memberRes.body?.id;
  });

  afterAll(async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    // Cleanup test book and member
    if (testBookId) {
      await request(app)
        .delete(`/api/books/${testBookId}`)
        .set('Authorization', `Bearer ${login.token}`);
    }
    if (testMemberId) {
      await request(app)
        .delete(`/api/members/${testMemberId}`)
        .set('Authorization', `Bearer ${login.token}`);
    }
  });

  test('can list issues with pagination', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    const res = await request(app)
      .get('/api/issues?page=1&limit=10')
      .set('Authorization', `Bearer ${login.token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('data');
    expect(res.body).toHaveProperty('pagination');
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  test('can create a new issue', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip || !testBookId || !testMemberId) return;

    const dueDate = new Date();
    dueDate.setDate(dueDate.getDate() + 14);

    const res = await request(app)
      .post('/api/issues')
      .set('Authorization', `Bearer ${login.token}`)
      .send({
        book_id: testBookId,
        member_id: testMemberId,
        due_date: dueDate.toISOString().split('T')[0],
      });

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('id');
    expect(res.body).toHaveProperty('book_id', testBookId);
    expect(res.body).toHaveProperty('member_id', testMemberId);
    expect(res.body).toHaveProperty('status', 'issued');
    testIssueId = res.body.id;
  });

  test('can return an issued book', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip || !testIssueId) return;

    const res = await request(app)
      .put(`/api/issues/${testIssueId}/return`)
      .set('Authorization', `Bearer ${login.token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('message');
  });

  test('can filter issues by status', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    const res = await request(app)
      .get('/api/issues?status=returned')
      .set('Authorization', `Bearer ${login.token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('data');
    // All returned issues should have the status
    for (const issue of res.body.data) {
      expect(issue.status).toBe('returned');
    }
  });

  test('cannot issue book that has no available copies', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    // Create a book with 0 copies
    const bookRes = await request(app)
      .post('/api/books')
      .set('Authorization', `Bearer ${login.token}`)
      .send({
        isbn: `NO-COPIES-${Date.now()}`,
        title: `No Copies Book ${Date.now()}`,
        author: 'Test',
        category: 'Fiction',
        total_copies: 0,
        available_copies: 0,
      });

    if (bookRes.body?.id) {
      const dueDate = new Date();
      dueDate.setDate(dueDate.getDate() + 14);

      const res = await request(app)
        .post('/api/issues')
        .set('Authorization', `Bearer ${login.token}`)
        .send({
          book_id: bookRes.body.id,
          member_id: testMemberId,
          due_date: dueDate.toISOString().split('T')[0],
        });

      expect(res.statusCode).toBe(400);

      // Cleanup
      await request(app)
        .delete(`/api/books/${bookRes.body.id}`)
        .set('Authorization', `Bearer ${login.token}`);
    }
  });
});
