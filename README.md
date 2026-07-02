# Library Management System

A premium desktop Library Management System: a Flutter (Windows) front end with
an embedded Node.js/Express backend and a MySQL database. Designed to run on a
**single machine** — the app shows a branded splash while it launches the
backend automatically on startup, then talks to it over `localhost`.

## What's in the box

| Layer     | Tech                          | Location        |
|-----------|-------------------------------|-----------------|
| Frontend  | Flutter (Windows desktop)     | `flutter_app/`  |
| Backend   | Node.js + Express (TypeScript)| `backend/`      |
| Database  | MySQL 8                       | `database/`     |
| Docs      | User Manual, SDLC, GeM spec   | `docs/`         |

## Features

- **Book catalogue** — add/edit/search books with ISBN, author, publisher,
  year, rack number, cover image, description, and multiple copies per title.
- **Member management** — profiles with photos, contact details, membership
  validity, activate/deactivate, borrowing history, and configurable member
  categories (student, faculty, staff, guest, and official designations).
- **Issue & return** — automatic due-date calculation, per-category borrowing
  limits, overdue/due-soon tracking, and printable borrow slips.
- **Categories** — manage book and member categories with distinct rules.
- **Bulk import** — import books/members from CSV and Excel (XLSX), tuned for
  large datasets (10,000+ rows).
- **Reports & dashboard** — customizable widgets, animated stat counters, and
  reports for issued/overdue/popular books and active members.
- **Notifications** — in-app notification centre with an animated bell, badge,
  and chime on new alerts (overdue, due-soon, etc.).
- **Backup & restore** — export/import all data as JSON.
- **Security** — JWT auth, bcrypt password hashing, forced first-login password
  change, rate limiting, Helmet headers, and input validation.
- **Premium UI** — branded boot splash, consistent premium dialogs, branded
  toasts, light/dark themes, smooth page transitions, and Hindi/Devanagari
  text support.

## Prerequisites (single machine)

- **Windows 10/11 (x64)**
- **Node.js 18+** — https://nodejs.org  (the backend runs on this)
- **MySQL 8+** — https://dev.mysql.com/downloads/mysql/  (data store)

The installer detects these and warns if they're missing.

## Quick start (from source)

```bat
:: 1. Backend deps + build
cd backend
npm install
npm run build:release

:: 2. Create the database (run once)
mysql -u root -p < ..\database\schema_v2.sql

:: 3. Configure backend\.env (copy the example, set real values)
copy .env.example .env

:: 4. Run the Flutter app (it shows a splash and auto-starts the backend)
cd ..\flutter_app
flutter pub get
flutter run -d windows
```

Default admin login (fresh database): **admin / Library#123**
(you'll be prompted to change it on first login).

## Startup behaviour

On launch the app displays a branded splash screen while it starts the bundled
backend (`http://localhost:3000`). If the backend can't start — for example
MySQL isn't running or `backend/.env` is misconfigured — the splash shows a
clear error with a **Retry** button instead of a blank window. When the app is
closed, the backend it started is shut down automatically.

## Building the installer (final .exe)

Use the build script — it builds the Flutter release, compiles + bundles the
backend, prunes to production dependencies, and runs Inno Setup:

```powershell
powershell -ExecutionPolicy Bypass -File Build.ps1 -Installer
```

The setup executable is written to `installer_output/`.
See **INSTALLATION_GUIDE.md** for full details.

## Tests

```bat
:: Backend — Jest unit/API suite
cd backend
npx jest

:: Backend — integration smoke test (requires the server running)
node integration_test.js

:: Frontend — Flutter widget/unit suite
cd ..\flutter_app
flutter test
```

The Flutter suite under `flutter_app/test/` covers models, providers, API
services, responsiveness, and premium UI widgets (dialogs, toasts, press/hover
micro-interactions). The backend suite under `backend/__tests__/` covers the
auth, books, members, issues, categories, reports, search, notifications, and
health APIs.

## Documentation

- `docs/User_Manual.pdf` — end-user guide
- `docs/SDLC_Document.pdf` — software development lifecycle document
- `docs/GeM_Product_Specification.html` — product/technical spec for GeM listing
- `INSTALLATION_GUIDE.md` — build and installation instructions
