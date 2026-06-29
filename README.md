# Library Management System

A desktop Library Management System: a Flutter (Windows) front end with an
embedded Node.js/Express backend and a MySQL database. Designed to run on a
**single machine** — the app launches the backend automatically on startup and
talks to it over `localhost`.

## What's in the box

| Layer     | Tech                         | Location        |
|-----------|------------------------------|-----------------|
| Frontend  | Flutter (Windows desktop)    | `flutter_app/`  |
| Backend   | Node.js + Express (TypeScript)| `backend/`     |
| Database  | MySQL 8                      | `database/`     |

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

:: 4. Run the Flutter app (it auto-starts the backend)
cd ..\flutter_app
flutter pub get
flutter run -d windows
```

Default admin login (fresh database): **admin / Library#123**
(you'll be prompted to change it on first login).

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
:: Backend (Jest + integration)
cd backend
npx jest
node integration_test.js   :: requires the server running

:: Frontend
cd flutter_app
flutter test
```
