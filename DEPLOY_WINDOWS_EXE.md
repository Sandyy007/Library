# Deploy to another Windows PC as an EXE (frontend + backend + database)

This project is a **Flutter Windows desktop app** + **Node.js backend** + **MySQL**.

Important reality check: **MySQL is a separate database server**. You can ship a single `Setup.exe` installer that installs everything, but it will either:
- (Recommended) **install MySQL Server** (or require it to be pre-installed), then load the schema; and
- install the Flutter app files and a backend runner (Node runtime + backend files).

Trying to “compile MySQL into the app” is not practical for a standard Windows EXE installer.

---

## 1) What you will deliver to the other PC

You will create **one installer**:

- `LibraryManagementSetup.exe` (your installer)

When installed, it will place:
- **Frontend**: the Flutter Windows release files
- **Backend**: the Node backend files + a way to run it (either a bundled portable Node runtime, or an installed Node)
- **Database**: MySQL installed/configured and the schema imported (`database/schema_v2.sql`)

---

## 2) Two deployment styles (choose one)

### A) All-in-one (single PC, offline-friendly)
Everything (MySQL + backend + frontend) runs on the same Windows PC.
- Frontend talks to backend on `http://localhost:3000`
- Backend talks to MySQL on `localhost:3306`

This is easiest for a single-library machine.

### B) Client/Server (multiple PCs)
- One “server PC” runs MySQL + backend.
- Each “client PC” installs only the Flutter desktop app.

This is best if you’ll have multiple client computers.

This guide focuses on **A (All-in-one)** because you asked for “whole app … to other PC”.

---

## 3) Build machine requirements (the PC where you create the EXE)

Install these on the build machine:
- Windows 10/11
- Flutter SDK 3.10+ and Dart (matches `sdk: ^3.10.4`)
- Visual Studio 2022 Build Tools (Desktop development with C++)
- Node.js 16+ (to install backend deps)
- MySQL 8.0+ (optional but useful for testing)
- Inno Setup (to create a single `Setup.exe`) **or** NSIS (either works)

---

## 4) Step-by-step: build the Frontend (Flutter) release

From `flutter_app/`:

1. Fetch dependencies:
   - `flutter pub get`

2. Build Windows release:
   - `flutter build windows --release`

Output folder is typically:
- `flutter_app/build/windows/x64/runner/Release/`

That folder contains `library_management_app.exe` plus required DLLs.

### If backend will be on another machine
Build with API base URL pointing to your server:

- `flutter build windows --release --dart-define=API_BASE_URL=http://SERVER_IP:3000/api --dart-define=API_SERVER_ORIGIN=http://SERVER_IP:3000`

The app’s API URL is controlled in `flutter_app/lib/services/api_service.dart` via `String.fromEnvironment`.

---

## 5) Step-by-step: package the Backend (Node) for an installer

### Recommended approach: ship a portable Node runtime (simplest)
Packaging Node into a single backend EXE is often painful because of native modules (this backend uses `bcrypt` and `mysql2`).

Instead, you can ship:
- `node.exe` (portable Node runtime)
- the backend folder (JS files + `node_modules`)

#### Backend build steps
From `backend/` on the build machine:

1. Install deps (production is enough):
   - `npm install --omit=dev`

2. Create `backend/.env` on the target machine at install-time (or ship a template and let your installer write it).
   Use `backend/.env.example` as your template.

3. You will start the backend using:
- `node backend/server.js`

### Alternative (advanced): compile backend to EXE
Tools like `pkg` may fail with native dependencies.
If you **must** have a single `backend.exe`, you’ll likely need code changes (e.g., replace native `bcrypt` with a pure JS alternative) and then test carefully.

---

## 6) Database: installing MySQL + importing schema

You have two options:

### Option 1 (recommended): installer requires MySQL already installed
- Your `Setup.exe` checks for MySQL or instructs the user to install it.
- Then it runs schema import.

### Option 2: installer installs MySQL silently
- Bundle the MySQL Installer (MSI) in your installer.
- Run a silent install.

Silent install details vary by MySQL package/version, so many teams prefer Option 1.

### Import schema
The schema is in:
- `database/schema_v2.sql`

Import command example:
- `mysql -u root -p < database/schema_v2.sql`

This schema creates database `library_management` and seeds default users.

---

## 7) Create ONE installer EXE (Setup.exe)

### Recommended: Inno Setup
Inno Setup can:
- copy your frontend release folder
- copy backend folder + portable Node
- run post-install commands (schema import)
- create Start Menu shortcuts

#### What your installer should include
Create a staging folder like:

- `dist/`
  - `app/`  (copy Flutter Release output here)
  - `backend/` (copy backend folder here)
  - `runtime/node/` (portable Node)
  - `database/schema_v2.sql`

#### Post-install actions
- Write `backend/.env` using user-provided DB credentials
- Run schema import using `mysql.exe` (requires MySQL client tools in PATH, or bundle `mysql.exe`)
- Add Windows Firewall rule for backend port `3000` (optional)

---

## 8) How the target PC runs it

All-in-one default (same PC):
- Start backend on `http://localhost:3000`
- Launch the Flutter EXE

You can also install the backend as a Windows service (advanced) using NSSM, or start it on login.

---

## 9) Troubleshooting checklist

- Backend starts but Flutter can’t login:
  - Confirm backend is reachable at `http://localhost:3000/api`
  - Confirm Windows firewall allows port `3000`

- Backend can’t connect to DB:
  - Validate `backend/.env` values
  - Confirm MySQL service is running
  - Confirm DB `library_management` exists and tables are created

- Images/uploads missing:
  - Ensure `backend/uploads/` exists and is writable

---

## 10) Quick commands (for your internal testing)

Backend:
- `cd backend`
- `npm install`
- Create `backend/.env`
- `npm start`

Flutter:
- `cd flutter_app`
- `flutter pub get`
- `flutter run -d windows`
