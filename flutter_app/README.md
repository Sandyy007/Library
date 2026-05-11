# UPSTTRI Library Management App - Flutter Frontend

A modern, premium desktop application for library management built with Flutter and Material 3 design system for **Uttar Pradesh State Tax Training & Research Institute**.

---

## Premium Features

### User Interface

- **Premium Sidebar** - Diagonal gradient header with glowing logo, decorative circles, frosted badge
- **Premium Dashboard** - Real-time KPI cards with hover animations, animated stat cards
- **Premium Popups** - Gradient headers, pagination, hover effects on all dialogs
- **Material 3 Design** - Modern, clean UI with dynamic theming
- **Dark/Light Theme** - Toggle between themes with smooth transitions
- **Responsive Layout** - Optimized for desktop screens (1200px+)
- **Animated Transitions** - Smooth page and component animations (200ms)

### Core Functionality

- **Dashboard** - Real-time statistics, library statistics bar chart, book status pie chart
- **Actionable Alerts** - Overdue, due today, low stock with color-coded sections
- **Recent Activity** - Live feed with auto-refresh every 10 seconds
- **Book Management** - CRUD operations with cover images
- **Member Management** - Profile photos and borrowing history
- **Issue/Return System** - Track book loans with due dates, send reminders
- **Reports** - Charts and exportable analytics
- **Notifications** - Bell icon with unread count badge
- **Advanced Search** - Multi-filter search functionality
- **Backup/Restore** - Data export and import

---

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── book.dart
│   ├── member.dart
│   ├── issue.dart
│   ├── user.dart
│   ├── notification.dart
│   └── report_models.dart
├── providers/                # State management
│   ├── auth_provider.dart
│   ├── book_provider.dart
│   ├── member_provider.dart
│   ├── issue_provider.dart
│   ├── notification_provider.dart
│   ├── report_provider.dart
│   ├── search_provider.dart
│   ├── dashboard_provider.dart
│   └── theme_provider.dart
├── screens/                  # Main screens
│   ├── login_screen.dart
│   └── dashboard_screen.dart
├── services/                 # API communication
│   └── api_service.dart
├── utils/                    # Utilities
│   ├── theme.dart
│   ├── responsive.dart
│   ├── date_formatter.dart
│   ├── error_utils.dart
│   ├── hindi_text.dart
│   └── color_extensions.dart
└── widgets/                  # Reusable components
    ├── sidebar.dart
    ├── dashboard_content.dart
    ├── books_content.dart
    ├── book_dialog.dart
    ├── members_content.dart
    ├── member_dialog.dart
    ├── member_history_dialog.dart
    ├── issues_content.dart
    ├── reports_content.dart
    ├── about_content.dart
    ├── notification_bell.dart
    ├── advanced_search_dialog.dart
    └── backup_restore_dialog.dart
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.10+
- Windows development environment
- Backend server running on `http://localhost:3000`

### Installation

1. Install dependencies:

```bash
flutter pub get
```

2. Enable Windows desktop:

```bash
flutter config --enable-windows-desktop
```

3. Run the app:

```bash
flutter run -d windows
```

### Build for Production

```bash
flutter build windows
```

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| provider | ^6.0.5 | State management |
| http | ^1.1.0 | HTTP requests |
| shared_preferences | ^2.2.2 | Local storage |
| flutter_secure_storage | ^9.2.2 | Secure token storage |
| fl_chart | ^0.66.1 | Charts and graphs |
| data_table_2 | ^2.5.8 | Enhanced data tables |
| file_picker | ^8.0.0+1 | File selection |
| path_provider | ^2.1.2 | File paths |
| pdf | ^3.10.4 | PDF generation |
| printing | ^5.12.0 | Print/export |
| krutidevtounicode | ^1.0.2 | Hindi text support |

---

## Architecture

### State Management

The app uses **Provider** for state management with 9 specialized providers:

- `AuthProvider` - Authentication state
- `BookProvider` - Book data and operations
- `MemberProvider` - Member data and operations
- `IssueProvider` - Issue/return operations and statistics
- `NotificationProvider` - Notification management with polling
- `ReportProvider` - Report data and export
- `SearchProvider` - Search filters and results
- `DashboardProvider` - Dashboard widget configuration
- `ThemeProvider` - Theme switching

### API Communication

All backend communication is handled through `ApiService` with:

- JWT token management
- Request timeout handling
- Error handling and logging
- File upload support
- Real-time data streaming via polling

---

## Commands

```bash
flutter run -d windows     # Run debug
flutter build windows      # Build release
flutter analyze            # Analyze code
flutter format .           # Format code
flutter test               # Run tests
flutter pub upgrade        # Update dependencies
```

---

## Configuration

### API Base URL

Configure the API URL at build time:

```bash
flutter run -d windows \
  --dart-define=API_BASE_URL=http://localhost:3000/api \
  --dart-define=API_SERVER_ORIGIN=http://localhost:3000
```

Auth tokens are stored using secure storage on supported platforms.

---

## Notes

- Requires backend server to be running
- Designed for Windows desktop (optimized for 1200px+ screens)
- Uses Material 3 design guidelines
- Supports hot reload for development
- Premium UI with hover animations and transitions

---

**Version:** 1.1.2
**Last Updated:** May 2026