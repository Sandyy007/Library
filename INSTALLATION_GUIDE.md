# Installation Guide — Library Management System

This guide covers building the installer and installing the app on a single
Windows machine.

---

## 1. Prerequisites

Install these on the target machine **before** running the setup:

1. **Node.js 18 or later** — https://nodejs.org
   - Verify: open Command Prompt and run `node --version`
2. **MySQL 8 or later** — https://dev.mysql.com/downloads/mysql/
   - During MySQL setup, remember the **root password** you set.
   - Verify: `mysql --version`

> The installer checks for both and will warn you if either is missing, but it
> will still let you continue (you can install them afterwards).

---

## 2. Building the setup executable (for developers)

You need the build toolchain installed:

- **Flutter SDK** (with Windows desktop support enabled)
- **Node.js 18+**
- **Inno Setup 6** — https://jrsoftware.org/isdl.php

Then, from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File Build.ps1 -Installer
```

This performs, in order:

1. `flutter build windows --release` — builds the desktop app.
2. `npm install && npm run build:release` — compiles the TypeScript backend to
   `dist/server.js` and copies it to `backend/server.js` (the launcher path).
3. `npm prune --production` — slims `node_modules` to runtime-only packages.
4. Runs Inno Setup against `installer.iss`.

Output: `installer_output/LibraryManagementSystem_Setup_v<version>.exe`

The setup bundles **everything the app needs to run**:
- The Flutter Windows release (the `.exe` and its DLLs/assets)
- The backend (`server.js` + production `node_modules`)
- The database schema (`database/schema_v2.sql`)
- Documentation

---

## 3. Installing on the target machine

1. Run `LibraryManagementSystem_Setup_v<version>.exe` (as Administrator).
2. On the **Database Configuration** page, enter your MySQL details:
   - **Host:** `localhost`
   - **User:** `root`
   - **Password:** the MySQL root password you chose during MySQL setup
   - **Database Name:** `library_management`
3. (Optional) Tick **Reinitialize database** only if you want to wipe and
   recreate the database — **this deletes existing data.**
4. Finish the wizard. The installer will:
   - Copy all app + backend files to `C:\Program Files\Library Management System`.
   - Generate `backend\.env` with your DB settings and a fresh random
     `JWT_SECRET`, plus a localhost `CORS_ORIGINS` so the backend starts cleanly.
   - Create the `library_management` database and import the schema (if MySQL is
     present).

---

## 4. First run

- Launch from the **Start Menu** or **Desktop** shortcut.
- A **branded splash screen** appears while the app starts the bundled backend
  automatically (on `http://localhost:3000`).
  - If the backend can't start (e.g. MySQL not running or `.env`
    misconfigured), the splash shows a clear error message with a **Retry**
    button. Fix the issue (see Troubleshooting) and tap Retry — no need to
    restart the app.
- Log in with the seeded admin account: **admin / Library#123**
  - You'll be required to change the password on first login.
- When you close the app, the backend it started is stopped automatically so
  port 3000 is freed for the next launch.

---

## 5. Troubleshooting

**Splash screen shows "Couldn't start the app" / connection errors**
- Confirm Node.js is installed: `node --version`.
- Confirm MySQL is running (Services → MySQL → Running).
- Open `C:\Program Files\Library Management System\backend\.env` and verify
  `DB_PASSWORD` matches your MySQL root password. Correct it, then tap **Retry**
  on the splash (or relaunch).
- Ensure `CORS_ORIGINS` is present in `.env` (the installer adds it). If the
  backend log shows `[FATAL] CORS_ORIGINS must be set`, add:
  `CORS_ORIGINS=http://localhost:3000,http://localhost:8080`

**"Access denied for user 'root'@'localhost'"**
- The DB password in `.env` is wrong. Update it and relaunch.

**Port 3000 already in use**
- Another process is using port 3000. Stop it, or change `PORT` in `.env`
  (the app expects 3000 by default).

**Reset the database manually**
```bat
mysql -u root -p < "C:\Program Files\Library Management System\database\schema_v2.sql"
```

---

## 6. Uninstalling

Use **Add/Remove Programs** → *Library Management System*. The uninstaller stops
the backend (port 3000) and removes program files. Your MySQL database and
uploaded files are **not** deleted automatically — drop the database manually if
you want a full cleanup.
