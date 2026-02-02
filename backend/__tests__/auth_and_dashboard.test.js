const { request, app, loginAdminOrSkip } = require('./test_utils');

describe('Auth + Dashboard APIs', () => {
  test('rejects /api/auth/me without token', async () => {
    const res = await request(app).get('/api/auth/me');
    expect([401, 403]).toContain(res.statusCode);
  });

  test('login works and /api/auth/me returns current user', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${login.token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('user');
    expect(res.body.user).toHaveProperty('id');
    expect(res.body.user).toHaveProperty('username');
    expect(res.body.user).toHaveProperty('role', 'admin');
  });

  test('dashboard settings are restricted to same user', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    const myId = login.user?.id;
    expect(typeof myId).toBe('number');

    const ok = await request(app)
      .get(`/api/dashboard/settings/${myId}`)
      .set('Authorization', `Bearer ${login.token}`);
    expect(ok.statusCode).toBe(200);

    const other = await request(app)
      .get('/api/dashboard/settings/999999')
      .set('Authorization', `Bearer ${login.token}`);
    expect([403, 400]).toContain(other.statusCode);
  });

  test('dashboard activity clear hides older activity', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    const before = await request(app)
      .get('/api/dashboard/activity?limit=25')
      .set('Authorization', `Bearer ${login.token}`);
    expect(before.statusCode).toBe(200);
    expect(Array.isArray(before.body)).toBe(true);

    const clear = await request(app)
      .post('/api/dashboard/activity/clear')
      .set('Authorization', `Bearer ${login.token}`);
    expect(clear.statusCode).toBe(200);
    expect(clear.body).toHaveProperty('hidden_before');

    const after = await request(app)
      .get('/api/dashboard/activity?limit=25')
      .set('Authorization', `Bearer ${login.token}`);
    expect(after.statusCode).toBe(200);
    expect(Array.isArray(after.body)).toBe(true);

    const cutoff = clear.body.hidden_before;
    // If anything exists after clear, it must be >= cutoff.
    for (const row of after.body) {
      expect(row).toHaveProperty('occurred_at');
      // MySQL DATETIME string compares lexicographically in same format.
      expect(String(row.occurred_at) >= String(cutoff)).toBe(true);
    }
  });
});
