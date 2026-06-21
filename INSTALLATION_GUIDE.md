# UPSTTRI Library Management System - Installation & Operator Guide

> This application is designed for **local single-PC use** at Uttar Pradesh State
> Tax Training & Research Institute. Everything (desktop app, backend API, and
> MySQL database) runs on **one Windows computer**. There is no cloud server,
> remote access, or network exposure to configure.

## Table of Contents

1. [What Gets Installed](#what-gets-installed)
2. [Prerequisites](#prerequisites)
3. [Quick Install (Recommended)](#quick-install-recommended)
4. [First Launch & Login](#first-launch--login)
5. [Acceptance Checklist (UAT)](#acceptance-checklist-uat)
6. [Backups](#backups)
7. [Troubleshooting](#troubleshooting)
8. [For Developers (Build From Source)](#for-developers-build-from-source)

---

## What Gets Installed

The single installer (`LibraryManagementSystem_Setup_v1.1.2.exe`) bundles three
parts onto the local PC:

| Component | Role | Location after install |
|-----------|------|------------------------|
| Flutter desktop app | The window the operator uses | `C:\Program Files\Library Management System\` |
| Node.js backend (`server.js`) | Local API the app talks to on `http://localhost:3000` | `...\Library Management System\backend\` |
| MySQL database | Stores all books, members, issues, users | Your local MySQL server (`library_management` schema) |

The desktop app automatically starts the bundled backend when it launches, so the
operator only ever opens **one icon**.

---

## Prerequisites

Install these **once** on the PC before running the setup. The installer detects
them and will warn you if either is missing.

1. **Node.js 18 or later** — https://nodejs.org (choose the LTS build).
2. **MySQL 8.0 or later** — https://dev.mysql.com/downloads/mysql/
   - During MySQL setup, remember the **root password** you choose. The default
     this app expects is `admin`, but any password works as long as you enter it
     on the installer's database page.

> Minimum machine: Windows 10/11 64-bit, 4 GB RAM, 2 GB free disk.

---

## Quick Install (Recommended)

1. Double-click `LibraryManagementSystem_Setup_v1.1.2.exe` and accept the admin
   prompt.
2. On the **Database Configuration** page, confirm or change:
   - MySQL Host: `localhost`
   - MySQL User: `root`
   - MySQL Password: *(the password you set when installing MySQL — default `admin`)*
   - Database Name: `library_management`
3. Leave **"Reinitialize database"** unchecked for a normal install. Check it
   **only** on a fresh machine or when you intentionally want to wipe all data.
4. Finish the wizard. The installer will:
   - Copy the app + backend + `node_modules`.
   - Generate `backend\.env` with a fresh random `JWT_SECRET`.
   - Create the `library_management` database and import the schema.
5. Launch the app from the desktop/Start Menu shortcut.

That's it — no manual `.env` editing, no separate server to start.

---

## First Launch & Login

Default administrator account (created by the schema/seed):

- **Username:** `admin`
- **Password:** `Library#123`

You will be **forced to set a new password on first login**. Choose a strong
password and record it somewhere safe — there is no email-based reset on a local
install.

---

## Acceptance Checklist (UAT)

Run through this once after install to confirm the system is healthy:

- [ ] App opens and shows the login screen (no "connection refused" banner).
- [ ] Login with `admin` / `Library#123` works and prompts for a new password.
- [ ] Dashboard loads with counters and charts.
- [ ] Add a test **Book** → it appears in the Books list.
- [ ] Add a test **Member** → it appears in the Members list.
- [ ] Issue the test book to the test member → it shows under Issues.
- [ ] Return the issued book → status updates correctly.
- [ ] Download a **Borrow Slip PDF** → the organization name is present and readable.
- [ ] Export a report as **PDF**, **Excel**, and **CSV** → dates are formatted correctly (DD-MM-YYYY).
- [ ] Toggle **Dark Mode** → UI remains readable, no broken colors.
- [ ] Switch a record to a **Hindi** name → text renders cleanly in lists and slips.
- [ ] Close and reopen the app → data persists (confirms DB is wired correctly).

If every box passes, the system is ready to hand to the client.

---

## Backups

All data lives in the local MySQL `library_management` database plus uploaded
images in `...\Library Management System\backend\uploads\`.

**Recommended weekly backup (run in Command Prompt):**

```bat
mysqldump -u root -p library_management > library_backup_%date:~-4%-%date:~3,2%-%date:~0,2%.sql
```

Also copy the `backend\uploads\` folder. To restore:

```bat
mysql -u root -p library_management < library_backup_YYYY-MM-DD.sql
```

---

## Troubleshooting

#### App shows "Connection refused" / backend not reachable

- Confirm MySQL service is running (Windows Services → `MySQL80`).
- Confirm Node.js is installed: open Command Prompt and run `node --version`.
- Manually start the backend to see errors: run
  `...\Library Management System\backend\StartBackend.bat` and read the console.

#### "Access denied for user 'root'"

- The MySQL password in `backend\.env` doesn't match your MySQL install. Open
  `backend\.env`, fix `DB_PASSWORD=`, and relaunch the app.

#### Port 3000 already in use

- Another copy of the backend is running. Close all app windows, or in Command
  Prompt run:
  `FOR /F "tokens=5" %a IN ('netstat -ano ^| findstr :3000') DO taskkill /F /PID %a`

#### Database is empty after install

- Re-run the installer and tick **"Reinitialize database"** (this wipes and
  recreates the schema). Only do this on a machine with no real data yet.

---

## For Developers (Build From Source)

These steps are only for rebuilding the installable artifacts; operators do not
need them.

### Project Layout

```
library_management_system/
├── backend/            # Node.js / TypeScript API (server.ts -> dist/server.js -> server.js)
├── flutter_app/        # Flutter Windows desktop app
├── database/           # schema.sql, schema_v2.sql
├── installer.iss       # Inno Setup script (bundles everything)
├── BuildRelease.bat    # One-shot release build
└── Build.ps1           # PowerShell release build
```

### Backend

```bat
cd backend
npm install
npm run build:release   :: tsc -> dist/server.js, then bundle to backend/server.js
npm test                :: requires local MySQL (DB_PASSWORD=admin)
```

- `npm run dev` runs `tsx watch server.ts` for live development.
- `build:release` is what the installer depends on — it produces the
  `backend\server.js` that `installer.iss` ships.

### Flutter App

```bat
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

Release output: `flutter_app\build\windows\x64\runner\Release\`.

### Packaging the Installer

1. Build the backend release: `BuildRelease.bat` (or `Build.ps1`).
2. Build the Flutter release: `flutter build windows --release`.
3. Compile the installer with Inno Setup 6:

   ```bat
   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
   ```

   Output: `installer_output\LibraryManagementSystem_Setup_v1.1.2.exe`.

> The installer auto-generates `backend\.env` (including a random `JWT_SECRET`)
> on the target machine, so no secrets are committed to source control.

---

## Configuration Reference

`backend\.env` keys (generated by the installer, edit only if troubleshooting):

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | localhost | MySQL host |
| `DB_USER` | root | MySQL user |
| `DB_PASSWORD` | admin | MySQL password (set during install) |
| `DB_NAME` | library_management | Database name |
| `PORT` | 3000 | Local API port |
| `JWT_SECRET` | (random) | Auto-generated per install |
| `JWT_EXPIRES_IN` | 8h | Login session length |

---

## License

Proprietary software for Uttar Pradesh State Tax Training & Research Institute.

**Version:** 1.1.2
**Last Updated:** June 2026
