# UPSTTRI Library Management System

A production-ready desktop **Library Management System** for **Uttar Pradesh State Tax Training & Research Institute**, built with **Flutter (Windows Desktop)** and **Node.js + Express + MySQL** backend.

It provides end-to-end book, member, and issue/return workflows together with advanced reporting, real-time notifications, data backup/restore, PDF/CSV export, and a fully responsive, premium admin interface.

---

## Key Features

### Premium UI/UX
- **Premium Sidebar** - Diagonal gradient header, decorative circles, glowing logo container, frosted badge
- **Dashboard** - Real-time KPI cards, animated stat cards, bar/pie charts, actionable alerts
- **Actionable Alerts** - Overdue, due today, low stock with color-coded sections
- **Recent Activity** - Live feed with auto-refresh
- **Dark/Light Theme** - Material 3 toggle with smooth transitions
- **Premium Popups** - Gradient headers, pagination, hover effects

### Authentication & Security
- Admin-only JWT authentication with bcrypt password hashing
- Automatic session expiry and forced re-login on token invalidation
- Brute-force login rate limiting (15 attempts per 15 min window)
- Secure token storage (OS keychain via `flutter_secure_storage`)
- Helmet security headers, CORS whitelist, global API rate limiting
- All SQL queries fully parameterised — no injection vectors

### Dashboard
- Real-time KPI cards (total books, issued, available, overdue, active members)
- Library Statistics bar chart (FL Chart)
- Book Status Distribution pie chart
- Actionable Alerts with expandable sections and "View All" popups
- Recent Activity feed with auto-refresh every 10 seconds
- Premium Library Overview hero banner with frosted chips

### Book Management
- Full CRUD with cover-image upload and preview
- Multi-copy tracking (total vs available)
- Categories/genres with CRUD management
- ISBN, rack number, publisher, year, description fields
- Bulk import from CSV / XLSX
- Bulk delete and CSV/JSON export
- Search and filter by title, author, category, year, availability

### Member Management
- Full CRUD with profile photo upload
- Member types: Student (3 books / 14 days), Faculty (10 / 30), Staff (5 / 21)
- Borrowing history with statistics dialogs
- Active / Inactive status toggling
- Bulk delete and CSV/JSON export

### Issue & Return System
- Issue books with automatic due-date calculation based on member type
- Quick return processing with availability auto-update
- Fine calculation for overdue returns
- Overdue / due-soon alerts with "Send Reminder" and "Mark Returned" actions
- Issue editing (extend due date, change status)

### Reports & Analytics
- Library Statistics — bar chart by category
- Book Status Distribution — pie chart
- Popular Books — ranked by borrow count
- Active Members — with statistics
- Overdue Report — full overdue list
- Export any report to PDF or Excel

### Notifications
- In-app notification bell with unread count badge
- Types: overdue, due-soon, new-book, system, warning, error, success
- Mark read (individual / bulk), delete
- Auto-refresh via polling + instant refresh on data mutations

### Search & Discovery
- Global search across books, members, and issues from the sidebar
- Advanced search dialog with multi-field filters
- Book recommendations based on a member's borrowing history

### Data Operations
- Full JSON backup & restore (books, members, issues)
- CSV / JSON export for books, members, issues
- CSV / XLSX bulk import with smart header mapping

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter 3.10+ · Material 3 · Provider state management |
| Backend | Node.js · Express 4 · REST API |
| Database | MySQL 8.0+ (connection pool, auto-migrations) |
| Auth | JWT (HS256) · bcrypt · Helmet · express-rate-limit |
| Charts | FL Chart |
| PDF | pdf + printing packages |
| File I/O | Multer (backend) · file_picker (Flutter) |

---

## Project Structure

```
library_management_system/
├── backend/                        # Node.js REST API
│   ├── server.js                  # Main server (routes, auth, migrations)
│   ├── package.json
│   ├── .env.example               # Environment template
│   ├── seed.js                    # Database seeding script
│   ├── uploads/                   # User-uploaded files (gitignored)
│   └── __tests__/                 # Jest API tests
├── flutter_app/                    # Flutter desktop application
│   ├── lib/
│   │   ├── main.dart              # Entry point + AuthWrapper
│   │   ├── models/                # book, member, issue, user, notification
│   │   ├── providers/              # 9 providers (auth, book, member, issue,
│   │   │                          #   theme, search, notification, report, dashboard)
│   │   ├── screens/               # login_screen, dashboard_screen
│   │   ├── services/              # api_service, backend_service
│   │   ├── utils/                 # theme, responsive, date_formatter,
│   │   │                          #   error_utils, hindi_text, color_extensions
│   │   └── widgets/               # Premium UI widgets (sidebar, dashboard,
│   │                              #   books, members, issues, reports, dialogs)
│   ├── assets/                    # Images and icons
│   └── pubspec.yaml
├── database/
│   ├── schema.sql                 # Base schema
│   └── schema_v2.sql              # Enhanced schema with all tables
├── installer.iss                   # Inno Setup installer script
├── INSTALLATION_GUIDE.md          # Detailed deployment guide
└── README.md                      # ← this file
```

---

## Quick Start

### Prerequisites

| Tool | Version |
|------|---------|
| Flutter SDK | 3.10+ |
| Node.js | 18+ |
| MySQL | 8.0+ |
| OS | Windows 10/11 (64-bit) |

### 1 · Database

```sql
CREATE DATABASE library_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```
```bash
mysql -u root -p library_management < database/schema_v2.sql
```

### 2 · Backend

```bash
cd backend
npm install
cp .env.example .env          # edit .env with real DB credentials & JWT secret
npm start                     # http://localhost:3000
```

> Generate a strong JWT secret:
> ```bash
> node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
> ```

### 3 · Flutter App

```bash
cd flutter_app
flutter pub get
flutter run -d windows
```

On Windows the app auto-starts the backend process; to run them separately set `API_BASE_URL`:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://your-server:3000/api
```

---

## Default Credentials

| Role | Username | Password |
|------|----------|----------|
| Admin | `admin` | `Library#123` |

Only admin users may log in (enforced server-side).

---

## API Reference

All endpoints (except health and login) require `Authorization: Bearer <token>`.

### Health
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/health` | Basic health check |
| GET | `/api/health/detailed` | Health + DB status |

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/login` | Login (returns JWT) |
| GET | `/api/auth/me` | Current user info |

### Books
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/books` | List (paginated, filterable) |
| GET | `/api/books/:id` | Get by ID |
| POST | `/api/books` | Create |
| PUT | `/api/books/:id` | Update |
| DELETE | `/api/books/:id` | Delete |
| POST | `/api/books/bulk-delete` | Bulk delete |
| POST | `/api/books/import` | CSV/XLSX import |
| POST | `/api/books/:id/cover` | Upload cover image |

### Members
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/members` | List (paginated) |
| GET | `/api/members/:id` | Get by ID |
| POST | `/api/members` | Create |
| PUT | `/api/members/:id` | Update |
| DELETE | `/api/members/:id` | Delete |
| POST | `/api/members/bulk-delete` | Bulk delete |
| PUT | `/api/members/:id/activate` | Activate |
| PUT | `/api/members/:id/deactivate` | Deactivate |
| GET | `/api/members/:id/borrowed-books` | Current loans |
| GET | `/api/members/:id/history` | Borrowing history |

### Issues
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/issues` | List (paginated, filterable) |
| POST | `/api/issues` | Issue a book |
| PUT | `/api/issues/:id` | Update issue |
| PUT | `/api/issues/:id/return` | Return a book |
| POST | `/api/issues/:id/remind` | Send reminder |
| POST | `/api/issues/bulk-delete` | Bulk delete |

### Categories
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/categories` | List categories |
| POST | `/api/categories` | Create |
| PUT | `/api/categories/:id` | Update |
| DELETE | `/api/categories/:id` | Delete |

### Dashboard & Reports
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dashboard/stats` | KPI statistics |
| GET | `/api/dashboard/alerts` | Overdue/due-soon alerts |
| GET | `/api/dashboard/activity` | Recent activity feed |
| POST | `/api/dashboard/activity/clear` | Clear activity |
| GET | `/api/dashboard/settings/:userId` | Widget layout |
| PUT | `/api/dashboard/settings/:userId` | Save widget layout |
| GET | `/api/reports/issued` | Issued books report |
| GET | `/api/reports/overdue` | Overdue books report |
| GET | `/api/reports/popular-books` | Popular books |
| GET | `/api/reports/active-members` | Active members |
| GET | `/api/reports/monthly-stats` | Monthly statistics |
| GET | `/api/reports/category-stats` | Category distribution |

### Notifications
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/notifications` | List notifications |
| GET | `/api/notifications/count` | Unread count |
| PUT | `/api/notifications/:id/read` | Mark read |
| PUT | `/api/notifications/read-all` | Mark all read |
| DELETE | `/api/notifications/:id` | Delete |

### Search & Recommendations
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/search?q=` | Global search |
| GET | `/api/recommendations/:memberId` | Book recommendations |

### Data Operations
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/backup` | Download JSON backup |
| POST | `/api/restore` | Restore from backup |
| GET | `/api/export/:type` | Export CSV/JSON |

### Uploads
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/uploads/book-cover` | Upload book cover |
| POST | `/api/uploads/member-photo` | Upload member photo |

---

## Security

| Layer | Measure |
|-------|---------|
| Auth | JWT HS256, bcrypt (10 rounds), admin-only enforcement |
| Brute-force | Login rate limiter: 15 attempts / 15 min per IP |
| API rate limit | Configurable global limit (production mode) |
| SQL | 100 % parameterised queries — no string interpolation |
| Restore | Column-name whitelist prevents injection via crafted backups |
| HTTP headers | Helmet (CSP, X-Frame, HSTS, etc.) |
| CORS | Whitelist-based origin policy |
| File uploads | Extension + MIME validation, size caps, sanitised filenames |
| Tokens | Secure storage (OS keychain) with SharedPreferences fallback |
| Errors | Internal details hidden in production responses |
| Secrets | `.env` excluded from VCS; `.env.example` provided |

---

## Build & Release

### Windows Executable

```bash
cd flutter_app
flutter build windows
```

Output: `flutter_app/build/windows/x64/runner/Release/`

### Installer (Inno Setup)

```bash
iscc installer.iss
```

See [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) for full production deployment instructions.

---

## Commands Cheat-Sheet

```bash
# Backend
cd backend
npm start                     # Start server
npm run dev                   # Dev mode (nodemon)
node seed.js                  # Seed sample data

# Flutter
cd flutter_app
flutter pub get               # Install deps
flutter run -d windows        # Run app
flutter build windows         # Release build
flutter analyze               # Static analysis
```

---

## License

This project is proprietary software for Uttar Pradesh State Tax Training & Research Institute. All rights reserved.

---

**Version** 1.1.2 · **Last updated** May 2026