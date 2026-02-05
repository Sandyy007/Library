/* eslint-disable no-console */

const base = process.env.BASE_URL || 'http://localhost:3000/api';

async function readBody(res) {
  const text = await res.text();
  return text;
}

async function main() {
  // Login (default seed credentials)
  const loginRes = await fetch(`${base}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'Library#123' }),
  });
  const loginBody = await readBody(loginRes);
  if (loginRes.status !== 200) {
    console.log('login status', loginRes.status);
    console.log('login body', loginBody.slice(0, 500));
    throw new Error('Login failed');
  }

  let token;
  let user;
  try {
    const parsed = JSON.parse(loginBody);
    token = parsed?.token;
    user = parsed?.user;
  } catch {
    // ignore
  }
  if (!token) throw new Error('Login did not return a token');

  const userId = user?.id;
  console.log('login user id', userId);

  const authHeaders = {
    Authorization: `Bearer ${token}`,
  };

  // 1) Dashboard activity should not be rate-limited in local desktop usage.
  const actRes = await fetch(`${base}/dashboard/activity?limit=1`, {
    headers: authHeaders,
  });
  const actBody = await readBody(actRes);
  console.log('activity status', actRes.status);
  console.log('activity body', actBody.slice(0, 500));

  // 2) Member updates should persist: member_type + is_active.
  const membersRes = await fetch(`${base}/members`, {
    headers: authHeaders,
  });
  const membersBody = await readBody(membersRes);
  console.log('members status', membersRes.status);

  let members;
  try {
    members = JSON.parse(membersBody);
  } catch {
    console.log('members body', membersBody.slice(0, 500));
    throw new Error('Failed to parse /members response as JSON');
  }

  if (!Array.isArray(members) || members.length === 0) {
    console.log('no members found');
    return;
  }

  const m = members[0];
  console.log('member id', m.id, 'before type', m.member_type, 'is_active', m.is_active);

  let r = await fetch(`${base}/members/${m.id}`, {
    method: 'PUT',
    headers: { ...authHeaders, 'Content-Type': 'application/json' },
    body: JSON.stringify({ member_type: 'faculty' }),
  });
  console.log('set type status', r.status, await readBody(r));

  r = await fetch(`${base}/members/${m.id}`, {
    method: 'PUT',
    headers: { ...authHeaders, 'Content-Type': 'application/json' },
    body: JSON.stringify({ is_active: false }),
  });
  console.log('set inactive status', r.status, await readBody(r));

  // 3) Clear recent activity (requires auth)
  const clearRes = await fetch(`${base}/dashboard/activity/clear`, {
    method: 'POST',
    headers: authHeaders,
  });
  console.log('clear activity status', clearRes.status, await readBody(clearRes));

  if (userId) {
    const settingsRes = await fetch(`${base}/dashboard/settings/${userId}`, {
      headers: authHeaders,
    });
    const settingsBody = await readBody(settingsRes);
    console.log('dashboard settings status', settingsRes.status);
    console.log('dashboard settings body', settingsBody.slice(0, 500));
  }

  // 4) Activity should now be filtered/hide previous items
  const actRes2 = await fetch(`${base}/dashboard/activity?limit=3`, {
    headers: authHeaders,
  });
  const actBody2 = await readBody(actRes2);
  console.log('activity(after clear) status', actRes2.status);
  console.log('activity(after clear) body', actBody2.slice(0, 500));

  const afterRes = await fetch(`${base}/members/${m.id}`, {
    headers: authHeaders,
  });
  const afterBody = await readBody(afterRes);
  console.log('after status', afterRes.status);
  try {
    const after = JSON.parse(afterBody);
    console.log('after type', after.member_type, 'is_active', after.is_active);
  } catch {
    console.log('after body', afterBody.slice(0, 500));
  }
}

main().catch((e) => {
  console.error('SMOKE TEST FAILED:', e && e.stack ? e.stack : e);
  process.exit(1);
});
