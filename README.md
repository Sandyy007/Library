# Library Management System

A comprehensive desktop Library Management System featuring a Flutter (Windows) frontend and a Node.js + MySQL backend. The application provides complete book/member management, issue/return workflows, advanced reporting & analytics, notifications, and robust admin functionality.

## ✨ Features

### 🔐 Authentication & Authorization
- Admin login 
- Secure password hashing with bcrypt
- JWT-based authentication with token refresh
- Session management

### 📊 Dashboard
- Real-time statistics (total books, issued books, available books, overdue books, active members)
- Monthly issue/return charts with interactive visualizations
- Quick access to common actions
- Customizable dashboard widgets
- Modern Material 3 design with dark/light theme support

### 📚 Book Management
- Add, edit, delete books with full CRUD operations
- **Book cover image upload** with preview
- **Multiple copies tracking** (total vs available)
- **Book categories/genres** (Fiction, Non-Fiction, Science, Technology, History, etc.)
- ISBN, title, author, category, publisher, year tracking
- Book description field
- Search and filter by title, author, category, availability

### 👥 Member Management
- Add, edit, delete members
- **Member profile photo upload**
- **Member types/categories**: Student, Faculty, Staff with different borrowing limits
  - Students: 3 books max, 14-day loan period
  - Faculty: 10 books max, 30-day loan period
  - Staff: 5 books max, 21-day loan period
- **Member borrowing history** with statistics
- Contact information (email, phone, address)
- Membership date and expiry tracking
- Active/Inactive status management

### 📖 Issue & Return System
- Issue books with automatic due date calculation based on member type
- Quick return processing
- Fine calculation for overdue books ($1 per day default)
- Issue history tracking with status indicators
- Overdue alerts and notifications

### 📈 Reports & Analytics
- **Popular Books Report** - Books ranked by borrow count
- **Active Members Report** - Most active members with badges
- **Monthly Statistics** - Bar chart visualization of issues/returns/overdue
- **Category Distribution** - Pie chart showing books by category
- **Overdue Report** - List of all overdue books with member info
- **Export to PDF/Excel** - Export reports in multiple formats

### 🔔 Notifications
- **In-app notification bell** with unread count badge
- Notification types: Overdue alerts, Due soon reminders, New book alerts, System messages
- Mark as read (individual and bulk)
- Delete notifications
- Auto-refresh notification count (30-second polling)

### 🔍 Search & Discovery
- **Advanced search** with multiple filters:
  - Search by title, author, ISBN
  - Filter by category
  - Filter by availability status
  - Sort options (title, author, year)
- Quick search from sidebar

### 🛠️ Additional Features
- **Data Backup & Restore** - Create and restore JSON backups
- **Dashboard widget customization** via DashboardProvider
- Dark/Light theme toggle
- Responsive desktop UI
- Real-time data synchronization

## 🛠️ Tech Stack

| Component | Technology |
|-----------|------------|
| **Frontend** | Flutter 3.10+ (Material 3, Provider state management) |
| **Backend** | Node.js + Express REST API |
| **Database** | MySQL 8.0+ |
| **Authentication** | JWT (JSON Web Tokens) |
| **Charts** | FL Chart |
| **File Upload** | Multer (backend), file_picker (Flutter) |
| **PDF Export** | pdf, printing packages |

## 📁 Project Structure

```
library_management_system/
├── flutter_app/                    # Flutter desktop application
│   ├── lib/
│   │   ├── main.dart              # App entry point
│   │   ├── models/                # Data models
│   │   ├── providers/             # State management (9 providers)
│   │   ├── screens/               # Screen widgets
│   │   ├── services/              # API services
│   │   ├── utils/                 # Utilities
│   │   └── widgets/               # Reusable widgets
│   ├── assets/images/
│   └── pubspec.yaml
├── backend/                        # Node.js REST API
│   ├── server.js                  # Main server file
│   ├── package.json
│   ├── .env                       # Environment variables
│   └── seed.js                    # Database seeding script
└── database/                       # MySQL schema
    ├── schema.sql                 # Base schema
    └── schema_v2.sql              # Enhanced schema
```

## 🚀 Setup Instructions

### Prerequisites
- Flutter SDK 3.10+
- Node.js v16+
- MySQL Server 8.0+
- Windows OS (for desktop app)

### 1. Database Setup
```sql
CREATE DATABASE library_management;
```
```bash
mysql -u root -p library_management < database/schema_v2.sql
```

### 2. Backend Setup
```bash
cd backend
npm install
```

Configure `.env`:
```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=library_management
JWT_SECRET=your_secure_jwt_secret
PORT=3000
```

Notes:
- Use `backend/.env.example` as a template and do not commit your real `.env`.
- Tokens expire by default (`JWT_EXPIRES_IN=1h`).
- For browser-based clients, set `CORS_ORIGINS` (comma-separated) in `.env`.

Start server:
```bash
npm start
```

### 3. Flutter Setup
```bash
cd flutter_app
flutter pub get
flutter config --enable-windows-desktop
flutter run -d windows
```

## 🔑 Default Login Credentials

| Role | Username | Password |
|------|----------|----------|
| Admin | `admin` | `admin` |

Only admin users are allowed to log in (enforced by the backend).

## 📡 API Endpoints

### Authentication
- `POST /api/auth/login` - User login

### Books
- `GET /api/books` - Get all books
- `POST /api/books` - Add new book
- `PUT /api/books/:id` - Update book
- `DELETE /api/books/:id` - Delete book

### Members
- `GET /api/members` - Get all members
- `GET /api/members/:id/history` - Get member history
- `POST /api/members` - Add new member
- `PUT /api/members/:id` - Update member
- `DELETE /api/members/:id` - Delete member

### Issues
- `GET /api/issues` - Get all issues
- `POST /api/issues` - Issue a book
- `PUT /api/issues/:id/return` - Return a book

### Reports
- `GET /api/dashboard/stats` - Dashboard statistics
- `GET /api/reports/popular-books` - Popular books report
- `GET /api/reports/active-members` - Active members report
- `GET /api/reports/monthly-stats` - Monthly statistics
- `GET /api/reports/category-stats` - Category statistics
- `GET /api/reports/overdue` - Overdue books report

### Notifications
- `GET /api/notifications` - Get notifications
- `PUT /api/notifications/:id/read` - Mark as read
- `PUT /api/notifications/mark-all-read` - Mark all as read

### Utilities
- `GET /api/search` - Advanced search
- `GET /api/backup` - Create backup
- `POST /api/restore` - Restore backup

## 🎯 Useful Commands

### Backend
```bash
npm start          # Start server
npm run dev        # Development with nodemon
node seed.js       # Seed database
```

### Flutter
```bash
flutter run -d windows    # Run app
flutter build windows     # Build release
flutter analyze           # Analyze code
```

## 📝 Development Notes

- Uses **Provider** for state management
- Clean Architecture with separation of concerns
- Responsive desktop UI with **Material 3**
- Comprehensive error handling
- Real-time data synchronization

---

**Last Updated:** February 2026
