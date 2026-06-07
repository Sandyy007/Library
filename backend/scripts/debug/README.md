# Debug Scripts

One-off debugging and inspection scripts that were originally scattered in
`backend/`. They are NOT part of the application or its test suite — keep them
here for future debugging sessions, but don't depend on them in CI.

The actual test suite lives in `backend/__tests__/` and the integration
smoke test is `backend/integration_test.js` (run with `node integration_test.js`
while the server is up).

## Files

| File | Purpose |
| ---- | ------- |
| `api_test.js` | Legacy single-endpoint HTTP smoke test |
| `test_all_apis.js` | Older multi-endpoint smoke test |
| `test_api.js`, `simple_test.js` | Throwaway endpoint probes |
| `test_connection.js`, `test_db.js` | MySQL connection sanity checks |
| `test_data.js`, `test_hash.js` | Fixture/hash utilities |
| `test_server.js` | One-off server boot test |
| `hash.js`, `update_password.js` | bcrypt hash + admin-password reset helpers |
| `tool/api_smoke_test.js` | Older smoke runner |
| `tool/generate_test_csv.js` | CSV fixture generator |
| `tool/test_large_import.js` | Bulk-import performance probe |

## Authoritative Suite

- `backend/__tests__/` — Jest test suite (run with `npm test` from `backend/`)
- `backend/integration_test.js` — integration smoke test
