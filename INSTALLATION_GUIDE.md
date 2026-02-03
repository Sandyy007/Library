# Library Management System - Installation & Deployment Guide

## 📋 Table of Contents

1. [System Requirements](#system-requirements)
2. [Project Overview](#project-overview)
3. [Backend Setup](#backend-setup)
4. [Database Setup](#database-setup)
5. [Flutter App Setup](#flutter-app-setup)
6. [Production Deployment](#production-deployment)
7. [Configuration](#configuration)
8. [Troubleshooting](#troubleshooting)

---

## 🖥️ System Requirements

### Server Requirements (Backend)
- **Node.js**: v18.0.0 or higher
- **MySQL**: v8.0 or higher (or MariaDB 10.5+)
- **RAM**: Minimum 2GB
- **Storage**: 10GB+ for database and uploads

### Client Requirements (Flutter App)
- **Windows**: Windows 10 or higher (64-bit)
- **RAM**: Minimum 4GB
- **Display**: 1280x720 minimum resolution

### Development Requirements
- **Flutter SDK**: 3.19.0 or higher
- **Dart SDK**: 3.3.0 or higher
- **Git**: For version control

---

## 📁 Project Overview

```
library_management_system/
├── backend/                 # Node.js Express API server
│   ├── server.js           # Main server file
│   ├── package.json        # Node.js dependencies
│   ├── uploads/            # File uploads directory
│   └── __tests__/          # API tests
├── flutter_app/            # Flutter desktop application
│   ├── lib/                # Dart source code
│   ├── assets/             # Images and fonts
│   ├── windows/            # Windows-specific files
│   └── pubspec.yaml        # Flutter dependencies
└── database/               # SQL schema files
    ├── schema.sql          # Database schema
    └── schema_v2.sql       # Updated schema
```

---

## ⚙️ Backend Setup

### Step 1: Install Node.js Dependencies

```bash
cd backend
npm install
```

### Step 2: Configure Environment

Create a `.env` file in the `backend` directory:

```env
# Database Configuration
DB_HOST=localhost
DB_PORT=3306
DB_USER=your_mysql_username
DB_PASSWORD=your_mysql_password
DB_NAME=library_db

# Server Configuration
PORT=3000
NODE_ENV=production

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production

# File Upload Configuration
UPLOAD_PATH=./uploads
MAX_FILE_SIZE=5242880
```

### Step 3: Start the Backend Server

**Development:**
```bash
npm start
# or
node server.js
```

**Production (with PM2):**
```bash
npm install -g pm2
pm2 start server.js --name "library-api"
pm2 save
pm2 startup
```

---

## 🗃️ Database Setup

### Step 1: Create Database

```sql
CREATE DATABASE library_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### Step 2: Import Schema

```bash
mysql -u your_username -p library_db < database/schema_v2.sql
```

### Step 3: Create Admin User

```bash
cd backend
node seed.js
```

This creates a default admin user:
- **Username:** `admin`
- **Password:** `admin`

> ⚠️ **Important:** Change the default admin password immediately after first login!

### Database Tables

| Table | Description |
|-------|-------------|
| `users` | Admin user accounts |
| `books` | Book inventory |
| `members` | Library members |
| `issues` | Book issues/loans |
| `notifications` | System notifications |
| `activity_log` | Dashboard activity |

---

## 📱 Flutter App Setup

### Step 1: Install Flutter Dependencies

```bash
cd flutter_app
flutter pub get
```

### Step 2: Configure API Endpoint

Edit `lib/services/api_service.dart`:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000/api',  // Change for production
);
```

Or build with custom URL:
```bash
flutter build windows --dart-define=API_BASE_URL=http://your-server:3000/api
```

### Step 3: Run in Development

```bash
flutter run -d windows
```

### Step 4: Build for Production

```bash
flutter build windows --release
```

The release build will be at:
```
flutter_app/build/windows/x64/runner/Release/
```

---

## 🚀 Production Deployment

### Backend Deployment Options

#### Option A: Traditional Server (VPS/Dedicated)

1. **Install Dependencies:**
   ```bash
   # Install Node.js 18+
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   
   # Install MySQL
   sudo apt-get install mysql-server
   ```

2. **Clone and Setup:**
   ```bash
   git clone <your-repo-url>
   cd library_management_system/backend
   npm install --production
   ```

3. **Setup PM2:**
   ```bash
   npm install -g pm2
   pm2 start server.js --name library-api
   pm2 startup
   pm2 save
   ```

4. **Setup Nginx (Reverse Proxy):**
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;

       location / {
           proxy_pass http://localhost:3000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
   }
   ```

#### Option B: Docker Deployment

Create `docker-compose.yml`:

```yaml
version: '3.8'
services:
  api:
    build: ./backend
    ports:
      - "3000:3000"
    environment:
      - DB_HOST=mysql
      - DB_USER=library
      - DB_PASSWORD=your_password
      - DB_NAME=library_db
    depends_on:
      - mysql
    volumes:
      - ./backend/uploads:/app/uploads

  mysql:
    image: mysql:8.0
    environment:
      - MYSQL_ROOT_PASSWORD=root_password
      - MYSQL_DATABASE=library_db
      - MYSQL_USER=library
      - MYSQL_PASSWORD=your_password
    volumes:
      - mysql_data:/var/lib/mysql
      - ./database/schema_v2.sql:/docker-entrypoint-initdb.d/init.sql

volumes:
  mysql_data:
```

### Flutter App Distribution

#### Windows Installer (Recommended)

1. **Build Release:**
   ```bash
   flutter build windows --release
   ```

2. **Create Installer with Inno Setup:**
   
   Download [Inno Setup](https://jrsoftware.org/isinfo.php) and create `installer.iss`:

   ```iss
   [Setup]
   AppName=Library Management System
   AppVersion=1.0.0
   DefaultDirName={autopf}\Library Management System
   DefaultGroupName=Library Management System
   OutputBaseFilename=LibraryMS_Setup
   Compression=lzma
   SolidCompression=yes

   [Files]
   Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

   [Icons]
   Name: "{group}\Library Management System"; Filename: "{app}\library_management_app.exe"
   Name: "{commondesktop}\Library Management System"; Filename: "{app}\library_management_app.exe"
   ```

3. **Compile Installer:**
   ```
   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
   ```

#### Portable Distribution

Simply zip the entire `build/windows/x64/runner/Release/` folder and distribute.

---

## 🔧 Configuration

### API Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 3000 | API server port |
| `DB_HOST` | localhost | MySQL host |
| `DB_PORT` | 3306 | MySQL port |
| `DB_NAME` | library_db | Database name |
| `JWT_SECRET` | (required) | JWT signing secret |
| `UPLOAD_PATH` | ./uploads | File upload directory |

### Flutter App Configuration

Build-time configuration using `--dart-define`:

```bash
flutter build windows \
  --dart-define=API_BASE_URL=https://api.yourserver.com/api \
  --dart-define=API_SERVER_ORIGIN=https://api.yourserver.com
```

---

## 🔐 Security Checklist

- [ ] Change default admin password
- [ ] Use strong JWT_SECRET (32+ characters)
- [ ] Enable HTTPS in production
- [ ] Configure firewall rules
- [ ] Set up database backups
- [ ] Enable MySQL SSL connections
- [ ] Restrict CORS origins in production
- [ ] Regular security updates

---

## 🧪 Testing

### Backend Tests

```bash
cd backend
npm test
```

### Flutter Tests

```bash
cd flutter_app
flutter test
```

### API Smoke Test

```bash
cd backend
node tool/api_smoke_test.js
```

---

## 🔍 Troubleshooting

### Common Issues

#### 1. "Connection Refused" Error
- Ensure backend server is running
- Check firewall settings
- Verify API_BASE_URL configuration

#### 2. Database Connection Failed
- Verify MySQL is running: `sudo systemctl status mysql`
- Check credentials in .env file
- Ensure database exists

#### 3. Flutter Build Fails
- Run `flutter clean` then `flutter pub get`
- Ensure Flutter SDK is up to date: `flutter upgrade`
- Check Windows SDK installation

#### 4. File Upload Fails
- Check uploads directory permissions
- Verify MAX_FILE_SIZE setting
- Ensure disk space is available

### Logs

**Backend logs:**
```bash
pm2 logs library-api
```

**Flutter debug:**
```bash
flutter run -d windows --verbose
```

---

## 📞 Support

For issues or feature requests, please create an issue in the repository.

---

## 📄 License

This project is licensed under the MIT License.

---

**Version:** 1.0.0  
**Last Updated:** February 2026
