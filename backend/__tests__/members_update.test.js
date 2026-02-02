const { request, app, loginAdminOrSkip } = require('./test_utils');

describe('Members API', () => {
  test('can create, update (faculty + is_active), fetch, and delete a member', async () => {
    const login = await loginAdminOrSkip();
    if (login.skip) return;

    // Create a member to avoid relying on seed data.
    const createRes = await request(app)
      .post('/api/members')
      .set('Authorization', `Bearer ${login.token}`)
      .send({
        name: `Test Member ${Date.now()}`,
        email: `test_${Date.now()}@example.com`,
        phone: '0000000000',
        member_type: 'student',
        membership_date: '2024-01-01',
      });

    expect(createRes.statusCode).toBe(200);
    expect(createRes.body).toHaveProperty('id');

    const memberId = createRes.body.id;

    const updateRes = await request(app)
      .put(`/api/members/${memberId}`)
      .set('Authorization', `Bearer ${login.token}`)
      .send({ member_type: 'faculty', is_active: false });

    expect(updateRes.statusCode).toBe(200);

    const getRes = await request(app)
      .get(`/api/members/${memberId}`)
      .set('Authorization', `Bearer ${login.token}`);

    expect(getRes.statusCode).toBe(200);
    expect(getRes.body).toHaveProperty('member_type', 'faculty');
    // mysql2 may return booleans as 0/1 depending on config.
    expect([0, false]).toContain(getRes.body.is_active);

    const deleteRes = await request(app)
      .delete(`/api/members/${memberId}`)
      .set('Authorization', `Bearer ${login.token}`);
    expect(deleteRes.statusCode).toBe(200);
  });
});
