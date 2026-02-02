# QA Report (Feb 2, 2026)

This document captures the automated test additions, security hardening, and a short set of recommendations for making the system more reliable in production.

## What Changed

### Backend (Node/Express)
- Added Jest + Supertest test harness and initial API test coverage.
- Refactored backend startup so the Express app can be imported for tests without binding a TCP port.
- Hardened dashboard settings endpoints so a user can only read/write their own dashboard settings.

### Flutter (Windows desktop)
- Made `AuthProvider` testable by allowing injection of API functions (login/me/token/logout).
- Added widget tests for `LoginScreen` and unit tests for `Book.fromJson` behaviors.

## How To Run Tests

### Backend
From the repo root:
- `cd backend`
- `npm install`
- `npm run test:jest`

Notes:
- These tests exercise real API routes against the in-process Express app.
- The tests assume a working MySQL database with an admin user `admin/admin` (as shipped in `database/schema_v2.sql`).

### Flutter
From the repo root:
- `cd flutter_app`
- `flutter pub get`
- `flutter test`

## Security & Access Control

### Fixed
- Dashboard settings user isolation: `/api/dashboard/settings/:userId` now enforces `:userId == req.user.id`.

### Recommended (next)
- Move from a single `mysql2.createConnection` to a `mysql2.createPool` for better concurrency and reliability.
- Add request logging with correlation IDs (especially for desktop clients) and log rotation.
- Review production CORS allowlist (`CORS_ORIGINS`) and disable permissive defaults.
- Keep `JWT_SECRET` required in production (already enforced) and rotate periodically.

## Database / Schema Notes

### Current state
- `database/schema_v2.sql` includes strong defaults: utf8mb4, useful indexes, and per-user `dashboard_settings`.

### Recommended (next)
- Add/confirm composite indexes that match frequent queries:
  - `issues(status, due_date)` for overdue/due-soon queries.
  - `issues(member_id, issue_date)` for member history.
- Consider upgrading `issues.issue_date/return_date/membership_date` from DATE to DATETIME if you want precise event ordering (currently mitigated in the dashboard activity feed by casting).

## Dependency Health

- `npm install` reports high severity vulnerabilities via `npm audit`.
- Recommendation: run `cd backend; npm audit` and decide whether to apply `npm audit fix` (avoid `--force` unless you validate imports/exports and file parsing behavior).

## Deliverables Added

Backend:
- `backend/jest.config.js`
- `backend/jest.setup.js`
- `backend/__tests__/auth_and_dashboard.test.js`
- `backend/__tests__/members_update.test.js`
- `backend/__tests__/test_utils.js`

Flutter:
- `flutter_app/test/login_screen_test.dart`
- `flutter_app/test/book_model_test.dart`

