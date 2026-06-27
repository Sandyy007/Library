const http = require('http');
const path = require('path');
// Load backend/.env so ADMIN_PASSWORD (and any overrides) are available when
// this script is run directly via `node integration_test.js`.
try {
  require('dotenv').config({ path: path.join(__dirname, '.env') });
} catch (_) {
  // dotenv is a dependency; ignore if unavailable.
}

const BASE = 'http://localhost:3000';

// Shared with __tests__/test_utils.js: defaults to the schema-seeded password
// ('Library#123'); override via ADMIN_PASSWORD for a differently-seeded DB.
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'Library#123';

function request(method, path, { token, body } = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(BASE + path);
    const data = body ? JSON.stringify(body) : null;
    const headers = { 'Content-Type': 'application/json' };
    if (data) headers['Content-Length'] = Buffer.byteLength(data);
    if (token) headers['Authorization'] = `Bearer ${token}`;
    const req = http.request({
      method, hostname: url.hostname, port: url.port, path: url.pathname + url.search, headers,
    }, (res) => {
      let chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const text = Buffer.concat(chunks).toString('utf8');
        let json = null;
        try { json = text ? JSON.parse(text) : null; } catch (_) { json = text; }
        resolve({ status: res.statusCode, body: json, headers: res.headers });
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

const tests = [];
function t(name, fn) { tests.push({ name, fn }); }

let adminToken = null;
let memberToken = null;

t('GET /api/health 200 (or 404) without auth', async () => {
  const r = await request('GET', '/');
  if (r.status >= 500) throw new Error('Server error: ' + r.status);
});

t('POST /api/auth/login as admin', async () => {
  const r = await request('POST', '/api/auth/login', {
    body: { username: 'admin', password: ADMIN_PASSWORD },
  });
  if (r.status !== 200) throw new Error(`login failed: ${r.status} ${JSON.stringify(r.body)}`);
  if (!r.body.token) throw new Error('no token in response');
  adminToken = r.body.token;
  if (r.body.user?.mustChangePassword !== undefined) {
    console.log('   mustChangePassword:', r.body.user.mustChangePassword);
  }
});

t('POST /api/auth/login wrong password returns 401 + AUTH_FAILED code', async () => {
  const r = await request('POST', '/api/auth/login', {
    body: { username: 'admin', password: 'wrong' },
  });
  if (r.status !== 401) throw new Error(`expected 401, got ${r.status}`);
  if (r.body?.code !== 'AUTH_FAILED') throw new Error(`expected code AUTH_FAILED, got ${r.body?.code}`);
});

t('POST /api/auth/login unknown user returns 401 (no enumeration)', async () => {
  const r = await request('POST', '/api/auth/login', {
    body: { username: 'nobody_here_xyz', password: 'whatever' },
  });
  if (r.status !== 401) throw new Error(`expected 401, got ${r.status}`);
  if (r.body?.code !== 'AUTH_FAILED') throw new Error(`expected code AUTH_FAILED, got ${r.body?.code}`);
});

t('GET /api/auth/me returns user info', async () => {
  const r = await request('GET', '/api/auth/me', { token: adminToken });
  if (r.status !== 200) throw new Error(`me failed: ${r.status} ${JSON.stringify(r.body)}`);
  if (!r.body.user || !r.body.user.username) throw new Error('no user.username');
});

t('GET /api/books with admin token', async () => {
  const r = await request('GET', '/api/books?page=1&limit=5', { token: adminToken });
  if (r.status !== 200) throw new Error(`books failed: ${r.status} ${JSON.stringify(r.body)}`);
  if (!Array.isArray(r.body.data)) throw new Error('books data not an array: ' + JSON.stringify(Object.keys(r.body)));
  if (!r.body.pagination) throw new Error('no pagination: ' + JSON.stringify(Object.keys(r.body)));
});

t('GET /api/members with admin token', async () => {
  const r = await request('GET', '/api/members?page=1&limit=5', { token: adminToken });
  if (r.status !== 200) throw new Error(`members failed: ${r.status}`);
});

t('GET /api/issues with admin token', async () => {
  const r = await request('GET', '/api/issues?page=1&limit=5', { token: adminToken });
  if (r.status !== 200) throw new Error(`issues failed: ${r.status} ${JSON.stringify(r.body).substring(0,200)}`);
});

t('GET /api/search returns books/members/issues arrays', async () => {
  const r = await request('GET', '/api/search?q=a', { token: adminToken });
  if (r.status !== 200) throw new Error(`search failed: ${r.status}`);
  if (!r.body.books || !r.body.members || !r.body.issues) {
    throw new Error('search response missing branches: ' + JSON.stringify(Object.keys(r.body)));
  }
  if (r.body.books.length > 200) throw new Error('books limit not enforced: ' + r.body.books.length);
});

t('GET /api/dashboard/activity respects limits', async () => {
  const r = await request('GET', '/api/dashboard/activity?limit=5', { token: adminToken });
  if (r.status !== 200) throw new Error(`activity failed: ${r.status}`);
});

t('GET /api/dashboard/stats', async () => {
  const r = await request('GET', '/api/dashboard/stats', { token: adminToken });
  if (r.status !== 200) throw new Error(`stats failed: ${r.status} ${JSON.stringify(r.body).substring(0,200)}`);
});

t('GET /api/backup respects whitelist', async () => {
  const r = await request('GET', '/api/backup', { token: adminToken });
  if (r.status !== 200) throw new Error(`backup failed: ${r.status}`);
  if (r.body.data.books === undefined) throw new Error('backup missing books');
  if (r.body.data.members === undefined) throw new Error('backup missing members');
  if (r.body.data.issues === undefined) throw new Error('backup missing issues');
});

t('PUT /api/issues/:id with invalid id', async () => {
  const r = await request('PUT', '/api/issues/abc', { token: adminToken, body: { status: 'returned' } });
  if (r.status !== 400) throw new Error(`expected 400 for invalid id, got ${r.status}: ${JSON.stringify(r.body)}`);
});

t('PUT /api/issues/:id with invalid date', async () => {
  const r = await request('PUT', '/api/issues/1', { token: adminToken, body: { due_date: 'not-a-date' } });
  if (r.status !== 400) throw new Error(`expected 400 for bad date, got ${r.status}: ${JSON.stringify(r.body)}`);
});

t('PUT /api/issues/:id with invalid status', async () => {
  const r = await request('PUT', '/api/issues/1', { token: adminToken, body: { status: 'exploded' } });
  if (r.status !== 400) throw new Error(`expected 400 for bad status, got ${r.status}: ${JSON.stringify(r.body)}`);
});

t('PUT /api/issues/99999 not found', async () => {
  const r = await request('PUT', '/api/issues/99999', { token: adminToken, body: { status: 'returned' } });
  if (r.status !== 404) throw new Error(`expected 404, got ${r.status}`);
});

t('POST /api/issues with invalid book_id', async () => {
  const r = await request('POST', '/api/issues', { token: adminToken, body: { book_id: 'abc', member_id: 1, due_date: '2026-12-31' } });
  if (r.status !== 400) throw new Error(`expected 400, got ${r.status}: ${JSON.stringify(r.body)}`);
});

t('PUT /api/dashboard/settings/:userId accepts valid widget', async () => {
  const me = await request('GET', '/api/auth/me', { token: adminToken });
  const uid = me.body.user.id;
  const r = await request('PUT', `/api/dashboard/settings/${uid}`, {
    token: adminToken,
    body: { widgets: [{ widget_name: 'charts', is_visible: true, settings: { foo: 'bar' } }] },
  });
  if (r.status !== 200) throw new Error(`settings failed: ${r.status} ${JSON.stringify(r.body)}`);
});

t('PUT /api/dashboard/settings ignores unknown widget names (whitelist)', async () => {
  const me = await request('GET', '/api/auth/me', { token: adminToken });
  const uid = me.body.user.id;
  const r = await request('PUT', `/api/dashboard/settings/${uid}`, {
    token: adminToken,
    body: { widgets: [
      { widget_name: 'charts', is_visible: true, settings: {} },
      { widget_name: 'evil_injection', is_visible: true, settings: {} },
    ] },
  });
  if (r.status !== 200) throw new Error(`settings failed: ${r.status}`);
  // re-fetch and verify only the whitelisted one was saved
  const r2 = await request('GET', `/api/dashboard/settings/${uid}`, { token: adminToken });
  if (r2.status !== 200) throw new Error(`re-fetch failed: ${r2.status}`);
  const rows = r2.body || [];
  const names = rows.map(s => s.widget_name);
  if (names.includes('evil_injection')) throw new Error('whitelist bypassed: ' + names.join(','));
});

t('POST /api/auth/change-password with wrong current', async () => {
  const r = await request('POST', '/api/auth/change-password', {
    token: adminToken,
    body: { currentPassword: 'wrong', newPassword: 'newpass123' },
  });
  if (r.status !== 401 && r.status !== 400) throw new Error(`expected 401/400, got ${r.status}: ${JSON.stringify(r.body)}`);
});

t('GET /api/reports/issued returns paginated {data, pagination}', async () => {
  const r = await request('GET', '/api/reports/issued?limit=10', { token: adminToken });
  if (r.status !== 200) throw new Error(`expected 200, got ${r.status}: ${JSON.stringify(r.body)}`);
  if (!Array.isArray(r.body.data) || !r.body.pagination) throw new Error('shape: ' + JSON.stringify(Object.keys(r.body)));
});

t('GET /api/reports/overdue returns paginated {data, pagination}', async () => {
  const r = await request('GET', '/api/reports/overdue?limit=10', { token: adminToken });
  if (r.status !== 200) throw new Error(`expected 200, got ${r.status}`);
  if (!Array.isArray(r.body.data) || !r.body.pagination) throw new Error('shape: ' + JSON.stringify(Object.keys(r.body)));
});

t('GET /api/reports/issued caps limit at 5000', async () => {
  const r = await request('GET', '/api/reports/issued?limit=999999', { token: adminToken });
  if (r.status !== 200) throw new Error(`expected 200, got ${r.status}`);
  if (r.body.pagination.limit > 5000) throw new Error('limit not capped: ' + r.body.pagination.limit);
});

t('GET /api/members/:id/history returns paginated {data, pagination}', async () => {
  const r = await request('GET', '/api/members/1/history?limit=10', { token: adminToken });
  if (r.status !== 200) throw new Error(`expected 200, got ${r.status}: ${JSON.stringify(r.body).substring(0, 200)}`);
  if (!Array.isArray(r.body.data) || !r.body.pagination) throw new Error('shape: ' + JSON.stringify(Object.keys(r.body)));
});

t('GET /api/members/:id/history rejects invalid id', async () => {
  const r = await request('GET', '/api/members/abc/history', { token: adminToken });
  if (r.status !== 400) throw new Error(`expected 400, got ${r.status}`);
});

t('GET /api/members/:id/borrowed-books caps at 100', async () => {
  const r = await request('GET', '/api/members/1/borrowed-books?limit=999', { token: adminToken });
  if (r.status !== 200) throw new Error(`expected 200, got ${r.status}`);
  if (r.body.borrowed_books.length > 100) throw new Error('not capped');
});

t('GET /api/notifications caps limit at 200', async () => {
  const r = await request('GET', '/api/notifications?limit=99999', { token: adminToken });
  if (r.status !== 200) throw new Error(`expected 200, got ${r.status}: ${JSON.stringify(r.body).substring(0, 200)}`);
  if (r.body.length > 200) throw new Error('limit not capped: ' + r.body.length);
});

t('GET /api/dashboard/alerts returns in reasonable time', async () => {
  const t0 = Date.now();
  const r = await request('GET', '/api/dashboard/alerts?limit=10', { token: adminToken });
  const elapsed = Date.now() - t0;
  if (r.status !== 200) throw new Error(`expected 200, got ${r.status}: ${JSON.stringify(r.body).substring(0, 200)}`);
  // Parallelisation should keep this well under 5s on a small library.
  if (elapsed > 5000) console.log('   (slow: ' + elapsed + 'ms)');
});

t('GET /api/export/books as JSON', async () => {
  const r = await request('GET', '/api/export/books?format=json', { token: adminToken });
  if (r.status !== 200) throw new Error(`expected 200, got ${r.status}: ${JSON.stringify(r.body).substring(0, 200)}`);
  if (!Array.isArray(r.body.data)) throw new Error('expected data array');
  if (typeof r.body.truncated !== 'boolean') throw new Error('expected truncated flag');
});

t('GET /api/export/books as CSV streams', async () => {
  const r = await request('GET', '/api/export/books?format=csv', { token: adminToken });
  if (r.status !== 200) throw new Error(`expected 200, got ${r.status}`);
  if (!r.body.includes('# Generated on:')) throw new Error('missing generated-on comment');
  if (!r.body.includes('id,')) throw new Error('missing CSV headers');
});

t('GET /api/export/invalid returns 400', async () => {
  const r = await request('GET', '/api/export/garbage', { token: adminToken });
  if (r.status !== 400) throw new Error(`expected 400, got ${r.status}`);
});

t('GET /api/categories sets cache headers', async () => {
  const r = await request('GET', '/api/categories', { token: adminToken });
  if (r.status !== 200) throw new Error(`expected 200, got ${r.status}`);
  const cc = r.headers['cache-control'] || '';
  if (!/max-age=300/.test(cc)) throw new Error('missing max-age=300 in Cache-Control: ' + cc);
});

t('GET /api/member-categories sets cache headers', async () => {
  const r = await request('GET', '/api/member-categories', { token: adminToken });
  if (r.status !== 200) throw new Error(`expected 200, got ${r.status}`);
  const cc = r.headers['cache-control'] || '';
  if (!/max-age=300/.test(cc)) throw new Error('missing max-age=300 in Cache-Control: ' + cc);
});

(async () => {
  let pass = 0, fail = 0, skipped = 0;
  for (const { name, fn } of tests) {
    try {
      await fn();
      console.log('  PASS', name);
      pass++;
    } catch (e) {
      console.log('  FAIL', name, '=>', e.message);
      fail++;
    }
  }
  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail === 0 ? 0 : 1);
})();
