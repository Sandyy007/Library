const express = require('express');
const mysql = require('mysql2');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const fs = require('fs');
const https = require('https');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const path = require('path');
const multer = require('multer');
const { parse: parseCsv } = require('csv-parse/sync');
const xlsx = require('xlsx');
const compression = require('compression');

// Always resolve .env relative to this file so running from other working directories still works
require('dotenv').config({ path: path.join(__dirname, '.env') });

const isProduction = process.env.NODE_ENV === 'production';
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '1h';

if (isProduction && !JWT_SECRET) {
  console.error('Missing required env var JWT_SECRET. Refusing to start in production.');
  process.exit(1);
}

const app = express();
app.disable('x-powered-by');
// Only trust the X-Forwarded-For header when behind a real reverse proxy.
// In dev / direct desktop usage, leaving this on lets clients spoof their IP
// and bypass the per-IP login rate limiter.
app.set('trust proxy', isProduction ? 1 : 0);

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  })
);

const allowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

// In production we MUST have an explicit allowlist. Refuse to boot otherwise
// to avoid silently blocking all browser traffic when the operator forgets to
// set the env var.
if (isProduction && allowedOrigins.length === 0) {
  console.error(
    'CORS_ORIGINS must be set to a comma-separated list in production. ' +
    'Refusing to start with a permissive CORS policy.'
  );
  process.exit(1);
}

app.use(
  cors({
    origin: (origin, cb) => {
      // Non-browser clients (mobile/CLI) often send no Origin.
      if (!origin) return cb(null, true);
      // If no allowlist configured, only allow all in non-production.
      if (allowedOrigins.length === 0) return cb(null, !isProduction);
      return cb(null, allowedOrigins.includes(origin));
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);

const jsonBodyLimit = process.env.JSON_BODY_LIMIT || '2mb';
app.use(express.json({ limit: jsonBodyLimit }));
app.use(express.urlencoded({ limit: jsonBodyLimit, extended: true }));

// Compress JSON/CSV/text responses. Skip for already-compressed file uploads.
app.use(
  compression({
    threshold: '1kb',
    filter: (req, res) => {
      if (req.path === '/uploads/' || req.path.startsWith('/uploads/')) {
        return false;
      }
      return compression.filter(req, res);
    },
  })
);

// Structured request logging
const logFormat = isProduction ? 'combined' : 'dev';
const logStream = process.env.LOG_FILE
  ? fs.createWriteStream(path.join(__dirname, process.env.LOG_FILE), { flags: 'a' })
  : null;
app.use(morgan(logFormat, logStream ? { stream: logStream } : {}));

// Rate limiting is configured via the apiLimiter mounted on /api below
// (see `apiLimiter` definition and `app.use('/api', apiLimiter)`).
// The OLD per-environment production-only rate limit was removed because
// it shadowed the new one in production (a single request would increment
// both counters). Operators can tune via API_RATE_LIMIT_PER_MIN env var.

// Stricter rate limit on login endpoint to prevent brute-force attacks.
// Applies in ALL environments (not just production).
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 15, // 15 attempts per window
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many login attempts. Please try again later.' },
  handler: (_req, res) => {
    res.status(429).json({ error: 'Too many login attempts. Please try again later.' });
  },
  // Key by IP only (not auth header).
  keyGenerator: (req) => req.ip,
});

// General API rate limit: protects every /api/* endpoint (not just login)
// from being hammered by a runaway client or scraping bot. Higher than the
// login limit because legitimate clients (e.g. dashboards that auto-refresh)
// make many requests per minute.
const apiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: parseInt(process.env.API_RATE_LIMIT_PER_MIN, 10) || 300, // 300 req/min/IP
  standardHeaders: true,
  legacyHeaders: false,
  // Skip limit on the login route; it has its own stricter limiter.
  skip: (req) => req.path === '/auth/login',
  handler: (_req, res) => {
    res.status(429).json({
      error: 'Too many requests. Please slow down.',
      code: 'RATE_LIMITED',
    });
  },
  keyGenerator: (req) => req.ip,
});

// Serve uploaded files statically with security headers
app.use('/uploads', (req, res, next) => {
  // Prevent browsers from MIME-sniffing or opening files inline
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Disposition', 'inline');
  next();
}, express.static(path.join(__dirname, 'uploads')));

const PORT = process.env.PORT || 3000;

const parsePositiveInt = (value, fallback) => {
  const n = Number.parseInt(String(value ?? ''), 10);
  if (!Number.isFinite(n) || n <= 0) return fallback;
  return n;
};

const parseNonNegativeInt = (value, fallback) => {
  const n = Number.parseInt(String(value ?? ''), 10);
  if (!Number.isFinite(n) || n < 0) return fallback;
  return n;
};

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, 'uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    // Sanitize extension: allow only alphanumeric + dot; strip path separators
    const ext = path.extname(file.originalname).replace(/[^a-zA-Z0-9.]/g, '');
    cb(null, uniqueSuffix + ext);
  }
});

const upload = multer({ 
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    // Disallow SVG by default to avoid scriptable image content.
    const allowedTypes = /jpeg|jpg|png|gif|webp|bmp|tiff|tif/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = /image\//;
    if (extname && mimetype.test(file.mimetype)) {
      return cb(null, true);
    }
    cb(new Error('Only image files are allowed'));
  }
});

// Separate upload handler for CSV/XLSX imports (memory; not stored on disk)
// Supports large imports (10k+ books)
const importUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 100 * 1024 * 1024 }, // 100MB for large book imports
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const okExt = ext === '.csv' || ext === '.xlsx' || ext === '.xls';
    if (!okExt) return cb(new Error('Only .csv, .xlsx, or .xls files are allowed'));
    return cb(null, true);
  },
});

const dbQuery = (sql, params = []) =>
  new Promise((resolve, reject) => {
    db.query(sql, params, (err, results) => {
      if (err) return reject(err);
      resolve(results);
    });
  });

const dbQueryWithConnection = (connection, sql, params = []) =>
  new Promise((resolve, reject) => {
    connection.query(sql, params, (err, results) => {
      if (err) return reject(err);
      resolve(results);
    });
  });

const getDbConnection = () =>
  new Promise((resolve, reject) => {
    db.getConnection((err, connection) => {
      if (err) return reject(err);
      resolve(connection);
    });
  });

const beginTransaction = (connection) =>
  new Promise((resolve, reject) => {
    connection.beginTransaction((err) => {
      if (err) return reject(err);
      resolve();
    });
  });

const commitTransaction = (connection) =>
  new Promise((resolve, reject) => {
    connection.commit((err) => {
      if (err) return reject(err);
      resolve();
    });
  });

const rollbackTransaction = (connection) =>
  new Promise((resolve) => {
    connection.rollback(() => {
      resolve();
    });
  });

const withTransaction = async (operation) => {
  const connection = await getDbConnection();
  try {
    await beginTransaction(connection);
    const result = await operation(connection);
    await commitTransaction(connection);
    return result;
  } catch (err) {
    await rollbackTransaction(connection);
    throw err;
  } finally {
    connection.release();
  }
};

const normalizeApiErrorPayload = (
  payload,
  fallbackCode = 'REQUEST_FAILED',
  fallbackMessage = 'Request failed'
) => {
  const source = payload && typeof payload === 'object' ? payload : {};
  const message = String(source.error || source.message || fallbackMessage);
  const code = String(source.error_code || source.code || fallbackCode);
  const details = Object.prototype.hasOwnProperty.call(source, 'details')
    ? source.details
    : (Object.prototype.hasOwnProperty.call(source, 'error_details') ? source.error_details : null);

  return {
    success: false,
    error: message,
    error_code: code,
    error_details: details,
    message,
  };
};

const sendApiError = (
  res,
  status,
  payload,
  fallbackCode = 'REQUEST_FAILED',
  fallbackMessage = 'Request failed'
) => {
  return res
    .status(status)
    .json(normalizeApiErrorPayload(payload, fallbackCode, fallbackMessage));
};

const createHttpError = (status, payload) => {
  const defaultPayload = normalizeApiErrorPayload(payload, 'REQUEST_FAILED', 'Request failed');
  const message = defaultPayload.error || 'Request failed';
  const err = new Error(message);
  err.status = status;
  err.payload = defaultPayload;
  return err;
};

// Best-effort activity logger (used by the dashboard Recent Activity feed).
// If the table doesn't exist (older DB), we silently ignore insert errors.
const logActivityEvent = ({
  type,
  related_id,
  related_type,
  title,
  description,
  occurred_at,
}) => {
  try {
    const sql =
      'INSERT INTO activity_events (type, related_id, related_type, title, description, occurred_at) VALUES (?, ?, ?, ?, ?, COALESCE(?, NOW()))';
    db.query(
      sql,
      [
        type,
        related_id ?? null,
        related_type ?? null,
        title ?? null,
        description ?? null,
        occurred_at ?? null,
      ],
      () => {
        // ignore
      }
    );

    const notificationType = type || 'activity';
    if (notificationType !== 'book_added') {
      const notificationTitle = title || 'Activity update';
      const notificationMessage = description || notificationTitle;
      db.query(
        `
          INSERT INTO notifications (user_id, title, message, type, related_id, related_type)
          SELECT id, ?, ?, ?, ?, ? FROM users WHERE role = 'admin' LIMIT 1
        `,
        [
          notificationTitle,
          notificationMessage,
          notificationType,
          related_id ?? null,
          related_type ?? null,
        ],
        () => {
          // ignore
        }
      );
    }
  } catch (_) {
    // ignore
  }
};

const tryDeleteUploadedFile = (maybeUploadUrl) => {
  try {
    if (!maybeUploadUrl || typeof maybeUploadUrl !== 'string') return;
    if (!maybeUploadUrl.startsWith('/uploads/')) return;

    const relative = maybeUploadUrl.replace(/^\/uploads\//, '');
    if (!relative) return;
    const fullPath = path.join(__dirname, 'uploads', relative);

    if (fs.existsSync(fullPath)) {
      fs.unlinkSync(fullPath);
    }
  } catch (e) {
    // Best-effort cleanup only
  }
};

// Decode text files robustly (Hindi/English), supporting UTF-8 and UTF-16.
// Excel often exports CSV as UTF-16LE.
const decodeTextBuffer = (buffer) => {
  if (!buffer || buffer.length === 0) return '';

  // UTF-8 BOM
  if (buffer.length >= 3 && buffer[0] === 0xEF && buffer[1] === 0xBB && buffer[2] === 0xBF) {
    return buffer.slice(3).toString('utf8');
  }

  // UTF-16LE BOM
  if (buffer.length >= 2 && buffer[0] === 0xFF && buffer[1] === 0xFE) {
    return buffer.slice(2).toString('utf16le');
  }

  // UTF-16BE BOM
  if (buffer.length >= 2 && buffer[0] === 0xFE && buffer[1] === 0xFF) {
    const sliced = buffer.slice(2);
    const swapped = Buffer.allocUnsafe(sliced.length);
    for (let i = 0; i + 1 < sliced.length; i += 2) {
      swapped[i] = sliced[i + 1];
      swapped[i + 1] = sliced[i];
    }
    // If odd length, copy last byte as-is.
    if (sliced.length % 2 === 1) swapped[sliced.length - 1] = sliced[sliced.length - 1];
    return swapped.toString('utf16le');
  }

  // Heuristic: if many NUL bytes, treat as UTF-16LE.
  let nulCount = 0;
  const sampleLen = Math.min(buffer.length, 2000);
  for (let i = 0; i < sampleLen; i++) {
    if (buffer[i] === 0x00) nulCount++;
  }
  if (nulCount > sampleLen * 0.1) {
    return buffer.toString('utf16le');
  }

  return buffer.toString('utf8');
};

// Promote overdue issues to "overdue" status before returning data/stats.
// Throttle the actual UPDATE to once per REFRESH_OVERDUE_MIN_INTERVAL_MS;
// the dashboard polls every 10s but the UPDATE itself is cheap to skip.
const REFRESH_OVERDUE_MIN_INTERVAL_MS = 15_000;
let _refreshOverdueStatusesLastRun = 0;
let _refreshOverdueStatusesInflight = null;
const _refreshOverdueStatusesCore = () =>
  new Promise((resolve) => {
    db.query(
      "UPDATE issues SET status = 'overdue' WHERE status = 'issued' AND due_date < CURDATE()",
      (err) => {
        if (err) {
          console.error('Failed to refresh overdue issue statuses:', err.message);
        }
        resolve();
      }
    );
  });

const refreshOverdueStatuses = async (opts = {}) => {
  const force = opts.force === true;
  const now = Date.now();
  if (!force && now - _refreshOverdueStatusesLastRun < REFRESH_OVERDUE_MIN_INTERVAL_MS) {
    return;
  }
  if (_refreshOverdueStatusesInflight) {
    return _refreshOverdueStatusesInflight;
  }
  _refreshOverdueStatusesInflight = (async () => {
    try {
      await _refreshOverdueStatusesCore();
      _refreshOverdueStatusesLastRun = Date.now();
    } finally {
      _refreshOverdueStatusesInflight = null;
    }
  })();
  return _refreshOverdueStatusesInflight;
};

// Generate notifications for overdue and due-soon books.
// The dashboard polls every 10s, but the full pipeline (two SQL inserts
// each scanning issues/joined tables) is wasteful to run that often. We
// throttle to at most once per GENERATE_NOTIFICATIONS_MIN_INTERVAL_MS, and
// also coalesce concurrent calls so a second caller piggy-backs on the
// in-flight run instead of starting a parallel one.
const GENERATE_NOTIFICATIONS_MIN_INTERVAL_MS = 30_000;
let _generateNotificationsLastRun = 0;
let _generateNotificationsInflight = null;
const _generateNotificationsCore = async () => {
  return new Promise((resolve) => {
    // Create notifications for overdue books
    db.query(`
      INSERT INTO notifications (user_id, title, message, type, related_id, related_type)
      SELECT 
        (SELECT id FROM users WHERE role = 'admin' LIMIT 1),
        CONCAT('Overdue: ', b.title),
        CONCAT(m.name, ' has not returned "', b.title, '" which was due on ', DATE_FORMAT(i.due_date, '%d/%m/%Y')),
        'overdue',
        i.id,
        'issue'
      FROM issues i
      JOIN books b ON i.book_id = b.id
      JOIN members m ON i.member_id = m.id
      WHERE i.status = 'overdue'
      AND NOT EXISTS (
        SELECT 1 FROM notifications n 
        WHERE n.related_id = i.id 
        AND n.related_type = 'issue' 
        AND n.type = 'overdue'
        AND DATE(n.created_at) = CURDATE()
      )
    `, (err) => {
      if (err) console.log('Note: notifications table may not exist yet');
      
      // Create notifications for books due soon (within 2 days)
      db.query(`
        INSERT INTO notifications (user_id, title, message, type, related_id, related_type)
        SELECT 
          (SELECT id FROM users WHERE role = 'admin' LIMIT 1),
          CONCAT('Due Soon: ', b.title),
          CONCAT('"', b.title, '" borrowed by ', m.name, ' is due on ', DATE_FORMAT(i.due_date, '%d/%m/%Y')),
          'due_soon',
          i.id,
          'issue'
        FROM issues i
        JOIN books b ON i.book_id = b.id
        JOIN members m ON i.member_id = m.id
        WHERE i.status = 'issued'
        AND i.due_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 2 DAY)
        AND NOT EXISTS (
          SELECT 1 FROM notifications n 
          WHERE n.related_id = i.id 
          AND n.related_type = 'issue' 
          AND n.type = 'due_soon'
          AND DATE(n.created_at) = CURDATE()
        )
      `, (err) => {
        if (err) console.log('Note: notifications insert skipped');
        resolve();
      });
    });
  });
};

const generateNotifications = async (opts = {}) => {
  const force = opts.force === true;
  const now = Date.now();
  if (!force && now - _generateNotificationsLastRun < GENERATE_NOTIFICATIONS_MIN_INTERVAL_MS) {
    return;
  }
  if (_generateNotificationsInflight) {
    return _generateNotificationsInflight;
  }
  _generateNotificationsInflight = (async () => {
    try {
      await _generateNotificationsCore();
      _generateNotificationsLastRun = Date.now();
    } finally {
      _generateNotificationsInflight = null;
    }
  })();
  return _generateNotificationsInflight;
};

// MySQL connection pool for better concurrency with large operations
const db = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'library_management',
  charset: 'utf8mb4',
  waitForConnections: true,
  connectionLimit: parseInt(process.env.DB_POOL_SIZE, 10) || 20,
  maxIdle: parseInt(process.env.DB_POOL_MAX_IDLE, 10) || 10,
  idleTimeout: parseInt(process.env.DB_POOL_IDLE_MS, 10) || 60000,
  // 0 = unlimited queue. With max connections enforced by the pool, an
  // unlimited queue lets us absorb traffic spikes rather than 503-ing
  // clients; the OS will still error out if memory is exhausted.
  queueLimit: 0,
  connectTimeout: 10000,  // fail fast rather than waiting 60s on bad network
  enableKeepAlive: true,  // Keep connections alive
  keepAliveInitialDelay: 10000,
});

// Statement timeout: kill any single query that runs longer than this.
// MySQL 5.7+ supports MAX_EXECUTION_TIME (millis) for SELECTs. Without this
// a single bad query can pin a pool connection forever.
const STATEMENT_TIMEOUT_MS = parseInt(process.env.STATEMENT_TIMEOUT_MS, 10) || 30000;

function applyStatementTimeout(conn, cb) {
  // Only SELECTs honour MAX_EXECUTION_TIME; writes are bounded by
  // innodb_lock_wait_timeout (default 50s) and by our connectTimeout.
  conn.query('SET SESSION MAX_EXECUTION_TIME=' + STATEMENT_TIMEOUT_MS, (err) => {
    cb(err, conn);
  });
}

// Wrap db.getConnection so every acquired connection has the timeout applied.
const _origGetConnection = db.getConnection.bind(db);
db.getConnection = function patchedGetConnection(cb) {
  _origGetConnection((err, conn) => {
    if (err) return cb(err);
    applyStatementTimeout(conn, cb);
  });
};

// Test pool connection on startup
db.getConnection((err, conn) => {
  if (err) {
    console.error('Database connection failed:', err.message);
    console.log('Server will continue with sample data only');
  } else {
    console.log('Connected to MySQL database (pool)');
    conn.release();
    // Run migrations on startup (skip in unit tests).
    if (process.env.NODE_ENV !== 'test') {
      runMigrations().catch(e => console.error('Migration error:', e.message));
    }
  }
});

// Run database migrations sequentially to avoid deadlocks
const runMigrations = async () => {
  const dbName = db.config?.database || process.env.DB_NAME || 'library_management';

  // Helper: promisified single-query execution
  const run = (sql) =>
    new Promise((resolve) => {
      db.query(sql, (err) => {
        if (err && !err.message.includes('Duplicate') && !err.message.includes('already exists')) {
          console.warn('Migration warning:', err.message.substring(0, 120));
        }
        resolve(); // always resolve ΓÇô migrations are best-effort
      });
    });

  const migrations = [
    // ΓöÇΓöÇ Character-set conversions ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    `ALTER DATABASE \`${dbName}\` CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci`,
    "ALTER TABLE books CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE members CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE issues CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE users CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE notifications CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE member_categories CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE book_categories CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE dashboard_settings CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",

    // ΓöÇΓöÇ Schema additions (books) ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    "ALTER TABLE books MODIFY COLUMN isbn VARCHAR(20) NULL",
    "ALTER TABLE books ADD COLUMN cover_image TEXT",
    "ALTER TABLE books ADD COLUMN total_copies INT DEFAULT 1",
    "ALTER TABLE books ADD COLUMN available_copies INT DEFAULT 1",
    "ALTER TABLE books ADD COLUMN description TEXT",
    "ALTER TABLE books ADD COLUMN rack_number VARCHAR(50)",

    // ΓöÇΓöÇ Schema additions (members) ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    // Support the expanded member type set while remaining backward compatible with existing 'student' values.
    "ALTER TABLE members MODIFY COLUMN member_type ENUM('student', 'guest', 'faculty', 'staff', 'additional_director', 'joint_director', 'deputy_director', 'assistant_commissioner', 'state_tax_officer', 'assistant') NOT NULL DEFAULT 'guest'",
    "UPDATE members SET member_type = 'guest' WHERE member_type = 'student'",
    "ALTER TABLE members ADD COLUMN profile_photo TEXT",
    "ALTER TABLE members ADD COLUMN address TEXT",
    "ALTER TABLE members ADD COLUMN expiry_date DATE",
    "ALTER TABLE members ADD COLUMN is_active BOOLEAN DEFAULT TRUE",

    // ΓöÇΓöÇ Schema additions (issues) ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    "ALTER TABLE issues ADD COLUMN notes TEXT",
    // Activity timestamps (enable truly realtime Recent Activity + reliable per-user Clear cutoff).
    "ALTER TABLE issues ADD COLUMN issued_at DATETIME NULL",
    "ALTER TABLE issues ADD COLUMN returned_at DATETIME NULL",

    // ΓöÇΓöÇ Schema additions (members ΓÇô timestamps) ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    "ALTER TABLE members ADD COLUMN created_at DATETIME NULL",


    // ─── Schema additions (users – password rotation) ───────────────────────────────────
    // must_change_password is set on seed and cleared by POST /api/auth/change-password.
    "ALTER TABLE users ADD COLUMN must_change_password TINYINT(1) NOT NULL DEFAULT 0",
    "ALTER TABLE users ADD COLUMN last_password_change DATETIME NULL",
    "UPDATE users SET must_change_password = 1 WHERE last_password_change IS NULL",
    // ΓöÇΓöÇ Best-effort backfill (safe to ignore if columns don't exist yet) ΓöÇ
    "UPDATE issues SET issued_at = CAST(issue_date AS DATETIME) WHERE issued_at IS NULL",
    // ΓöÇΓöÇ Performance indexes (idempotent via information_schema check) ΓöÇΓöÇ
    // Indexes for hot WHERE/ORDER BY columns that were missing in the original schema.
    // MySQL 5.7 doesn't support CREATE INDEX IF NOT EXISTS, so we check information_schema first.
    (async () => {
      const REQUIRED_INDEXES =     [
      {
        "table": "books",
        "name": "idx_status",
        "cols": "(status)"
      },
      {
        "table": "books",
        "name": "idx_added_date",
        "cols": "(added_date)"
      },
      {
        "table": "books",
        "name": "idx_status_avail",
        "cols": "(status, available_copies)"
      },
      {
        "table": "issues",
        "name": "idx_member_status",
        "cols": "(member_id, status)"
      },
      {
        "table": "issues",
        "name": "idx_book_status",
        "cols": "(book_id, status)"
      },
      {
        "table": "issues",
        "name": "idx_return_date",
        "cols": "(return_date)"
      },
      {
        "table": "members",
        "name": "idx_is_active",
        "cols": "(is_active)"
      },
      {
        "table": "members",
        "name": "idx_member_type",
        "cols": "(member_type)"
      },
      {
        "table": "members",
        "name": "idx_expiry_date",
        "cols": "(expiry_date)"
      },
      {
        "table": "notifications",
        "name": "idx_related",
        "cols": "(related_id, related_type)"
      },
      {
        "table": "borrow_slips",
        "name": "idx_issue_id",
        "cols": "(issue_id)"
      },
      {
        "table": "borrow_slips",
        "name": "idx_generated_at",
        "cols": "(generated_at)"
      },
      {
        "table": "book_recommendations",
        "name": "idx_member_id",
        "cols": "(member_id)"
      },
      {
        "table": "book_recommendations",
        "name": "idx_book_id",
        "cols": "(book_id)"
      }
    ];
      for (const idx of REQUIRED_INDEXES) {
        try {
          const [existing] = await db.promise().query(
            "SELECT 1 FROM information_schema.statistics WHERE table_schema = ? AND table_name = ? AND index_name = ? LIMIT 1",
            [process.env.DB_NAME || 'library_management', idx.table, idx.name]
          );
          if (existing.length === 0) {
            // Build CREATE INDEX with parameterised table/column names from a
            // hard-coded list, so SQL injection isn't a concern.
            const sql = 'CREATE INDEX `' + idx.name + '` ON `' + idx.table + '` ' + idx.cols;
            await db.promise().query(sql);
            console.log('[migrate] created index ' + idx.name + ' on ' + idx.table);
          }
        } catch (e) {
          // table doesn't exist (older schema) or insufficient privileges; safe to ignore.
        }
      }
    })(),
    "UPDATE issues SET returned_at = CAST(return_date AS DATETIME) WHERE returned_at IS NULL AND return_date IS NOT NULL",
    "UPDATE members SET created_at = CAST(membership_date AS DATETIME) WHERE created_at IS NULL",

    // ΓöÇΓöÇ New tables ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    `CREATE TABLE IF NOT EXISTS member_categories (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(50) UNIQUE NOT NULL,
      max_books INT DEFAULT 3,
      loan_period_days INT DEFAULT 14,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    `CREATE TABLE IF NOT EXISTS book_categories (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(100) UNIQUE NOT NULL,
      description TEXT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    `CREATE TABLE IF NOT EXISTS notifications (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT,
      title VARCHAR(255) NOT NULL,
      message TEXT NOT NULL,
      type VARCHAR(50) DEFAULT 'info',
      is_read BOOLEAN DEFAULT FALSE,
      related_id INT,
      related_type VARCHAR(50),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    `CREATE TABLE IF NOT EXISTS dashboard_settings (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT,
      widget_name VARCHAR(100) NOT NULL,
      is_visible BOOLEAN DEFAULT TRUE,
      position INT DEFAULT 0,
      settings JSON
    )`,
    `CREATE TABLE IF NOT EXISTS activity_events (
      id INT AUTO_INCREMENT PRIMARY KEY,
      type VARCHAR(50) NOT NULL,
      related_id INT NULL,
      related_type VARCHAR(50) NULL,
      title VARCHAR(255) NULL,
      description TEXT NULL,
      occurred_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_occurred_at (occurred_at),
      INDEX idx_type (type)
    ) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

    // ΓöÇΓöÇ Seed data ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    `INSERT IGNORE INTO member_categories (name, max_books, loan_period_days) VALUES
      ('student', 3, 14)`,
    `INSERT IGNORE INTO member_categories (name, max_books, loan_period_days) VALUES
      ('faculty', 10, 30)`,
    `INSERT IGNORE INTO member_categories (name, max_books, loan_period_days) VALUES
      ('staff', 5, 21)`,
    "UPDATE books SET total_copies = 1, available_copies = CASE WHEN status = 'available' THEN 1 ELSE 0 END WHERE total_copies IS NULL",

    // ΓöÇΓöÇ Indexes for large-database performance ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    // These are now declared in schema_v2.sql and added by the second-pass
    // runtime migration block at the top of runMigrations(). We keep NO
    // inline CREATE INDEX here so that re-running migrations on an
    // already-indexed database doesn't recreate the same indexes (which
    // would otherwise balloon the index count and slow down writes). The
    // run() helper above silently swallows duplicate-key errors, but the
    // extra indexes were still piling up - see audit pass.

    // ΓöÇΓöÇ Borrow Slips table ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    `CREATE TABLE IF NOT EXISTS borrow_slips (
      id INT AUTO_INCREMENT PRIMARY KEY,
      issue_id INT NOT NULL,
      slip_number VARCHAR(100) UNIQUE NOT NULL,
      generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      pdf_data JSON,
      FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE
    )`
  ];

  // Run each migration one at a time to prevent deadlocks
  for (const sql of migrations) {
    await run(sql);
  }
  console.log('Database migrations completed');
};

// Middleware for authentication. We return a machine-readable `code` so the
// Flutter client can distinguish "token expired, please log in again" from
// "token is malformed/forged, drop the session" from "you don't have
// permission for this route" (the last one is enforced by `requireRole`).
const authenticateToken = (req, res, next) => {
  const token = req.header('Authorization')?.split(' ')[1];
  if (!token) {
    return res.status(401).json({ error: 'Access denied', code: 'AUTH_MISSING' });
  }

  if (!JWT_SECRET) {
    return res.status(500).json({ error: 'Server misconfigured: missing JWT secret' });
  }

  jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] }, (err, user) => {
    if (err) {
      // TokenExpiredError is a sub-class of JsonWebTokenError; check it
      // first. We use 401 for expired/missing and 403 for invalid/forged so
      // a forged token doesn't get treated as a routine session timeout.
      if (err.name === 'TokenExpiredError') {
        return res
          .status(401)
          .json({ error: 'Token expired', code: 'AUTH_EXPIRED' });
      }
      return res
        .status(403)
        .json({ error: 'Invalid token', code: 'AUTH_INVALID' });
    }
    req.user = user;
    next();
  });
};

// Role-based access control. Use AFTER authenticateToken.
const requireRole = (...roles) => (req, res, next) => {
  if (!req.user || !roles.includes(req.user.role)) {
    return res
      .status(403)
      .json({ error: 'Insufficient permissions', code: 'AUTH_FORBIDDEN' });
  }
  next();
};

// ==================== HEALTH CHECK ROUTES ====================

// Basic health check (no auth required)
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0',
  });
});

// Detailed health check with database status
app.get('/api/health/detailed', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0',
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    database: { status: 'unknown' },
  };

  try {
    const [rows] = await db.promise().query('SELECT 1 as test');
    health.database = {
      status: rows && rows.length > 0 ? 'connected' : 'error',
      type: 'mysql',
    };
  } catch (err) {
    health.status = 'degraded';
    health.database = {
      status: 'disconnected',
      error: err.message,
    };
  }

  const statusCode = health.status === 'healthy' ? 200 : 503;
  res.status(statusCode).json(health);
});

// ==================== AUTH ROUTES ====================

app.post(
  '/api/auth/login',
  loginLimiter,
  body('username').isString().trim().isLength({ min: 1, max: 64 }),
  body('password').isString().isLength({ min: 1, max: 256 }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Invalid login request' });
    }

    const { username, password } = req.body;
    // Use a generic message for unknown-user vs bad-password to avoid
    // leaking which usernames exist. Use the same status + code in both
    // cases. We still distinguish non-admin accounts in a separate 403 to
    // avoid silently allowing non-admins to authenticate through this
    // system.
    const invalidCredentials = () =>
      res.status(401).json({ error: 'Invalid credentials', code: 'AUTH_FAILED' });

    db.query('SELECT * FROM users WHERE username = ?', [username], async (err, results) => {
      if (err) return res.status(500).json({ error: err.message });
      if (results.length === 0) return invalidCredentials();

      const user = results[0];

      if (user.role !== 'admin') {
        return res.status(403).json({ error: 'Only admin users are allowed to access this system' });
      }

      const validPassword = await bcrypt.compare(password, user.password_hash);
      if (!validPassword) return invalidCredentials();

      if (!JWT_SECRET) {
        return res.status(500).json({ error: 'Server misconfigured: missing JWT secret' });
      }

      const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, {
        expiresIn: JWT_EXPIRES_IN,
        algorithm: 'HS256',
      });
      res.json({
        token,
        user: {
          id: user.id,
          username: user.username,
          role: user.role,
          mustChangePassword: user.must_change_password === 1 || user.must_change_password === true,
        },
      });
    });
  }
);

// Public auth routes. Anything else under /api requires a valid admin token.
const PUBLIC_API_ROUTES = new Set(['/auth/login', '/auth/change-password']);
// Apply the general rate limiter FIRST so it sees every /api request,
// including the ones that will be rejected by the auth checks below.
app.use('/api', apiLimiter);
app.use('/api', (req, res, next) => {
  if (PUBLIC_API_ROUTES.has(req.path)) return next();
  return authenticateToken(req, res, next);
});
app.use('/api', (req, res, next) => {
  if (PUBLIC_API_ROUTES.has(req.path)) return next();
  return requireRole('admin')(req, res, next);
});

// Change the current user's password. Public (no JWT required) so a user
// forced to rotate can do so even after their session expires. We still
// verify the current password and issue a fresh token on success.
app.post(
  '/api/auth/change-password',
  loginLimiter,
  body('currentPassword').isString().isLength({ min: 1, max: 256 }),
  body('newPassword').isString().isLength({ min: 8, max: 256 }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Invalid request' });
    }
    const auth = req.header('Authorization') || '';
    const bearer = auth.startsWith('Bearer ') ? auth.slice(7) : null;
    let userId = null;
    if (bearer && JWT_SECRET) {
      try {
        const decoded = jwt.verify(bearer, JWT_SECRET, { algorithms: ['HS256'] });
        userId = decoded.id;
      } catch (_) {
        // Fall through: maybe the token was cleared on the client.
      }
    }
    if (!userId) {
      return res.status(401).json({ error: 'Authentication required', code: 'AUTH_MISSING' });
    }

    const { currentPassword, newPassword } = req.body;
    db.query(
      'SELECT id, password_hash FROM users WHERE id = ? LIMIT 1',
      [userId],
      async (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        if (!results || results.length === 0) {
          return res.status(404).json({ error: 'User not found' });
        }
        const ok = await bcrypt.compare(currentPassword, results[0].password_hash);
        if (!ok) {
          return res.status(401).json({ error: 'Current password is incorrect', code: 'AUTH_FAILED' });
        }
        if (currentPassword === newPassword) {
          return res.status(400).json({ error: 'New password must be different from the current one' });
        }
        const newHash = await bcrypt.hash(newPassword, 10);
        db.query(
          'UPDATE users SET password_hash = ?, must_change_password = 0, last_password_change = NOW() WHERE id = ?',
          [newHash, userId],
          (updateErr) => {
            if (updateErr) {
              return res.status(500).json({ error: updateErr.message });
            }
            if (JWT_SECRET) {
              const fresh = jwt.sign(
                { id: userId, role: 'admin' },
                JWT_SECRET,
                { expiresIn: JWT_EXPIRES_IN, algorithm: 'HS256' }
              );
              return res.json({ token: fresh, mustChangePassword: false });
            }
            return res.json({ mustChangePassword: false });
          }
        );
      }
    );
  }
);

// Current authenticated user
app.get('/api/auth/me', (req, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Access denied' });
  db.query(
    'SELECT id, username, role, must_change_password FROM users WHERE id = ? LIMIT 1',
    [userId],
    (err, results) => {
      if (err) return res.status(500).json({ error: err.message });
      if (!results || results.length === 0) return res.status(404).json({ error: 'User not found' });
      const u = results[0];
      res.json({
        user: {
          id: u.id,
          username: u.username,
          role: u.role,
          mustChangePassword: u.must_change_password === 1 || u.must_change_password === true,
        },
      });
    }
  );
});

// ==================== BOOKS ROUTES ====================

// GET /api/books - Supports pagination for large datasets
// Query params: page (1-based), limit (default 100, max 1000), search, category, author, year, status, available
app.get('/api/books', (req, res) => {
  const { search, category, author, year, status, available, page, limit: limitParam } = req.query;
  
  // Pagination support for large datasets
  const pageNum = parsePositiveInt(page, 1);
  const limit = Math.min(parsePositiveInt(limitParam, 100), 1000); // Max 1000 per page
  const offset = (pageNum - 1) * limit;
  
  let whereClause = 'WHERE 1=1';
  const params = [];
  
  if (search) {
    whereClause += ' AND (title LIKE ? OR author LIKE ? OR isbn LIKE ?)';
    const searchTerm = `%${search}%`;
    params.push(searchTerm, searchTerm, searchTerm);
  }
  if (category) {
    whereClause += ' AND category = ?';
    params.push(category);
  }
  if (author) {
    whereClause += ' AND author LIKE ?';
    params.push(`%${author}%`);
  }
  if (year) {
    whereClause += ' AND year_published = ?';
    params.push(year);
  }
  if (status) {
    whereClause += ' AND status = ?';
    params.push(status);
  }
  if (available === 'true') {
    whereClause += ' AND (available_copies > 0 OR status = "available")';
  }
  
  // Two simple queries instead of SQL_CALC_FOUND_ROWS + FOUND_ROWS().
  // SQL_CALC_FOUND_ROWS is deprecated in MySQL 8.0.17+.
  const dataQuery = `SELECT * FROM books ${whereClause} ORDER BY title ASC LIMIT ? OFFSET ?`;
  const dataParams = [...params, limit, offset];
  const countQuery = `SELECT COUNT(*) AS total FROM books ${whereClause}`;
  const countParams = [...params];

  db.query(dataQuery, dataParams, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });

    db.query(countQuery, countParams, (countErr, countResults) => {
      if (countErr) return res.status(500).json({ error: countErr.message });

      const total = Number(countResults[0]?.total || 0);
      const totalPages = Math.ceil(total / limit);
      
      // Return with pagination metadata
      res.json({
        data: results,
        pagination: {
          page: pageNum,
          limit,
          total,
          totalPages,
          hasMore: pageNum < totalPages
        }
      });
    });
  });
});

app.get('/api/books/:id', (req, res) => {
  db.query('SELECT * FROM books WHERE id = ?', [req.params.id], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0) return res.status(404).json({ error: 'Book not found' });
    res.json(results[0]);
  });
});

app.post('/api/books', (req, res) => {
  const {
    isbn,
    title,
    author,
    rack_number,
    category,
    publisher,
    year_published,
    cover_image,
    total_copies,
    description,
  } = req.body;
  if (!title || !author) {
    return res.status(400).json({ error: 'Title and author are required' });
  }

  const normalizedIsbn = typeof isbn === 'string' && isbn.trim() !== '' ? isbn.trim() : null;
  const normalizedRack = typeof rack_number === 'string' && rack_number.trim() !== '' ? rack_number.trim() : null;
  const copies = total_copies || 1;
  
  db.query(
    'INSERT INTO books (isbn, title, author, rack_number, category, publisher, year_published, cover_image, total_copies, available_copies, description) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      normalizedIsbn,
      title,
      author,
      normalizedRack,
      category || null,
      publisher || null,
      year_published || null,
      cover_image || null,
      copies,
      copies,
      description || null,
    ],
    (err, result) => {
      if (err) return res.status(500).json({ error: err.message });
      
      // Create notification for new book
      db.query(
        `INSERT INTO notifications (user_id, title, message, type, related_id, related_type)
         SELECT id, ?, ?, 'new_book', ?, 'book' FROM users WHERE role = 'admin' LIMIT 1`,
        [`New Book Added: ${title}`, `"${title}" by ${author} has been added to the library.`, result.insertId]
      );

      // Dashboard activity
      logActivityEvent({
        type: 'book_added',
        related_id: result.insertId,
        related_type: 'book',
        title: `New book: ${title}`,
        description: `"${title}" by ${author}`,
      });
      
      res.json({ id: result.insertId });
    }
  );
});

app.put('/api/books/:id', (req, res) => {
  const {
    isbn,
    title,
    author,
    rack_number,
    category,
    publisher,
    year_published,
    cover_image,
    total_copies,
    description,
  } = req.body;
  if (!title || !author) {
    return res.status(400).json({ error: 'Title and author are required' });
  }

  const normalizedIsbn = typeof isbn === 'string' && isbn.trim() !== '' ? isbn.trim() : null;
  const normalizedRack = typeof rack_number === 'string' && rack_number.trim() !== '' ? rack_number.trim() : null;
  
  // First get current book data
  db.query('SELECT * FROM books WHERE id = ?', [req.params.id], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0) return res.status(404).json({ error: 'Book not found' });
    
    const currentBook = results[0];
    const newTotalCopies = total_copies !== undefined ? total_copies : (currentBook.total_copies || 1);
    const currentTotal = currentBook.total_copies || 1;
    const currentAvailable = currentBook.available_copies !== undefined ? currentBook.available_copies : (currentBook.status === 'available' ? 1 : 0);
    const issuedCopies = currentTotal - currentAvailable;
    const newAvailableCopies = Math.max(0, newTotalCopies - issuedCopies);
    
    // Determine new status
    let newStatus = 'available';
    if (newAvailableCopies <= 0) {
      newStatus = 'issued';
    }
    
    db.query(
      'UPDATE books SET isbn = ?, title = ?, author = ?, rack_number = ?, category = ?, publisher = ?, year_published = ?, cover_image = ?, total_copies = ?, available_copies = ?, description = ?, status = ? WHERE id = ?',
      [
        normalizedIsbn,
        title,
        author,
        normalizedRack,
        category || null,
        publisher || null,
        year_published || null,
        cover_image || null,
        newTotalCopies,
        newAvailableCopies,
        description || null,
        newStatus,
        req.params.id,
      ],
      (err) => {
        if (err) return res.status(500).json({ error: err.message });
        logActivityEvent({
          type: 'book_updated',
          related_id: Number(req.params.id),
          related_type: 'book',
          title: `Book updated: ${title}`,
          description: `Updated details for "${title}" by ${author}.`,
        });
        res.json({ message: 'Book updated' });
      }
    );
  });
});

app.delete('/api/books/:id', (req, res) => {
  db.query('DELETE FROM books WHERE id = ?', [req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Book deleted' });
  });
});

// Bulk delete books - optimized for large deletions
app.post('/api/books/bulk-delete', async (req, res) => {
  const { ids } = req.body;
  
  if (!Array.isArray(ids) || ids.length === 0) {
    return res.status(400).json({ error: 'No book IDs provided' });
  }
  
  // Validate all IDs are numbers
  const validIds = ids.filter(id => Number.isFinite(Number(id))).map(Number);
  if (validIds.length === 0) {
    return res.status(400).json({ error: 'No valid book IDs provided' });
  }
  
  try {
    // Use a single DELETE query with IN clause for efficiency
    const placeholders = validIds.map(() => '?').join(',');
    const query = `DELETE FROM books WHERE id IN (${placeholders})`;
    
    const result = await dbQuery(query, validIds);
    const deletedCount = result.affectedRows || 0;
    
    res.json({ 
      message: `Deleted ${deletedCount} book(s)`,
      deleted: deletedCount,
      requested: validIds.length
    });
  } catch (err) {
    console.error('Bulk delete error:', err);
    res.status(500).json({ error: err.message || 'Bulk delete failed' });
  }
});

// Import books from CSV/XLSX. Required: title + author. Optional: rack_number, isbn.
// Optimized for large imports (10k+ books) using batch inserts.
app.post('/api/books/import', importUpload.single('file'), async (req, res) => {
  // Disable request timeout for large imports
  req.setTimeout(0);
  res.setTimeout(0);
  
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });

    const ext = path.extname(req.file.originalname || '').toLowerCase();

    let rows = [];
    if (ext === '.csv') {
      const csvText = decodeTextBuffer(req.file.buffer);
      rows = parseCsv(csvText, {
        columns: true,
        skip_empty_lines: true,
        bom: true,
        relax_column_count: true,
        trim: true,
      });
    } else {
      const workbook = xlsx.read(req.file.buffer, { type: 'buffer' });
      const sheetName = workbook.SheetNames?.[0];
      if (!sheetName) return res.status(400).json({ error: 'No worksheet found in file' });
      const sheet = workbook.Sheets[sheetName];
      rows = xlsx.utils.sheet_to_json(sheet, { defval: '', raw: false });
    }

    const normalizeKey = (k) => String(k || '')
      .toLowerCase()
      .replace(/\s+/g, '')
      .replace(/_/g, '')
      .replace(/-/g, '');

    const pick = (obj, keys) => {
      const map = new Map();
      Object.keys(obj || {}).forEach((k) => map.set(normalizeKey(k), obj[k]));
      for (const key of keys) {
        const v = map.get(normalizeKey(key));
        if (v !== undefined) return v;
      }
      return undefined;
    };

    const titleKeys = ['title', 'book', 'bookname', 'name'];
    const authorKeys = ['author', 'authorname'];
    const rackKeys = ['rack', 'racknumber', 'rackno', 'racknum', 'racklocation'];
    const isbnKeys = ['isbn'];
    const categoryKeys = ['category', 'categoryname', 'genre', 'type', 'subject'];
    const descriptionKeys = ['description', 'desc', 'summary', 'about'];
    const publisherKeys = ['publisher', 'publishername', 'pub'];
    const yearKeys = ['year', 'yearpublished', 'publishedyear', 'pubyear', 'publicationyear'];
    const copiesKeys = ['copy', 'copies', 'totalcopies', 'quantity', 'qty', 'count', 'noofcopies', 'numberofcopies'];

    const looksLikeLegacyHindi = (text) => {
      const s = String(text || '').trim();
      if (!s) return false;
      if (/[\u0900-\u097F]/.test(s)) return false;
      const letters = (s.match(/[A-Za-z]/g) || []).length;
      if (letters < 6) return false;
      const special = (s.match(/[;*]/g) || []).length;
      if (special < 1) return false;
      const ratio = letters / Math.max(s.length, 1);
      return ratio >= 0.55;
    };

    let inserted = 0;
    let updated = 0;
    let skipped = 0;
    let legacyHindiRows = 0;
    const errors = [];

    // Parse all rows first
    const validBooks = [];
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const title = String(pick(row, titleKeys) ?? '').trim();
      const author = String(pick(row, authorKeys) ?? '').trim();
      const rackNumber = String(pick(row, rackKeys) ?? '').trim();
      const isbn = String(pick(row, isbnKeys) ?? '').trim();
      const category = String(pick(row, categoryKeys) ?? '').trim();
      const description = String(pick(row, descriptionKeys) ?? '').trim();
      const publisher = String(pick(row, publisherKeys) ?? '').trim();
      const yearRaw = pick(row, yearKeys);
      const year = yearRaw ? parseInt(String(yearRaw).trim(), 10) : null;
      const copiesRaw = pick(row, copiesKeys);
      const copies = copiesRaw ? parseInt(String(copiesRaw).trim(), 10) : 1;
      const totalCopies = (copies && !isNaN(copies) && copies > 0) ? copies : 1;

      if (!title || !author) {
        skipped++;
        if (errors.length < 100) {
          errors.push({ row: i + 2, error: 'Missing required Title or Author' });
        }
        continue;
      }

      if (looksLikeLegacyHindi(title) || looksLikeLegacyHindi(author)) {
        legacyHindiRows++;
      }

      validBooks.push({
        rowIndex: i + 2,
        isbn: isbn || null,
        title,
        author,
        rackNumber: rackNumber || null,
        category: category || null,
        description: description || null,
        publisher: publisher || null,
        year: (year && !isNaN(year)) ? year : null,
        totalCopies,
      });
    }

    // Process in batches for better performance
    const BATCH_SIZE = 500;
    
    for (let batchStart = 0; batchStart < validBooks.length; batchStart += BATCH_SIZE) {
      const batch = validBooks.slice(batchStart, batchStart + BATCH_SIZE);
      
      // Collect all ISBNs and title+author pairs for batch lookup
      const isbnList = batch.filter(b => b.isbn).map(b => b.isbn);
      const titleAuthorPairs = batch.map(b => `${b.title}|||${b.author}`);
      
      // Batch lookup existing books
      const existingByIsbn = new Map();
      const existingByTitleAuthor = new Map();
      
      if (isbnList.length > 0) {
        try {
          const placeholders = isbnList.map(() => '?').join(',');
          const found = await dbQuery(
            `SELECT id, isbn, title, author FROM books WHERE isbn IN (${placeholders})`,
            isbnList
          );
          for (const row of found) {
            if (row.isbn) existingByIsbn.set(row.isbn, row.id);
          }
        } catch (e) {
          // Continue with individual lookups if batch fails
        }
      }
      
      // Batch lookup by title+author
      if (batch.length > 0) {
        try {
          // Build OR conditions for title+author pairs
          const conditions = batch.map(() => '(title = ? AND author = ?)').join(' OR ');
          const params = batch.flatMap(b => [b.title, b.author]);
          const found = await dbQuery(
            `SELECT id, title, author FROM books WHERE ${conditions}`,
            params
          );
          for (const row of found) {
            existingByTitleAuthor.set(`${row.title}|||${row.author}`, row.id);
          }
        } catch (e) {
          // Continue with individual lookups if batch fails
        }
      }
      
      // Separate books into updates and inserts
      const toUpdate = [];
      const toInsert = [];
      
      for (const book of batch) {
        let existingId = null;
        if (book.isbn && existingByIsbn.has(book.isbn)) {
          existingId = existingByIsbn.get(book.isbn);
        } else {
          const key = `${book.title}|||${book.author}`;
          if (existingByTitleAuthor.has(key)) {
            existingId = existingByTitleAuthor.get(key);
          }
        }
        
        if (existingId) {
          toUpdate.push({ ...book, existingId });
        } else {
          toInsert.push(book);
        }
      }
      
      // Batch UPDATE using CASE statements for efficiency
      if (toUpdate.length > 0) {
        try {
          for (const book of toUpdate) {
            await dbQuery(
              `UPDATE books SET title = ?, author = ?, rack_number = ?, isbn = ?, 
               category = COALESCE(?, category), description = COALESCE(?, description),
               publisher = COALESCE(?, publisher), year_published = COALESCE(?, year_published)
               WHERE id = ?`,
              [book.title, book.author, book.rackNumber, book.isbn, book.category, 
               book.description, book.publisher, book.year, book.existingId]
            );
            updated++;
          }
        } catch (e) {
          if (errors.length < 100) {
            errors.push({ batch: Math.floor(batchStart / BATCH_SIZE) + 1, error: `Update batch error: ${e.message}` });
          }
        }
      }
      
      // Batch INSERT for new books
      if (toInsert.length > 0) {
        try {
          const insertValues = toInsert.map(book => [
            book.isbn, book.title, book.author, book.rackNumber, book.category,
            book.description, book.publisher, book.year, book.totalCopies, book.totalCopies, 'available'
          ]);
          
          const placeholders = insertValues.map(() => '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)').join(', ');
          const flatParams = insertValues.flat();
          
          await dbQuery(
            `INSERT INTO books (isbn, title, author, rack_number, category, description, 
             publisher, year_published, total_copies, available_copies, status) 
             VALUES ${placeholders}`,
            flatParams
          );
          inserted += toInsert.length;
        } catch (e) {
          // If batch insert fails, try individual inserts
          for (const book of toInsert) {
            try {
              await dbQuery(
                `INSERT INTO books (isbn, title, author, rack_number, category, description, 
                 publisher, year_published, total_copies, available_copies, status) 
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'available')`,
                [book.isbn, book.title, book.author, book.rackNumber, book.category, 
                 book.description, book.publisher, book.year, book.totalCopies, book.totalCopies]
              );
              inserted++;
            } catch (e2) {
              if (errors.length < 100) {
                errors.push({ row: book.rowIndex, error: e2.message || String(e2) });
              }
            }
          }
        }
      }
    }

    return res.json({ 
      inserted, 
      updated, 
      skipped, 
      errors: errors.slice(0, 50), // Limit errors in response
      totalRows: rows.length, 
      legacyHindiRows,
      totalErrors: errors.length 
    });
  } catch (e) {
    return res.status(500).json({ error: e.message || String(e) });
  }
});

// Upload book cover image (for existing books)
app.post('/api/books/:id/cover', upload.single('cover'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  
  const imageUrl = `/uploads/${req.file.filename}`;
  db.query('SELECT cover_image FROM books WHERE id = ?', [req.params.id], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!rows || rows.length === 0) return res.status(404).json({ error: 'Book not found' });

    const oldUrl = rows[0]?.cover_image;
    db.query('UPDATE books SET cover_image = ? WHERE id = ?', [imageUrl, req.params.id], (err2) => {
      if (err2) return res.status(500).json({ error: err2.message });
      if (oldUrl && oldUrl !== imageUrl) {
        tryDeleteUploadedFile(oldUrl);
      }
      res.json({ imageUrl, storedInDb: true });
    });
  });
});

// Upload book cover image (returns URL; optionally persists to DB when book_id is provided)
app.post('/api/uploads/book-cover', upload.single('cover'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  
  const imageUrl = `/uploads/${req.file.filename}`;

  const bookIdRaw = req.body?.book_id ?? req.body?.bookId;
  const bookId = bookIdRaw !== undefined && bookIdRaw !== null && String(bookIdRaw).trim() !== ''
    ? Number(bookIdRaw)
    : null;

  if (!bookId || Number.isNaN(bookId)) {
    return res.json({ url: imageUrl, storedInDb: false });
  }

  db.query('SELECT cover_image FROM books WHERE id = ?', [bookId], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!rows || rows.length === 0) return res.status(404).json({ error: 'Book not found' });

    const oldUrl = rows[0]?.cover_image;
    db.query('UPDATE books SET cover_image = ? WHERE id = ?', [imageUrl, bookId], (err2) => {
      if (err2) return res.status(500).json({ error: err2.message });
      if (oldUrl && oldUrl !== imageUrl) {
        tryDeleteUploadedFile(oldUrl);
      }
      res.json({ url: imageUrl, storedInDb: true, book_id: bookId });
    });
  });
});

// Upload member photo (returns URL; optionally persists to DB when member_id is provided)
app.post('/api/uploads/member-photo', upload.single('photo'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  
  const imageUrl = `/uploads/${req.file.filename}`;

  const memberIdRaw = req.body?.member_id ?? req.body?.memberId;
  const memberId = memberIdRaw !== undefined && memberIdRaw !== null && String(memberIdRaw).trim() !== ''
    ? Number(memberIdRaw)
    : null;

  if (!memberId || Number.isNaN(memberId)) {
    return res.json({ url: imageUrl, storedInDb: false });
  }

  db.query('SELECT profile_photo FROM members WHERE id = ?', [memberId], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!rows || rows.length === 0) return res.status(404).json({ error: 'Member not found' });

    const oldUrl = rows[0]?.profile_photo;
    db.query('UPDATE members SET profile_photo = ? WHERE id = ?', [imageUrl, memberId], (err2) => {
      if (err2) return res.status(500).json({ error: err2.message });
      if (oldUrl && oldUrl !== imageUrl) {
        tryDeleteUploadedFile(oldUrl);
      }
      res.json({ url: imageUrl, storedInDb: true, member_id: memberId });
    });
  });
});

// ==================== BOOK CATEGORIES ROUTES ====================

app.get('/api/categories', (req, res) => {
  db.query('SELECT * FROM book_categories ORDER BY name', (err, results) => {
    if (err || results.length === 0) {
      // Fallback to predefined categories if table doesn't exist
      const defaultCategories = [
        'Fiction', 'Non-Fiction', 'Science', 'History', 'Biography', 'Literature',
        'Philosophy', 'Psychology', 'Art', 'Music', 'Technology', 'Mathematics',
        'Physics', 'Chemistry', 'Biology', 'Medicine', 'Engineering', 'Computer Science',
        'Business', 'Economics', 'Politics', 'Law', 'Religion', 'Education',
        'Sports', 'Travel', 'Cooking', 'Health', 'Self-Help', 'Poetry',
        'Drama', 'Romance', 'Mystery', 'Thriller', 'Fantasy', 'Science Fiction',
        'Horror', 'Adventure', 'Children', 'Young Adult', 'Reference', 'Comics'
      ];
      res.setHeader('Cache-Control', 'public, max-age=300, stale-while-revalidate=600');
      return res.json(defaultCategories.map((name, index) => ({ id: index + 1, name })));
    }
    res.setHeader('Cache-Control', 'public, max-age=300, stale-while-revalidate=600');
    res.json(results);
  });
});

app.post('/api/categories', (req, res) => {
  const { name, description } = req.body;
  if (!name || name.trim() === '') {
    return res.status(400).json({ error: 'Category name is required' });
  }
  db.query('INSERT INTO book_categories (name, description) VALUES (?, ?)', [name.trim(), description], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ id: result.insertId });
  });
});

app.put('/api/categories/:id', (req, res) => {
  const { name, description } = req.body;
  db.query('UPDATE book_categories SET name = ?, description = ? WHERE id = ?', [name, description || null, req.params.id], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    if (result.affectedRows === 0) return res.status(404).json({ error: 'Category not found' });
    res.json({ message: 'Category updated' });
  });
});

app.delete('/api/categories/:id', (req, res) => {
  db.query('DELETE FROM book_categories WHERE id = ?', [req.params.id], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    if (result.affectedRows === 0) return res.status(404).json({ error: 'Category not found' });
    res.json({ message: 'Category deleted' });
  });
});

// ==================== BORROW SLIPS ROUTES ====================

// Generate a borrow slip for an issue
app.post('/api/borrow-slips', (req, res) => {
  const { issue_id } = req.body;

  if (!issue_id) {
    return res.status(400).json({ error: 'Issue ID is required' });
  }

  // Get issue details with book, member, and staff info
  db.query(`
    SELECT
      i.id as issue_id,
      i.issue_date,
      i.due_date,
      i.return_date,
      i.status,
      i.notes,
      i.issued_at,
      i.returned_at,
      b.id as book_id,
      b.isbn,
      b.title as book_title,
      b.author as book_author,
      b.rack_number,
      b.category as book_category,
      b.cover_image,
      m.id as member_id,
      m.name as member_name,
      m.email as member_email,
      m.phone as member_phone,
      m.member_type,
      m.profile_photo,
      m.address as member_address,
      'Library Staff' as issued_by_name
    FROM issues i
    JOIN books b ON i.book_id = b.id
    JOIN members m ON i.member_id = m.id
    WHERE i.id = ?
  `, [issue_id], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!results || results.length === 0) {
      return res.status(404).json({ error: 'Issue not found' });
    }

    const issue = results[0];
    // Two slips generated in the same millisecond for the same issue would
// collide on the UNIQUE slip_number column. Append a short random suffix
// so we don't 500 the borrow request on a tight race.
const slipNumber = `SLIP-${Date.now()}-${issue_id}-${Math.random()
  .toString(36)
  .slice(2, 8)}`;
    // Use MySQL datetime format
    const generatedAt = new Date().toISOString().slice(0, 19).replace('T', ' ');

    // Check if slip already exists for this issue
    db.query('SELECT id FROM borrow_slips WHERE issue_id = ?', [issue_id], (err2, existingSlips) => {
      if (err2) return res.status(500).json({ error: err2.message });

      if (existingSlips && existingSlips.length > 0) {
        // Return existing slip with full issue data
        db.query(`
          SELECT
            bs.id,
            bs.issue_id,
            bs.slip_number,
            bs.generated_at,
            bs.pdf_data,
            i.id as issue_id,
            i.issue_date,
            i.due_date,
            i.return_date,
            i.status,
            i.notes,
            i.issued_at,
            i.returned_at,
            b.id as book_id,
            b.isbn,
            b.title as book_title,
            b.author as book_author,
            b.rack_number,
            b.category as book_category,
            b.cover_image as cover_image,
            m.id as member_id,
            m.name as member_name,
            m.email as member_email,
            m.phone as member_phone,
            m.member_type,
            m.profile_photo,
            m.address as member_address,
            'Library Staff' as issued_by_name
          FROM borrow_slips bs
          JOIN issues i ON bs.issue_id = i.id
          JOIN books b ON i.book_id = b.id
          JOIN members m ON i.member_id = m.id
          WHERE bs.issue_id = ?
        `, [issue_id], (err3, slipData) => {
          if (err3) return res.status(500).json({ error: err3.message });
          return res.json(slipData[0]);
        });
      } else {
        // Create new slip
        db.query(`
          INSERT INTO borrow_slips (issue_id, slip_number, generated_at, pdf_data)
          VALUES (?, ?, ?, ?)
        `, [issue_id, slipNumber, generatedAt, JSON.stringify(issue)], (err4, result) => {
          if (err4) return res.status(500).json({ error: err4.message });

          const slip = {
            id: result.insertId,
            issue_id,
            slip_number: slipNumber,
            generated_at: new Date().toISOString(),
            ...issue
          };
          res.json(slip);
        });
      }
    });
  });
});

// Get borrow slip by issue ID
app.get('/api/borrow-slips/issue/:issueId', (req, res) => {
  const { issueId } = req.params;

  db.query(`
    SELECT
      bs.id,
      bs.issue_id,
      bs.slip_number,
      bs.generated_at,
      bs.pdf_data,
      i.id as issue_id,
      i.issue_date,
      i.due_date,
      i.return_date,
      i.status,
      i.notes,
      i.issued_at,
      i.returned_at,
      b.id as book_id,
      b.isbn,
      b.title as book_title,
      b.author as book_author,
      b.rack_number,
      b.category as book_category,
      b.cover_image as cover_image,
      m.id as member_id,
      m.name as member_name,
      m.email as member_email,
      m.phone as member_phone,
      m.member_type,
      m.profile_photo,
      m.address as member_address,
      'Library Staff' as issued_by_name
    FROM borrow_slips bs
    JOIN issues i ON bs.issue_id = i.id
    JOIN books b ON i.book_id = b.id
    JOIN members m ON i.member_id = m.id
    WHERE bs.issue_id = ?
  `, [issueId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!results || results.length === 0) {
      return res.status(404).json({ error: 'Borrow slip not found' });
    }
    res.json(results[0]);
  });
});

// Get borrow slip by ID
app.get('/api/borrow-slips/:id', (req, res) => {
  const { id } = req.params;

  db.query(`
    SELECT
      bs.id,
      bs.issue_id,
      bs.slip_number,
      bs.generated_at,
      bs.pdf_data,
      i.id as issue_id,
      i.issue_date,
      i.due_date,
      i.return_date,
      i.status,
      i.notes,
      i.issued_at,
      i.returned_at,
      b.id as book_id,
      b.isbn,
      b.title as book_title,
      b.author as book_author,
      b.rack_number,
      b.category as book_category,
      b.cover_image as cover_image,
      m.id as member_id,
      m.name as member_name,
      m.email as member_email,
      m.phone as member_phone,
      m.member_type,
      m.profile_photo,
      m.address as member_address,
      'Library Staff' as issued_by_name
    FROM borrow_slips bs
    JOIN issues i ON bs.issue_id = i.id
    JOIN books b ON i.book_id = b.id
    JOIN members m ON i.member_id = m.id
    WHERE bs.id = ?
  `, [id], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!results || results.length === 0) {
      return res.status(404).json({ error: 'Borrow slip not found' });
    }
    res.json(results[0]);
  });
});

// List all borrow slips
app.get('/api/borrow-slips', (req, res) => {
  const { page = 1, limit = 50 } = req.query;
  const offset = (parseInt(page) - 1) * parseInt(limit);

  db.query(`
    SELECT bs.*, i.issue_date, i.due_date, i.status,
           b.title as book_title, b.author as book_author,
           m.name as member_name
    FROM borrow_slips bs
    JOIN issues i ON bs.issue_id = i.id
    JOIN books b ON i.book_id = b.id
    JOIN members m ON i.member_id = m.id
    ORDER BY bs.generated_at DESC
    LIMIT ? OFFSET ?
  `, [parseInt(limit), offset], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });

    db.query('SELECT COUNT(*) as total FROM borrow_slips', (err2, countResult) => {
      if (err2) return res.status(500).json({ error: err2.message });

      res.json({
        data: results,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: countResult[0].total,
          hasMore: offset + results.length < countResult[0].total
        }
      });
    });
  });
});

// Delete borrow slip
app.delete('/api/borrow-slips/:id', (req, res) => {
  const { id } = req.params;

  db.query('DELETE FROM borrow_slips WHERE id = ?', [id], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Borrow slip not found' });
    }
    res.json({ message: 'Borrow slip deleted' });
  });
});

// ==================== MEMBERS ROUTES ====================

// GET /api/members - Supports pagination for large datasets
app.get('/api/members', (req, res) => {
  const { search, type, active, page, limit: limitParam } = req.query;
  
  // Pagination support
  const pageNum = parsePositiveInt(page, 1);
  const limit = Math.min(parsePositiveInt(limitParam, 100), 1000);
  const offset = (pageNum - 1) * limit;
  
  let whereClause = 'WHERE 1=1';
  const params = [];
  
  if (search) {
    whereClause += ' AND (name LIKE ? OR email LIKE ? OR phone LIKE ?)';
    const searchTerm = `%${search}%`;
    params.push(searchTerm, searchTerm, searchTerm);
  }
  if (type) {
    whereClause += ' AND member_type = ?';
    params.push(type);
  }
  if (active !== undefined) {
    whereClause += ' AND (is_active = ? OR is_active IS NULL)';
    params.push(active === 'true');
  }
  
  // Two simple queries instead of SQL_CALC_FOUND_ROWS + FOUND_ROWS().
  const dataQuery = `SELECT m.*,
    COALESCE((SELECT COUNT(*) FROM issues i WHERE i.member_id = m.id AND i.status IN ('issued', 'overdue')), 0) AS borrow_count
    FROM members m ${whereClause} ORDER BY m.name ASC LIMIT ? OFFSET ?`;
  const dataParams = [...params, limit, offset];
  const countQuery = `SELECT COUNT(*) AS total FROM members m ${whereClause}`;

  db.query(dataQuery, dataParams, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });

    db.query(countQuery, params, (countErr, countResults) => {
      if (countErr) return res.status(500).json({ error: countErr.message });

      const total = Number(countResults[0]?.total || 0);
      const totalPages = Math.ceil(total / limit);
      
      res.json({
        data: results,
        pagination: {
          page: pageNum,
          limit,
          total,
          totalPages,
          hasMore: pageNum < totalPages
        }
      });
    });
  });
});

app.get('/api/members/:id', (req, res) => {
  db.query('SELECT * FROM members WHERE id = ?', [req.params.id], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0) return res.status(404).json({ error: 'Member not found' });
    res.json(results[0]);
  });
});

app.post('/api/members', (req, res) => {
  const { name, email, phone, member_type, membership_date, profile_photo, address, expiry_date } = req.body;

  if (!name || (typeof name === 'string' && name.trim().length === 0)) {
    return res.status(400).json({ error: 'Member name is required' });
  }

  // Prefer storing a real creation timestamp when supported.
  const insertWithCreatedAt =
    'INSERT INTO members (name, email, phone, member_type, membership_date, profile_photo, address, expiry_date, is_active, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, TRUE, NOW())';
  const insertLegacy =
    'INSERT INTO members (name, email, phone, member_type, membership_date, profile_photo, address, expiry_date, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, TRUE)';

  // Handle empty strings for date fields and nullable fields
  // Provide default values for required fields
  const today = new Date().toISOString().split('T')[0];
  const values = [
    name,
    email || null,
    phone || null,
    member_type || 'student',
    membership_date || today,
    profile_photo || null,
    address || null,
    expiry_date || null, // Convert empty string to null
  ];

  db.query(insertWithCreatedAt, values, (err, result) => {
    if (err && /Unknown column/i.test(err.message || '')) {
      return db.query(insertLegacy, values, (err2, result2) => {
        if (err2) return res.status(500).json({ error: err2.message });

        // Dashboard activity
        logActivityEvent({
          type: 'member_added',
          related_id: result2.insertId,
          related_type: 'member',
          title: `New member: ${name}`,
          description: `${name} registered`,
        });

        res.json({ id: result2.insertId });
      });
    }
    if (err) return res.status(500).json({ error: err.message });

    // Dashboard activity
    logActivityEvent({
      type: 'member_added',
      related_id: result.insertId,
      related_type: 'member',
      title: `New member: ${name}`,
      description: `${name} registered`,
    });

    res.json({ id: result.insertId });
  });
});

app.put('/api/members/:id', (req, res) => {
  (async () => {
    try {
      const id = Number(req.params.id);
      if (!Number.isFinite(id) || id <= 0) {
        return res.status(400).json({ error: 'Invalid member id' });
      }

      const existingRows = await dbQuery('SELECT * FROM members WHERE id = ? LIMIT 1', [id]);
      const existing = Array.isArray(existingRows) && existingRows.length > 0 ? existingRows[0] : null;
      if (!existing) return res.status(404).json({ error: 'Member not found' });

      const body = req.body || {};

      const name = body.name ?? existing.name;
      const email = body.email !== undefined ? (body.email || null) : existing.email;
      const phone = body.phone ?? existing.phone;

      // Support both snake_case and camelCase keys from clients.
      const memberTypeRaw = body.member_type ?? body.memberType ?? existing.member_type;
      const membershipDate = body.membership_date ?? body.membershipDate ?? existing.membership_date;
      const profilePhoto = body.profile_photo ?? body.profilePhoto ?? existing.profile_photo;
      const address = body.address !== undefined ? (body.address || null) : existing.address;
      
      // Handle expiry_date: convert empty string to null
      let expiryDate = body.expiry_date ?? body.expiryDate;
      if (expiryDate === '' || expiryDate === undefined) {
        expiryDate = existing.expiry_date;
      }
      if (expiryDate === '') {
        expiryDate = null;
      }

      const isActive = body.is_active !== undefined
        ? body.is_active !== false
        : (existing.is_active === 1 || existing.is_active === true);

      await dbQuery(
        'UPDATE members SET name = ?, email = ?, phone = ?, member_type = ?, membership_date = ?, profile_photo = ?, address = ?, expiry_date = ?, is_active = ? WHERE id = ?',
        [
          name,
          email,
          phone,
          memberTypeRaw,
          membershipDate,
          profilePhoto,
          address,
          expiryDate,
          isActive,
          id,
        ]
      );

      const wasActive = existing.is_active === 1 || existing.is_active === true;
      const statusChanged = Boolean(isActive) !== wasActive;
      const safeName = name || existing.name || `Member #${id}`;
      const description = statusChanged
        ? `Status changed to ${isActive ? 'active' : 'inactive'}`
        : 'Member profile updated';

      logActivityEvent({
        type: 'member_updated',
        related_id: id,
        related_type: 'member',
        title: `Member updated: ${safeName}`,
        description,
      });

      res.json({ message: 'Member updated' });
    } catch (err) {
      res.status(500).json({ error: err?.message || String(err) });
    }
  })();
});

app.put('/api/members/:id/deactivate', (req, res) => {
  const memberId = Number(req.params.id);
  const safeMemberId = Number.isFinite(memberId) ? memberId : null;
  db.query('UPDATE members SET is_active = FALSE WHERE id = ?', [req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    db.query('SELECT name FROM members WHERE id = ? LIMIT 1', [req.params.id], (err2, rows) => {
      const name = (!err2 && rows && rows.length > 0 && rows[0].name)
        ? rows[0].name
        : `Member #${req.params.id}`;
      logActivityEvent({
        type: 'member_deactivated',
        related_id: safeMemberId,
        related_type: 'member',
        title: `Member deactivated: ${name}`,
        description: `${name} set to inactive`,
      });
    });
    res.json({ message: 'Member deactivated' });
  });
});

app.put('/api/members/:id/activate', (req, res) => {
  const memberId = Number(req.params.id);
  const safeMemberId = Number.isFinite(memberId) ? memberId : null;
  db.query('UPDATE members SET is_active = TRUE WHERE id = ?', [req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    db.query('SELECT name FROM members WHERE id = ? LIMIT 1', [req.params.id], (err2, rows) => {
      const name = (!err2 && rows && rows.length > 0 && rows[0].name)
        ? rows[0].name
        : `Member #${req.params.id}`;
      logActivityEvent({
        type: 'member_activated',
        related_id: safeMemberId,
        related_type: 'member',
        title: `Member activated: ${name}`,
        description: `${name} set to active`,
      });
    });
    res.json({ message: 'Member activated' });
  });
});

app.delete('/api/members/:id', (req, res) => {
  // Check for active issues before deleting
  db.query(
    "SELECT COUNT(*) as count FROM issues WHERE member_id = ? AND status IN ('issued', 'overdue')",
    [req.params.id],
    (err, countResults) => {
      if (err) return res.status(500).json({ error: 'Database error' });
      if (countResults[0].count > 0) {
        return res.status(400).json({ 
          error: `Cannot delete member with ${countResults[0].count} active issue(s). Return all books first.` 
        });
      }
      db.query('DELETE FROM members WHERE id = ?', [req.params.id], (err, result) => {
        if (err) return res.status(500).json({ error: 'Database error' });
        if (result.affectedRows === 0) return res.status(404).json({ error: 'Member not found' });
        res.json({ message: 'Member deleted' });
      });
    }
  );
});

// Bulk delete members - optimized for large deletions
app.post('/api/members/bulk-delete', async (req, res) => {
  const { ids } = req.body;
  
  if (!Array.isArray(ids) || ids.length === 0) {
    return res.status(400).json({ error: 'No member IDs provided' });
  }
  
  const validIds = ids.filter(id => Number.isFinite(Number(id))).map(Number);
  if (validIds.length === 0) {
    return res.status(400).json({ error: 'No valid member IDs provided' });
  }
  
  try {
    const placeholders = validIds.map(() => '?').join(',');
    const query = `DELETE FROM members WHERE id IN (${placeholders})`;
    
    const result = await dbQuery(query, validIds);
    const deletedCount = result.affectedRows || 0;
    
    res.json({ 
      message: `Deleted ${deletedCount} member(s)`,
      deleted: deletedCount,
      requested: validIds.length
    });
  } catch (err) {
    console.error('Bulk delete members error:', err);
    res.status(500).json({ error: err.message || 'Bulk delete failed' });
  }
});

// Upload member profile photo
app.post('/api/members/:id/photo', upload.single('photo'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  
  const imageUrl = `/uploads/${req.file.filename}`;
  db.query('SELECT profile_photo FROM members WHERE id = ?', [req.params.id], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!rows || rows.length === 0) return res.status(404).json({ error: 'Member not found' });

    const oldUrl = rows[0]?.profile_photo;
    db.query('UPDATE members SET profile_photo = ? WHERE id = ?', [imageUrl, req.params.id], (err2) => {
      if (err2) return res.status(500).json({ error: err2.message });
      if (oldUrl && oldUrl !== imageUrl) {
        tryDeleteUploadedFile(oldUrl);
      }
      res.json({ imageUrl, storedInDb: true });
    });
  });
});

// Get currently borrowed books for a member (issued/overdue only)
app.get('/api/members/:id/borrowed-books', (req, res) => {
  const memberId = Number(req.params.id);
  if (!Number.isInteger(memberId) || memberId <= 0) {
    return res.status(400).json({ error: 'Invalid member id' });
  }
  // Borrowing limit is 5 per member; cap the result to a small page.
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 25, 1), 100);
  db.query(`
    SELECT i.id, i.book_id, i.issue_date, i.due_date, i.status,
           b.title, b.author, b.isbn, b.category, b.cover_image
    FROM issues i
    JOIN books b ON i.book_id = b.id
    WHERE i.member_id = ? AND i.status IN ('issued', 'overdue')
    ORDER BY i.issue_date DESC
    LIMIT ?
  `, [memberId, limit], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ borrowed_books: results, count: results.length, max_allowed: 5 });
  });
});

// Get member borrowing history
app.get('/api/members/:id/history', (req, res) => {
  const memberId = Number(req.params.id);
  if (!Number.isInteger(memberId) || memberId <= 0) {
    return res.status(400).json({ error: 'Invalid member id' });
  }
  // Cap to a reasonable page size; clients should request pagination for longer histories.
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 100, 1), 500);
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const offset = (page - 1) * limit;
  db.query(`
    SELECT i.*, b.title, b.author, b.isbn, b.category, b.cover_image
    FROM issues i
    JOIN books b ON i.book_id = b.id
    WHERE i.member_id = ?
    ORDER BY i.issue_date DESC
    LIMIT ? OFFSET ?
  `, [memberId, limit, offset], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    db.query('SELECT COUNT(*) AS total FROM issues WHERE member_id = ?', [memberId], (err2, countRows) => {
      if (err2) return res.status(500).json({ error: err2.message });
      const total = Number(countRows[0]?.total || 0);
      res.json({
        data: results,
        pagination: {
          page, limit, total,
          hasMore: offset + results.length < total,
        },
      });
    });
  });
});

// Get member borrowing limits based on type
app.get('/api/member-categories', (req, res) => {
  db.query('SELECT * FROM member_categories', (err, results) => {
    if (err || results.length === 0) {
      // Return default values if table doesn't exist
      res.setHeader('Cache-Control', 'public, max-age=300, stale-while-revalidate=600');
      return res.json([
        { name: 'student', max_books: 3, loan_period_days: 14 },
        { name: 'faculty', max_books: 10, loan_period_days: 30 },
        { name: 'staff', max_books: 5, loan_period_days: 21 }
      ]);
    }
    res.setHeader('Cache-Control', 'public, max-age=300, stale-while-revalidate=600');
    res.json(results);
  });
});

// ==================== ISSUES ROUTES ====================

// GET /api/issues - Supports pagination for large datasets
app.get('/api/issues', async (req, res) => {
  await refreshOverdueStatuses();
  try {
    await generateNotifications();
  } catch (e) {
    // Ignore notification errors
  }

  const { member_id, book_id, status, page, limit: limitParam } = req.query;
  
  // Pagination support
  const pageNum = parsePositiveInt(page, 1);
  const limit = Math.min(parsePositiveInt(limitParam, 100), 1000);
  const offset = (pageNum - 1) * limit;
  
  let whereClause = 'WHERE 1=1';
  const params = [];
  
  if (member_id) {
    whereClause += ' AND i.member_id = ?';
    params.push(member_id);
  }
  if (book_id) {
    whereClause += ' AND i.book_id = ?';
    params.push(book_id);
  }
  if (status) {
    whereClause += ' AND i.status = ?';
    params.push(status);
  }
  
  // Two simple queries instead of SQL_CALC_FOUND_ROWS + FOUND_ROWS().
  const selectFields = `i.id, i.book_id, i.member_id, i.issue_date, i.due_date, i.return_date, i.status, i.notes,
         b.title, b.author, b.cover_image,
         m.name as member_name, m.profile_photo as member_photo,
         'Library Staff' as issued_by_name`;
  const dataQuery = `SELECT ${selectFields}
    FROM issues i
    JOIN books b ON i.book_id = b.id
    JOIN members m ON i.member_id = m.id
    ${whereClause} ORDER BY i.issue_date DESC LIMIT ? OFFSET ?`;
  const dataParams = [...params, limit, offset];
  const countQuery = `SELECT COUNT(*) AS total
    FROM issues i
    JOIN books b ON i.book_id = b.id
    JOIN members m ON i.member_id = m.id
    ${whereClause}`;

  db.query(dataQuery, dataParams, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });

    db.query(countQuery, params, (countErr, countResults) => {
      if (countErr) return res.status(500).json({ error: countErr.message });

      const total = Number(countResults[0]?.total || 0);
      const totalPages = Math.ceil(total / limit);
      
      res.json({
        data: results,
        pagination: {
          page: pageNum,
          limit,
          total,
          totalPages,
          hasMore: pageNum < totalPages
        }
      });
    });
  });
});

// Get single issue by ID
app.get('/api/issues/:id', (req, res) => {
  db.query(`
    SELECT i.*, b.title as book_title, b.author as book_author, b.isbn,
           m.name as member_name, m.email as member_email, m.phone as member_phone, m.member_type,
           'Library Staff' as issued_by_name
    FROM issues i
    JOIN books b ON i.book_id = b.id
    JOIN members m ON i.member_id = m.id
    WHERE i.id = ?
  `, [req.params.id], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!results || results.length === 0) {
      return res.status(404).json({ error: 'Issue not found' });
    }
    res.json(results[0]);
  });
});

app.post('/api/issues', async (req, res) => {
  const { book_id, member_id, due_date } = req.body;

  // Validate before opening a transaction. A bad book_id or member_id would
  // otherwise surface as a generic MySQL error from the FOR UPDATE query.
  const bookIdNum = Number(book_id);
  const memberIdNum = Number(member_id);
  if (!Number.isInteger(bookIdNum) || bookIdNum <= 0) {
    return res.status(400).json({ error: 'book_id must be a positive integer' });
  }
  if (!Number.isInteger(memberIdNum) || memberIdNum <= 0) {
    return res.status(400).json({ error: 'member_id must be a positive integer' });
  }
  if (due_date !== undefined && due_date !== null && !/^\d{4}-\d{2}-\d{2}$/.test(String(due_date))) {
    return res.status(400).json({ error: 'due_date must be YYYY-MM-DD' });
  }

  const now = new Date();
  const issue_date = now.toISOString().split('T')[0];

  try {
    const txResult = await withTransaction(async (connection) => {
      // Lock the book row first to serialize competing issue requests.
      const bookResults = await dbQueryWithConnection(
        connection,
        'SELECT id, title, status, total_copies, available_copies FROM books WHERE id = ? FOR UPDATE',
        [book_id]
      );

      if (!bookResults || bookResults.length === 0) {
        throw createHttpError(404, { error: 'Book not found' });
      }

      const book = bookResults[0];
      const rawAvailable = book.available_copies;
      const availableCopies = rawAvailable !== undefined && rawAvailable !== null
        ? Number(rawAvailable)
        : (book.status === 'available' ? 1 : 0);

      if (!Number.isFinite(availableCopies) || availableCopies <= 0) {
        throw createHttpError(400, { error: 'No copies available for this book' });
      }

      // Lock the member row so parallel issue requests for the same member don't bypass limits.
      const memberResults = await dbQueryWithConnection(
        connection,
        'SELECT id, name FROM members WHERE id = ? FOR UPDATE',
        [member_id]
      );

      if (!memberResults || memberResults.length === 0) {
        throw createHttpError(404, { error: 'Member not found' });
      }

      const member = memberResults[0];
      const maxBooks = 5; // Universal borrowing limit: 5 books per member

      const countResults = await dbQueryWithConnection(
        connection,
        "SELECT COUNT(*) AS count FROM issues WHERE member_id = ? AND status IN ('issued', 'overdue')",
        [member_id]
      );

      const currentBorrowed = Number(countResults?.[0]?.count || 0);
      if (currentBorrowed >= maxBooks) {
        throw createHttpError(400, {
          error: `Member has reached maximum borrowing limit of ${maxBooks} books. Please return some books before borrowing new ones.`,
          current_borrowed: currentBorrowed,
          max_allowed: maxBooks,
        });
      }

      const insertWithIssuedAt =
        'INSERT INTO issues (book_id, member_id, issue_date, due_date, issued_at) VALUES (?, ?, ?, ?, NOW())';
      const insertLegacy =
        'INSERT INTO issues (book_id, member_id, issue_date, due_date) VALUES (?, ?, ?, ?)';
      const insertValues = [book_id, member_id, issue_date, due_date];

      let insertResult;
      try {
        insertResult = await dbQueryWithConnection(connection, insertWithIssuedAt, insertValues);
      } catch (err) {
        if (!/Unknown column/i.test(err.message || '')) {
          throw err;
        }
        insertResult = await dbQueryWithConnection(connection, insertLegacy, insertValues);
      }

      const totalCopiesRaw = Number(book.total_copies);
      const totalCopies = Number.isFinite(totalCopiesRaw) && totalCopiesRaw > 0 ? totalCopiesRaw : 1;
      const newAvailable = Math.max(availableCopies - 1, 0);
      const newStatus = newAvailable <= 0 ? 'issued' : 'available';

      await dbQueryWithConnection(
        connection,
        'UPDATE books SET available_copies = ?, status = ? WHERE id = ?',
        [newAvailable, newStatus, book_id]
      );

      return {
        issueId: insertResult.insertId,
        bookTitle: book?.title ?? '',
        memberName: member?.name ?? 'Someone',
      };
    });

    // Activity logging is best-effort and should not block successful issuance.
    logActivityEvent({
      type: 'issue',
      related_id: txResult.issueId,
      related_type: 'issue',
      title: `Issued: ${txResult.bookTitle}`,
      description: `${txResult.memberName} borrowed "${txResult.bookTitle}"`,
    });

    res.json({
      id: txResult.issueId,
      book_id: book_id,
      member_id: member_id,
      issue_date: issue_date,
      due_date: due_date,
      status: 'issued',
    });
  } catch (err) {
    if (err?.status) {
      return res.status(err.status).json(err.payload || { error: err.message });
    }
    console.error('Issue create error:', err);
    res.status(500).json({ error: err.message || 'Failed to issue book' });
  }
});

// Bulk delete issues - optimized for large deletions
app.post('/api/issues/bulk-delete', async (req, res) => {
  const { ids } = req.body;
  
  if (!Array.isArray(ids) || ids.length === 0) {
    return res.status(400).json({ error: 'No issue IDs provided' });
  }
  
  const validIds = ids.filter(id => Number.isFinite(Number(id))).map(Number);
  if (validIds.length === 0) {
    return res.status(400).json({ error: 'No valid issue IDs provided' });
  }
  
  try {
    // First, get the book IDs for all issued books to restore availability
    const placeholders = validIds.map(() => '?').join(',');
    const issuesQuery = `SELECT id, book_id, status FROM issues WHERE id IN (${placeholders})`;
    const issues = await dbQuery(issuesQuery, validIds);
    
    // Count how many issued copies per book need availability restored
    const bookCountMap = {};
    issues.filter(i => i.status === 'issued' || i.status === 'overdue').forEach(i => {
      bookCountMap[i.book_id] = (bookCountMap[i.book_id] || 0) + 1;
    });
    
    // Delete the issues
    const deleteQuery = `DELETE FROM issues WHERE id IN (${placeholders})`;
    const result = await dbQuery(deleteQuery, validIds);
    const deletedCount = result.affectedRows || 0;
    
    // Restore book availability for issued books (per-book count)
    const bookIds = Object.keys(bookCountMap);
    for (const bookId of bookIds) {
      const count = bookCountMap[bookId];
      await dbQuery(
        'UPDATE books SET available_copies = LEAST(available_copies + ?, total_copies), status = CASE WHEN available_copies + ? >= total_copies THEN "available" ELSE status END WHERE id = ?',
        [count, count, bookId]
      );
    }
    
    res.json({ 
      message: `Deleted ${deletedCount} issue(s)`,
      deleted: deletedCount,
      requested: validIds.length,
      booksRestored: bookIds.length
    });
  } catch (err) {
    console.error('Bulk delete issues error:', err);
    res.status(500).json({ error: err.message || 'Bulk delete failed' });
  }
});

app.put('/api/issues/:id/return', async (req, res) => {
  const now = new Date();
  const return_date = now.toISOString().split('T')[0];

  try {
    const txResult = await withTransaction(async (connection) => {
      const issueResults = await dbQueryWithConnection(
        connection,
        'SELECT id, book_id, member_id, status FROM issues WHERE id = ? FOR UPDATE',
        [req.params.id]
      );

      if (!issueResults || issueResults.length === 0) {
        throw createHttpError(404, { error: 'Issue not found' });
      }

      const issue = issueResults[0];
      if (issue.status === 'returned') {
        throw createHttpError(400, { error: 'Book is already returned' });
      }

      const bookResults = await dbQueryWithConnection(
        connection,
        'SELECT id, title, total_copies, available_copies FROM books WHERE id = ? FOR UPDATE',
        [issue.book_id]
      );

      if (!bookResults || bookResults.length === 0) {
        throw createHttpError(404, { error: 'Book not found for this issue' });
      }

      const book = bookResults[0];
      const updateWithReturnedAt =
        'UPDATE issues SET return_date = ?, status = "returned", returned_at = NOW() WHERE id = ?';
      const updateLegacy =
        'UPDATE issues SET return_date = ?, status = "returned" WHERE id = ?';
      const updateValues = [return_date, req.params.id];

      try {
        await dbQueryWithConnection(connection, updateWithReturnedAt, updateValues);
      } catch (err) {
        if (!/Unknown column/i.test(err.message || '')) {
          throw err;
        }
        await dbQueryWithConnection(connection, updateLegacy, updateValues);
      }

      const rawAvailable = Number(book.available_copies);
      const currentAvailable = Number.isFinite(rawAvailable) && rawAvailable >= 0 ? rawAvailable : 0;
      const totalCopiesRaw = Number(book.total_copies);
      const totalCopies = Number.isFinite(totalCopiesRaw) && totalCopiesRaw > 0 ? totalCopiesRaw : 1;
      const newAvailable = Math.min(currentAvailable + 1, totalCopies);
      const newStatus = newAvailable >= totalCopies ? 'available' : 'issued';

      await dbQueryWithConnection(
        connection,
        'UPDATE books SET available_copies = ?, status = ? WHERE id = ?',
        [newAvailable, newStatus, issue.book_id]
      );

      const memberRows = await dbQueryWithConnection(
        connection,
        'SELECT name FROM members WHERE id = ? LIMIT 1',
        [issue.member_id]
      );

      return {
        issueId: Number(req.params.id),
        bookTitle: book?.title ?? '',
        memberName: memberRows?.[0]?.name ?? 'Someone',
      };
    });

    // Activity logging is best-effort and should not block successful return.
    logActivityEvent({
      type: 'return',
      related_id: txResult.issueId,
      related_type: 'issue',
      title: `Returned: ${txResult.bookTitle}`,
      description: `${txResult.memberName} returned "${txResult.bookTitle}"`,
    });

    res.json({ message: 'Book returned successfully' });
  } catch (err) {
    if (err?.status) {
      return res.status(err.status).json(err.payload || { error: err.message });
    }
    console.error('Issue return error:', err);
    res.status(500).json({ error: err.message || 'Failed to return book' });
  }
});

// Log a reminder action for an issue (creates a notification entry)
app.post('/api/issues/:id/remind', (req, res) => {
  const issueId = req.params.id;

  db.query(
    `
      SELECT i.id, i.due_date, i.status, b.title, m.name AS member_name
      FROM issues i
      JOIN books b ON i.book_id = b.id
      JOIN members m ON i.member_id = m.id
      WHERE i.id = ?
      LIMIT 1
    `,
    [issueId],
    (err, results) => {
      if (err) return res.status(500).json({ error: err.message });
      if (!results || results.length === 0) return res.status(404).json({ error: 'Issue not found' });

      const row = results[0];
      const title = `Reminder sent: ${row.title}`;
      const message = `Reminder sent to ${row.member_name} for "${row.title}" (due ${row.due_date}).`;

      db.query(
        `
          INSERT INTO notifications (user_id, title, message, type, related_id, related_type)
          SELECT id, ?, ?, 'system', ?, 'issue' FROM users WHERE role = 'admin' LIMIT 1
        `,
        [title, message, issueId],
        () => {
          res.json({ message: 'Reminder logged' });
        }
      );
    }
  );
});

app.put('/api/issues/:id', async (req, res) => {
  const { due_date, return_date, status } = req.body;
  const issueId = Number(req.params.id);
  if (!Number.isInteger(issueId) || issueId <= 0) {
    return res.status(400).json({ error: 'Invalid issue id' });
  }

  // Reject obviously-bad input before opening a transaction.
  const datePattern = /^\d{4}-\d{2}-\d{2}$/;
  if (due_date !== undefined && due_date !== null && !datePattern.test(String(due_date))) {
    return res.status(400).json({ error: 'due_date must be YYYY-MM-DD' });
  }
  if (return_date !== undefined && return_date !== null && !datePattern.test(String(return_date))) {
    return res.status(400).json({ error: 'return_date must be YYYY-MM-DD' });
  }
  if (status !== undefined && !['issued', 'overdue', 'returned', 'lost'].includes(status)) {
    return res.status(400).json({ error: "status must be one of issued|overdue|returned|lost" });
  }

  if (due_date === undefined && return_date === undefined && status === undefined) {
    return res.status(400).json({ error: 'No fields to update' });
  }

  try {
    const { issue, bookAvailabilityUpdated } = await withTransaction(async (connection) => {
      // Lock the issue row first.
      const issueResults = await dbQueryWithConnection(
        connection,
        'SELECT id, book_id, member_id, status, due_date, return_date, returned_at FROM issues WHERE id = ? FOR UPDATE',
        [issueId]
      );
      if (!issueResults || issueResults.length === 0) {
        throw createHttpError(404, { error: 'Issue not found' });
      }
      const issue = issueResults[0];

      const changeNotes = [];
      if (due_date !== undefined && String(due_date) !== String(issue.due_date ?? '')) {
        changeNotes.push(`Due date set to ${due_date}`);
      }
      if (return_date !== undefined && String(return_date) !== String(issue.return_date ?? '')) {
        changeNotes.push(`Return date set to ${return_date}`);
      }
      if (status !== undefined && String(status) !== String(issue.status ?? '')) {
        changeNotes.push(`Status changed to ${status}`);
      }

      const updateFields = [];
      const updateValues = [];
      let wantsReturnedAt = false;

      if (due_date !== undefined) {
        updateFields.push('due_date = ?');
        updateValues.push(due_date);
      }

      if (return_date !== undefined) {
        updateFields.push('return_date = ?');
        updateValues.push(return_date);
        wantsReturnedAt = true;
      }

      if (status !== undefined) {
        updateFields.push('status = ?');
        updateValues.push(status);

        if (status === 'returned' && issue.status !== 'returned') {
          wantsReturnedAt = true;
          if (return_date === undefined) {
            updateFields.push('return_date = ?');
            updateValues.push(new Date().toISOString().split('T')[0]);
          }
        }
      }

      if (wantsReturnedAt) {
        // Schema may not have this column; the fallback below strips it on failure.
        updateFields.push('returned_at = COALESCE(returned_at, NOW())');
      }

      updateValues.push(issueId);
      const updateQuery = `UPDATE issues SET ${updateFields.join(', ')} WHERE id = ?`;

      let bookAvailabilityUpdated = false;
      try {
        await dbQueryWithConnection(connection, updateQuery, updateValues);
      } catch (err) {
        if (wantsReturnedAt && /Unknown column 'returned_at'/i.test(err.message || '')) {
          const legacyFields = updateFields.filter((f) => !/returned_at/i.test(f));
          const legacyQuery = `UPDATE issues SET ${legacyFields.join(', ')} WHERE id = ?`;
          await dbQueryWithConnection(connection, legacyQuery, updateValues);
        } else {
          throw err;
        }
      }

      // Reverse book availability inside the same transaction, with a row
      // lock so concurrent returns don't double-credit the same copy.
      if (status === 'returned' && issue.status !== 'returned' && issue.book_id) {
        const bookResults = await dbQueryWithConnection(
          connection,
          'SELECT id, total_copies, available_copies FROM books WHERE id = ? FOR UPDATE',
          [issue.book_id]
        );
        if (bookResults && bookResults.length > 0) {
          const book = bookResults[0];
          const currentAvailable = Number.isFinite(Number(book.available_copies))
            ? Number(book.available_copies)
            : 0;
          const totalCopies = Number.isFinite(Number(book.total_copies)) && Number(book.total_copies) > 0
            ? Number(book.total_copies)
            : 1;
          const newAvailable = Math.min(currentAvailable + 1, totalCopies);
          const newStatus = newAvailable >= totalCopies ? 'available' : 'issued';
          await dbQueryWithConnection(
            connection,
            'UPDATE books SET available_copies = ?, status = ? WHERE id = ?',
            [newAvailable, newStatus, issue.book_id]
          );
          bookAvailabilityUpdated = true;
        }
      }

      // Fetch display fields for the activity log; not strictly required
      // for the response, but useful for log context.
      const displayResults = await dbQueryWithConnection(
        connection,
        'SELECT b.title AS book_title, m.name AS member_name FROM issues i LEFT JOIN books b ON i.book_id = b.id LEFT JOIN members m ON i.member_id = m.id WHERE i.id = ?',
        [issueId]
      );
      const display = displayResults?.[0] || {};
      const enrichedIssue = { ...issue, book_title: display.book_title, member_name: display.member_name };

      return { issue: enrichedIssue, bookAvailabilityUpdated, changeNotes };
    });

    // Activity logging is best-effort and outside the transaction.
    const bookTitle = issue.book_title || `Issue #${issue.id}`;
    const memberName = issue.member_name || '';
    const summary = issue.changeNotes && issue.changeNotes.length > 0
      ? issue.changeNotes.join('; ')
      : 'Issue updated';
    const description = memberName ? `${memberName}: ${summary}` : summary;
    logActivityEvent({
      type: 'issue_updated',
      related_id: issue.id,
      related_type: 'issue',
      title: `Issue updated: ${bookTitle}`,
      description,
    });

    res.json({ message: 'Issue updated successfully', book_availability_updated: bookAvailabilityUpdated });
  } catch (err) {
    if (err?.status) {
      return res.status(err.status).json(err.payload || { error: err.message });
    }
    console.error('Issue update error:', err);
    res.status(500).json({ error: err.message || 'Failed to update issue' });
  }
});

// DELETE single issue by ID
app.delete('/api/issues/:id', (req, res) => {
  const issueId = req.params.id;

  // First get the issue to know the book_id
  db.query('SELECT book_id FROM issues WHERE id = ?', [issueId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0) return res.status(404).json({ error: 'Issue not found' });

    const bookId = results[0].book_id;

    // Delete the issue
    db.query('DELETE FROM issues WHERE id = ?', [issueId], (err, result) => {
      if (err) return res.status(500).json({ error: err.message });
      if (result.affectedRows === 0) return res.status(404).json({ error: 'Issue not found' });

      // Restore book availability
      if (bookId) {
        db.query(
          'UPDATE books SET available_copies = COALESCE(available_copies, 0) + 1, status = CASE WHEN available_copies + 1 >= total_copies THEN "available" ELSE "issued" END WHERE id = ?',
          [bookId],
          () => {} // Fire and forget
        );
      }

      res.json({ message: 'Issue deleted successfully' });
    });
  });
});

// ==================== DASHBOARD & STATS ROUTES ====================

app.get('/api/dashboard/stats', async (req, res) => {
  await refreshOverdueStatuses();
  const stats = {};
  
  db.query('SELECT COUNT(*) as total_books, SUM(COALESCE(total_copies, 1)) as total_copies FROM books', (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    stats.total_books = Number(results[0].total_books) || 0;
    stats.total_copies = Number(results[0].total_copies) || stats.total_books;
    
    db.query("SELECT COUNT(*) as issued_books FROM issues WHERE status IN ('issued', 'overdue')", (err, results) => {
      if (err) return res.status(500).json({ error: err.message });
      stats.issued_books = Number(results[0].issued_books) || 0;

      // Keep counts consistent at the copy-level:
      // issued_books = active issues (issued + overdue)
      // available_books = total_copies - issued_books (never negative)
      stats.available_books = Math.max((stats.total_copies || 0) - (stats.issued_books || 0), 0);

      db.query("SELECT COUNT(*) as overdue_books FROM issues WHERE status = 'overdue'", (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        stats.overdue_books = Number(results[0].overdue_books) || 0;
        
        db.query('SELECT COUNT(*) as active_members FROM members WHERE is_active = TRUE OR is_active IS NULL', (err, results) => {
          if (err) return res.status(500).json({ error: err.message });
          stats.active_members = Number(results[0].active_members) || 0;
          
          db.query('SELECT COUNT(*) as total_members FROM members', (err, results) => {
            if (err) return res.status(500).json({ error: err.message });
            stats.total_members = Number(results[0].total_members) || 0;
            res.json(stats);
          });
        });
      });
    });
  });
});

// Dashboard actionable alerts + operational KPIs
app.get('/api/dashboard/alerts', async (req, res) => {
  await refreshOverdueStatuses();

  // Keep notifications in sync even if user stays on Dashboard.
  try {
    await generateNotifications();
  } catch (_) {
    // Ignore notification errors
  }

  const overdueDays = parseNonNegativeInt(req.query.overdue_days, 7);
  const lowStockThreshold = parseNonNegativeInt(req.query.low_stock_threshold, 1);
  const limit = parsePositiveInt(req.query.limit, 10);
  const lowStockLimit = Math.min(parsePositiveInt(req.query.low_stock_limit, limit), 500);
  const lowStockPage = parsePositiveInt(req.query.low_stock_page, 1);
  const lowStockOffset = (lowStockPage - 1) * lowStockLimit;

  const response = {
    overdue: { count: 0, items: [] },
    dueToday: { count: 0, items: [] },
    dueTomorrow: { count: 0, items: [] },
    lowStock: {
      count: 0,
      items: [],
      pagination: {
        page: lowStockPage,
        limit: lowStockLimit,
        total: 0,
        totalPages: 1,
        hasMore: false,
      },
    },
    dailySummary: { count: 0, issued_today: 0, returned_today: 0, items: [] },
    mostActiveMembers: { count: 0, items: [] },
    mostIssuedBooks: { count: 0, items: [] },
    kpis: {
      utilization_rate: 0,
      availability_rate: 0,
      avg_checkout_duration_days: 0,
    },
  };

  // Each call runs its two queries (count + items) in parallel using the
  // promise wrapper. Failures are swallowed (count=0 / items=[]) so a
  // single bad query doesn't 500 the whole dashboard.
  const withCountsAndItems = async (countSql, countParams, itemsSql, itemsParams, assign) => {
    const [countRes, itemsRes] = await Promise.all([
      db.promise().query(countSql, countParams).catch(() => [[{ count: 0 }]]),
      db.promise().query(itemsSql, itemsParams).catch(() => [[]]),
    ]);
    const countRows = Array.isArray(countRes) ? countRes[0] : countRes;
    const itemRows = Array.isArray(itemsRes) ? itemsRes[0] : itemsRes;
    assign(Number(countRows?.[0]?.count || 0), itemRows || []);
  };

  try {
    // Run all 7 count+items pairs in parallel. Each pair is internally
    // parallelised (count + items run together), and the pairs run concurrently
    // with each other. Latency is now max(per-pair) instead of sum-of-pairs.
    await Promise.all([
      withCountsAndItems(
      `
        SELECT COUNT(*) AS count
        FROM issues i
        WHERE i.status = 'overdue'
          AND DATEDIFF(CURDATE(), i.due_date) > ?
      `,
      [overdueDays],
      `
        SELECT i.id, i.book_id, i.member_id, i.issue_date, i.due_date, i.return_date, i.status,
               DATEDIFF(CURDATE(), i.due_date) AS days_overdue,
               b.title, b.author, b.cover_image,
               m.name AS member_name, m.email, m.phone, m.profile_photo
        FROM issues i
        JOIN books b ON i.book_id = b.id
        JOIN members m ON i.member_id = m.id
        WHERE i.status = 'overdue'
          AND DATEDIFF(CURDATE(), i.due_date) > ?
        ORDER BY days_overdue DESC
        LIMIT ?
      `,
      [overdueDays, limit],
      (count, items) => {
        response.overdue = { count, items };
      }
    ),

      withCountsAndItems(
      `
        SELECT COUNT(*) AS count
        FROM issues i
        WHERE i.status IN ('issued', 'overdue')
          AND i.due_date = CURDATE()
      `,
      [],
      `
        SELECT i.id, i.book_id, i.member_id, i.issue_date, i.due_date, i.return_date, i.status,
               DATEDIFF(CURDATE(), i.due_date) AS days_overdue,
               b.title, b.author, b.cover_image,
               m.name AS member_name, m.email, m.phone, m.profile_photo
        FROM issues i
        JOIN books b ON i.book_id = b.id
        JOIN members m ON i.member_id = m.id
        WHERE i.status IN ('issued', 'overdue')
          AND i.due_date = CURDATE()
        ORDER BY i.status DESC, i.issue_date DESC
        LIMIT ?
      `,
      [limit],
      (count, items) => {
        response.dueToday = { count, items };
      }
    ),

      withCountsAndItems(
      `
        SELECT COUNT(*) AS count
        FROM issues i
        WHERE i.status = 'issued'
          AND i.due_date = DATE_ADD(CURDATE(), INTERVAL 1 DAY)
      `,
      [],
      `
        SELECT i.id, i.book_id, i.member_id, i.issue_date, i.due_date, i.return_date, i.status,
               0 AS days_overdue,
               b.title, b.author, b.cover_image,
               m.name AS member_name, m.email, m.phone, m.profile_photo
        FROM issues i
        JOIN books b ON i.book_id = b.id
        JOIN members m ON i.member_id = m.id
        WHERE i.status = 'issued'
          AND i.due_date = DATE_ADD(CURDATE(), INTERVAL 1 DAY)
        ORDER BY i.issue_date DESC
        LIMIT ?
      `,
      [limit],
      (count, items) => {
        response.dueTomorrow = { count, items };
      }
    ),

      withCountsAndItems(
      `
        SELECT COUNT(*) AS count
        FROM books b
        WHERE COALESCE(b.available_copies, CASE WHEN b.status = 'available' THEN 1 ELSE 0 END) <= ?
      `,
      [lowStockThreshold],
      `
        SELECT b.id, b.isbn, b.title, b.author, b.category, b.publisher, b.year_published,
               b.cover_image, b.total_copies, b.available_copies, b.status
        FROM books b
        WHERE COALESCE(b.available_copies, CASE WHEN b.status = 'available' THEN 1 ELSE 0 END) <= ?
        ORDER BY COALESCE(b.available_copies, 0) ASC, b.title ASC
        LIMIT ? OFFSET ?
      `,
      [lowStockThreshold, lowStockLimit, lowStockOffset],
      (count, items) => {
        const totalPages = count > 0 ? Math.ceil(count / lowStockLimit) : 1;
        response.lowStock = {
          count,
          items,
          pagination: {
            page: lowStockPage,
            limit: lowStockLimit,
            total: count,
            totalPages,
            hasMore: lowStockPage < totalPages,
          },
        };
      }
    ),

    // Daily Issue-Return Summary
      withCountsAndItems(
      `
        SELECT COUNT(*) AS count
        FROM issues
        WHERE DATE(COALESCE(issued_at, issue_date)) = CURDATE()
      `,
      [],
      `
        SELECT i.id, i.book_id, i.member_id, i.issue_date, i.due_date, i.status,
               b.title, b.author,
               m.name AS member_name
        FROM issues i
        JOIN books b ON i.book_id = b.id
        JOIN members m ON i.member_id = m.id
        WHERE DATE(COALESCE(i.issued_at, i.issue_date)) = CURDATE()
        ORDER BY i.issue_date DESC
        LIMIT ?
      `,
      [limit],
      (count, items) => {
        // Calculate issued and returned today
        const issuedToday = items.filter(i => i.status === 'issued' || i.status === 'overdue').length;
        const returnedToday = items.filter(i => i.status === 'returned').length;
        response.dailySummary = { count, issued_today: issuedToday, returned_today: returnedToday, items };
      }
    ),

    // Most Active Members (top borrowers this month)
      withCountsAndItems(
      `
        SELECT COUNT(*) AS count FROM (
          SELECT member_id FROM issues
          WHERE issue_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
          GROUP BY member_id
        ) AS active_members
      `,
      [],
      `
        SELECT m.id, m.name, m.email, m.member_type, m.profile_photo,
               COUNT(i.id) AS borrow_count,
               (SELECT COUNT(*) FROM issues WHERE member_id = m.id AND status IN ('issued', 'overdue')) AS active_issues
        FROM members m
        JOIN issues i ON m.id = i.member_id
        WHERE i.issue_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        GROUP BY m.id
        ORDER BY borrow_count DESC
        LIMIT ?
      `,
      [limit],
      (count, items) => {
        response.mostActiveMembers = { count, items };
      }
    ),

    // Most Issued Books (top borrowed books this month)
      withCountsAndItems(
      `
        SELECT COUNT(*) AS count FROM (
          SELECT book_id FROM issues
          WHERE issue_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
          GROUP BY book_id
        ) AS active_books
      `,
      [],
      `
        SELECT b.id, b.title, b.author, b.category, b.cover_image, b.available_copies,
               COUNT(i.id) AS borrow_count,
               (SELECT COUNT(*) FROM issues WHERE book_id = b.id AND status IN ('issued', 'overdue')) AS active_copies
        FROM books b
        JOIN issues i ON b.id = i.book_id
        WHERE i.issue_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        GROUP BY b.id
        ORDER BY borrow_count DESC
        LIMIT ?
      `,
      [limit],
      (count, items) => {
        response.mostIssuedBooks = { count, items };
      }
    ),
    ]);

    // KPIs
    db.query('SELECT SUM(COALESCE(total_copies, 1)) AS total_copies FROM books', (err, rows) => {
      const totalCopies = err ? 0 : Number(rows?.[0]?.total_copies || 0);
      db.query("SELECT COUNT(*) AS issued_copies FROM issues WHERE status IN ('issued', 'overdue')", (err2, rows2) => {
        const issuedCopies = err2 ? 0 : Number(rows2?.[0]?.issued_copies || 0);
        const safeTotal = Math.max(totalCopies, 0);
        response.kpis.utilization_rate = safeTotal > 0 ? Number((issuedCopies / safeTotal).toFixed(4)) : 0;
        response.kpis.availability_rate = safeTotal > 0 ? Number((((safeTotal - issuedCopies) / safeTotal)).toFixed(4)) : 0;

        db.query('SELECT AVG(DATEDIFF(return_date, issue_date)) AS avg_days FROM issues WHERE return_date IS NOT NULL', (err3, rows3) => {
          const avg = err3 ? 0 : Number(rows3?.[0]?.avg_days || 0);
          response.kpis.avg_checkout_duration_days = Number.isFinite(avg) ? Number(avg.toFixed(2)) : 0;
          res.json(response);
        });
      });
    });
  } catch (e) {
    res.status(500).json({ error: 'Failed to compute alerts' });
  }
});

// Recent activity feed (derived from existing timestamps)
app.get('/api/dashboard/activity', (req, res) => {
  (async () => {
    try {
      const limit = parsePositiveInt(req.query.limit, 25);
      const userId = req.user?.id;

      // Detect optional timestamp columns so this endpoint stays compatible with older schemas.
      const columnExists = async (table, column) => {
        const rows = await dbQuery(
          `SELECT 1 AS ok
           FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE()
             AND TABLE_NAME = ?
             AND COLUMN_NAME = ?
           LIMIT 1`,
          [table, column]
        );
        return Array.isArray(rows) && rows.length > 0;
      };

      const [hasIssueIssuedAt, hasIssueReturnedAt, hasMemberCreatedAt, hasBookAddedDate] =
        await Promise.all([
          columnExists('issues', 'issued_at'),
          columnExists('issues', 'returned_at'),
          columnExists('members', 'created_at'),
          columnExists('books', 'added_date'),
        ]);

      const issueOccurredAt = hasIssueIssuedAt
        ? 'COALESCE(i.issued_at, CAST(i.issue_date AS DATETIME))'
        : 'CAST(i.issue_date AS DATETIME)';

      const returnOccurredAt = hasIssueReturnedAt
        ? 'COALESCE(i.returned_at, CAST(i.return_date AS DATETIME))'
        : 'CAST(i.return_date AS DATETIME)';

      const memberOccurredAt = hasMemberCreatedAt
        ? 'COALESCE(m.created_at, CAST(m.membership_date AS DATETIME))'
        : 'CAST(m.membership_date AS DATETIME)';

      const bookOccurredAt = hasBookAddedDate
        ? 'CAST(b.added_date AS DATETIME)'
        : 'CAST(NULL AS DATETIME)';

      // Optional per-user cutoff ("Clear" button on UI hides anything before this timestamp).
      let hiddenBefore = null;
      if (userId) {
        const rows = await dbQuery(
          'SELECT settings FROM dashboard_settings WHERE user_id = ? AND widget_name = ? ORDER BY id DESC LIMIT 1',
          [userId, 'recent_activity_cutoff']
        );
        let raw = Array.isArray(rows) && rows.length > 0 ? rows[0]?.settings : null;
        if (raw) {
          try {
            // mysql2 may return JSON columns as objects, strings, or Buffers depending on config.
            if (Buffer.isBuffer(raw)) {
              raw = raw.toString('utf8');
            }
            const obj = typeof raw === 'string' ? JSON.parse(raw) : raw;
            if (obj && obj.hidden_before) hiddenBefore = obj.hidden_before;
          } catch (_) {
            // ignore
          }
        }
      }

      // If the dedicated activity table exists, use it (this supports true realtime ordering).
      let hasActivityEvents = false;
      try {
        const tRows = await dbQuery(
          `SELECT 1 AS ok
           FROM INFORMATION_SCHEMA.TABLES
           WHERE TABLE_SCHEMA = DATABASE()
             AND TABLE_NAME = 'activity_events'
           LIMIT 1`
        );
        hasActivityEvents = Array.isArray(tRows) && tRows.length > 0;
      } catch (_) {
        hasActivityEvents = false;
      }

      // Skip activity_events table for now - use UNION query to generate fresh data
      // from source tables (books, members, issues) to avoid corrupted legacy data.
      // TODO: Re-enable once activity_events table has clean data.
      hasActivityEvents = false;

      if (hasActivityEvents) {
        const whereCutoff = hiddenBefore ? 'WHERE occurred_at >= ?' : '';
        const params = [];
        if (hiddenBefore) params.push(hiddenBefore);
        params.push(limit);

        const sql = `
          SELECT type, related_id, related_type, occurred_at, title, description
          FROM activity_events
          ${whereCutoff}
          ORDER BY occurred_at DESC
          LIMIT ?
        `;

        const rows = await dbQuery(sql, params);
        return res.json(rows);
      }

      // Build the UNION first, then apply the cutoff in an outer WHERE on a unified DATETIME.
      // This makes "Clear" reliable even when source columns are DATE-only.
      // Each UNION branch is pre-LIMITed so MySQL doesn't try to materialize
      // the entire books/members/issues tables for the UNION before sorting
      // and slicing.
      const PER_BRANCH_LIMIT = Math.max(limit * 4, 100);
      const whereCutoff = hiddenBefore ? 'WHERE a.occurred_at >= ?' : '';
      const params = [];
      if (hiddenBefore) params.push(hiddenBefore);
      params.push(limit);

      const sql = `
        SELECT a.*
        FROM (
          (
            SELECT
              CAST('issue' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS type,
              i.id AS related_id,
              CAST('issue' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS related_type,
              ${issueOccurredAt} AS occurred_at,
              (CONCAT('Issued: ', CONVERT(b.title USING utf8mb4)) COLLATE utf8mb4_unicode_ci) AS title,
              (CONCAT(CONVERT(m.name USING utf8mb4), ' borrowed "', CONVERT(b.title USING utf8mb4), '"') COLLATE utf8mb4_unicode_ci) AS description
            FROM issues i
            JOIN books b ON i.book_id = b.id
            JOIN members m ON i.member_id = m.id
            ORDER BY i.issue_date DESC
            LIMIT ${PER_BRANCH_LIMIT}
          )
          UNION ALL
          (
            SELECT
              CAST('return' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS type,
              i.id AS related_id,
              CAST('issue' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS related_type,
              ${returnOccurredAt} AS occurred_at,
              (CONCAT('Returned: ', CONVERT(b.title USING utf8mb4)) COLLATE utf8mb4_unicode_ci) AS title,
              (CONCAT(CONVERT(m.name USING utf8mb4), ' returned "', CONVERT(b.title USING utf8mb4), '"') COLLATE utf8mb4_unicode_ci) AS description
            FROM issues i
            JOIN books b ON i.book_id = b.id
            JOIN members m ON i.member_id = m.id
            WHERE i.return_date IS NOT NULL
            ORDER BY i.return_date DESC
            LIMIT ${PER_BRANCH_LIMIT}
          )
          UNION ALL
          (
            SELECT
              CAST('book_added' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS type,
              b.id AS related_id,
              CAST('book' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS related_type,
              ${bookOccurredAt} AS occurred_at,
              (CONCAT('New book: ', CONVERT(b.title USING utf8mb4)) COLLATE utf8mb4_unicode_ci) AS title,
              (CONCAT('"', CONVERT(b.title USING utf8mb4), '" by ', CONVERT(b.author USING utf8mb4)) COLLATE utf8mb4_unicode_ci) AS description
            FROM books b
            ORDER BY b.id DESC
            LIMIT ${PER_BRANCH_LIMIT}
          )
          UNION ALL
          (
            SELECT
              CAST('member_added' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS type,
              m.id AS related_id,
              CAST('member' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS related_type,
              ${memberOccurredAt} AS occurred_at,
              (CONCAT('New member: ', CONVERT(m.name USING utf8mb4)) COLLATE utf8mb4_unicode_ci) AS title,
              (CONCAT(CONVERT(m.name USING utf8mb4), ' registered') COLLATE utf8mb4_unicode_ci) AS description
            FROM members m
            ORDER BY m.id DESC
            LIMIT ${PER_BRANCH_LIMIT}
          )
        ) a
        ${whereCutoff}
        ORDER BY a.occurred_at DESC
        LIMIT ?
      `;

      const rows = await dbQuery(sql, params);
      res.json(rows);
    } catch (err) {
      res.status(500).json({ error: err?.message || String(err) });
    }
  })();
});

// Clear (hide) recent activity for current user by storing a cutoff timestamp.
app.post('/api/dashboard/activity/clear', async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ error: 'Access denied' });

    const now = new Date();
    // Use LOCAL time to match MySQL session time (DATETIME has no timezone).
    const pad2 = (n) => String(n).padStart(2, '0');
    const cutoff = `${now.getFullYear()}-${pad2(now.getMonth() + 1)}-${pad2(now.getDate())} ${pad2(now.getHours())}:${pad2(now.getMinutes())}:${pad2(now.getSeconds())}`;
    const settings = JSON.stringify({ hidden_before: cutoff });

    await dbQuery(
      'DELETE FROM dashboard_settings WHERE user_id = ? AND widget_name = ?',
      [userId, 'recent_activity_cutoff']
    );
    await dbQuery(
      'INSERT INTO dashboard_settings (user_id, widget_name, is_visible, position, settings) VALUES (?, ?, ?, ?, ?)',
      [userId, 'recent_activity_cutoff', true, 0, settings]
    );

    res.json({ message: 'Activity cleared', hidden_before: cutoff });
  } catch (err) {
    res.status(500).json({ error: err?.message || String(err) });
  }
});

// ==================== REPORTS ROUTES ====================

app.get('/api/reports/issued', (req, res) => {
  // Cap at 1000 by default. Clients should request a smaller page for exports.
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 1000, 1), 5000);
  const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);
  db.query(`
    SELECT i.issue_date, i.due_date, i.status,
           b.title, b.author, b.isbn, b.cover_image,
           m.name as member_name, m.profile_photo
    FROM issues i
    JOIN books b ON i.book_id = b.id
    JOIN members m ON i.member_id = m.id
    WHERE i.return_date IS NULL
    ORDER BY i.issue_date DESC
    LIMIT ? OFFSET ?
  `, [limit, offset], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ data: results, pagination: { limit, offset, hasMore: results.length === limit } });
  });
});

app.get('/api/reports/overdue', async (req, res) => {
  await refreshOverdueStatuses();
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 1000, 1), 5000);
  const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);
  db.query(`
    SELECT i.due_date, i.issue_date, DATEDIFF(CURDATE(), i.due_date) as days_overdue,
           b.title, b.author, b.isbn, b.cover_image, 
           m.name as member_name, m.email, m.phone, m.profile_photo
    FROM issues i
    JOIN books b ON i.book_id = b.id
    JOIN members m ON i.member_id = m.id
    WHERE i.status = 'overdue'
    ORDER BY days_overdue DESC
    LIMIT ? OFFSET ?
  `, [limit, offset], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ data: results, pagination: { limit, offset, hasMore: results.length === limit } });
  });
});

// Popular books report
app.get('/api/reports/popular-books', (req, res) => {
  const { limit = 10, period } = req.query;
  let dateFilter = '';
  
  if (period === 'month') {
    dateFilter = 'AND i.issue_date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)';
  } else if (period === 'year') {
    dateFilter = 'AND i.issue_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)';
  }
  
  db.query(`
    SELECT b.id, b.title, b.author, b.category, b.cover_image, COUNT(i.id) as borrow_count
    FROM books b
    LEFT JOIN issues i ON b.id = i.book_id ${dateFilter}
    GROUP BY b.id
    ORDER BY borrow_count DESC
    LIMIT ?
  `, [parseInt(limit)], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// Active members report
app.get('/api/reports/active-members', (req, res) => {
  const { limit = 10, period } = req.query;
  let dateFilter = '';
  
  if (period === 'month') {
    dateFilter = 'AND i.issue_date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)';
  } else if (period === 'year') {
    dateFilter = 'AND i.issue_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)';
  }
  
  db.query(`
    SELECT m.id, m.name, m.email, m.member_type, m.profile_photo, COUNT(i.id) as borrow_count
    FROM members m
    LEFT JOIN issues i ON m.id = i.member_id ${dateFilter}
    GROUP BY m.id
    ORDER BY borrow_count DESC
    LIMIT ?
  `, [parseInt(limit)], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// Monthly statistics
app.get('/api/reports/monthly-stats', (req, res) => {
  const { year = new Date().getFullYear() } = req.query;
  
  db.query(`
    SELECT 
      MONTH(issue_date) as month,
      COUNT(*) as issues,
      SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) as returns,
      SUM(CASE WHEN status = 'overdue' THEN 1 ELSE 0 END) as overdue
    FROM issues
    WHERE YEAR(issue_date) = ?
    GROUP BY MONTH(issue_date)
    ORDER BY month
  `, [year], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    
    // Fill in missing months with zeros
    const monthlyData = Array.from({ length: 12 }, (_, i) => ({
      month: i + 1,
      issues: 0,
      returns: 0,
      overdue: 0
    }));
    
    results.forEach(row => {
      monthlyData[row.month - 1] = row;
    });
    
    res.json(monthlyData);
  });
});

// Category statistics
app.get('/api/reports/category-stats', (req, res) => {
  db.query(`
    SELECT 
      COALESCE(b.category, 'Uncategorized') as category,
      COUNT(DISTINCT b.id) as book_count,
      COUNT(i.id) as borrow_count
    FROM books b
    LEFT JOIN issues i ON b.id = i.book_id
    GROUP BY b.category
    ORDER BY borrow_count DESC
  `, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// Yearly comparison
app.get('/api/reports/yearly-stats', (req, res) => {
  db.query(`
    SELECT 
      YEAR(issue_date) as year,
      COUNT(*) as total_issues,
      SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) as total_returns,
      COUNT(DISTINCT member_id) as unique_borrowers,
      COUNT(DISTINCT book_id) as unique_books
    FROM issues
    GROUP BY YEAR(issue_date)
    ORDER BY year DESC
    LIMIT 5
  `, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// ==================== NOTIFICATIONS ROUTES ====================

app.get('/api/notifications', async (req, res) => {
  try {
    await generateNotifications();
  } catch (e) {
    // Ignore
  }
  const { unread_only } = req.query;
  // Clamp to a sane upper bound so a malicious client can't request limit=1e9
  // and force the server to materialise the entire notifications table.
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 50, 1), 200);
  
  let query = 'SELECT * FROM notifications WHERE 1=1';
  const params = [];
  
  if (unread_only === 'true') {
    query += ' AND is_read = FALSE';
  }
  
  query += ' ORDER BY created_at DESC LIMIT ?';
  params.push(parseInt(limit));
  
  db.query(query, params, (err, results) => {
    if (err) return res.json([]);
    res.json(results);
  });
});

app.get('/api/notifications/count', async (req, res) => {
  try {
    await generateNotifications();
  } catch (e) {
    // Ignore
  }
  db.query('SELECT COUNT(*) as count FROM notifications WHERE is_read = FALSE', (err, results) => {
    if (err) return res.json({ count: 0 });
    res.json({ count: results[0].count });
  });
});

app.put('/api/notifications/:id/read', (req, res) => {
  db.query('UPDATE notifications SET is_read = TRUE WHERE id = ?', [req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Notification marked as read' });
  });
});

app.put('/api/notifications/read-all', (req, res) => {
  db.query('UPDATE notifications SET is_read = TRUE', (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'All notifications marked as read' });
  });
});

app.delete('/api/notifications/:id', (req, res) => {
  db.query('DELETE FROM notifications WHERE id = ?', [req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Notification deleted' });
  });
});

// ==================== SEARCH & RECOMMENDATIONS ====================

// Cap each branch of the cross-table search so a permissive query can't
// pull tens of thousands of rows and freeze the API.
const SEARCH_RESULT_LIMIT = 200;

// Advanced search
app.get('/api/search', (req, res) => {
  const { q, type, category, author, year_from, year_to, status, member_type } = req.query;
  const results = { books: [], members: [], issues: [] };
  
  let bookQuery = 'SELECT * FROM books WHERE 1=1';
  const bookParams = [];
  
  if (q) {
    bookQuery += ' AND (title LIKE ? OR author LIKE ? OR isbn LIKE ?)';
    const searchTerm = `%${q}%`;
    bookParams.push(searchTerm, searchTerm, searchTerm);
  }
  if (category) {
    bookQuery += ' AND category = ?';
    bookParams.push(category);
  }
  if (author) {
    bookQuery += ' AND author LIKE ?';
    bookParams.push(`%${author}%`);
  }
  if (year_from) {
    bookQuery += ' AND year_published >= ?';
    bookParams.push(year_from);
  }
  if (year_to) {
    bookQuery += ' AND year_published <= ?';
    bookParams.push(year_to);
  }
  if (status) {
    bookQuery += ' AND status = ?';
    bookParams.push(status);
  }
  bookQuery += ' ORDER BY title ASC LIMIT ?';
  bookParams.push(SEARCH_RESULT_LIMIT);

  db.query(bookQuery, bookParams, (err, bookResults) => {
    if (!err) results.books = bookResults;
    
    let memberQuery = 'SELECT * FROM members WHERE 1=1';
    const memberParams = [];
    
    if (q) {
      memberQuery += ' AND (name LIKE ? OR email LIKE ? OR phone LIKE ?)';
      const searchTerm = `%${q}%`;
      memberParams.push(searchTerm, searchTerm, searchTerm);
    }
    if (member_type) {
      memberQuery += ' AND member_type = ?';
      memberParams.push(member_type);
    }
    memberQuery += ' ORDER BY name ASC LIMIT ?';
    memberParams.push(SEARCH_RESULT_LIMIT);

    db.query(memberQuery, memberParams, (err, memberResults) => {
      if (!err) results.members = memberResults;

      let issueQuery = `
        SELECT i.*, b.title, b.author, b.cover_image, m.name as member_name, m.profile_photo as member_photo
        FROM issues i
        JOIN books b ON i.book_id = b.id
        JOIN members m ON i.member_id = m.id
        WHERE 1=1
      `;
      const issueParams = [];

      if (q) {
        issueQuery += ' AND (b.title LIKE ? OR b.author LIKE ? OR b.isbn LIKE ? OR m.name LIKE ? OR m.email LIKE ? OR m.phone LIKE ?)';
        const searchTerm = `%${q}%`;
        issueParams.push(searchTerm, searchTerm, searchTerm, searchTerm, searchTerm, searchTerm);
      }
      if (status) {
        issueQuery += ' AND i.status = ?';
        issueParams.push(status);
      }

      issueQuery += ' ORDER BY i.issue_date DESC LIMIT ?';
      issueParams.push(SEARCH_RESULT_LIMIT);

      db.query(issueQuery, issueParams, (err2, issueResults) => {
        if (!err2) results.issues = issueResults;
        res.json(results);
      });
    });
  });
});

// Book recommendations based on borrowing history
app.get('/api/recommendations/:memberId', (req, res) => {
  const memberId = req.params.memberId;
  
  // Get categories and authors the member has borrowed
  db.query(`
    SELECT DISTINCT b.category, b.author
    FROM issues i
    JOIN books b ON i.book_id = b.id
    WHERE i.member_id = ?
  `, [memberId], (err, preferences) => {
    if (err) return res.status(500).json({ error: err.message });
    
    if (preferences.length === 0) {
      // No history, return popular books
      db.query(`
        SELECT b.*, COUNT(i.id) as popularity
        FROM books b
        LEFT JOIN issues i ON b.id = i.book_id
        WHERE b.available_copies > 0 OR b.status = 'available'
        GROUP BY b.id
        ORDER BY popularity DESC
        LIMIT 10
      `, (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
      });
    } else {
      const categories = preferences.map(p => p.category).filter(Boolean);
      const authors = preferences.map(p => p.author).filter(Boolean);

      if (categories.length === 0 && authors.length === 0) {
        // No usable preferences; fall through to popular books.
        return db.query(`
          SELECT b.*, COUNT(i.id) as popularity
          FROM books b
          LEFT JOIN issues i ON b.id = i.book_id
          WHERE b.available_copies > 0 OR b.status = 'available'
          GROUP BY b.id
          ORDER BY popularity DESC
          LIMIT 10
        `, (err, results) => {
          if (err) return res.status(500).json({ error: err.message });
          res.json(results);
        });
      }

      // mysql2 expands `?` placeholders inside arrays automatically, but only
      // for one placeholder per call. Build the IN clause manually so we can
      // pass the right number of placeholders for both categories and
      // authors.
      const categoryPlaceholders = categories.map(() => '?').join(',') || "''";
      const authorPlaceholders = authors.map(() => '?').join(',') || "''";
      const query = `
        SELECT b.*
        FROM books b
        WHERE b.id NOT IN (SELECT book_id FROM issues WHERE member_id = ?)
        AND (b.available_copies > 0 OR b.status = 'available')
        AND (b.category IN (${categoryPlaceholders}) OR b.author IN (${authorPlaceholders}))
        LIMIT 10
      `;

      db.query(
        query,
        [memberId, ...categories, ...authors],
        (err, results) => {
          if (err) return res.status(500).json({ error: err.message });
          res.json(results);
        }
      );
    }
  });
});

// ==================== DASHBOARD SETTINGS ====================

app.get('/api/dashboard/settings/:userId', (req, res) => {
  const authUserId = req.user?.id;
  const targetUserId = Number(req.params.userId);
  if (!authUserId) return res.status(401).json({ error: 'Access denied' });
  if (!Number.isFinite(targetUserId) || targetUserId <= 0) {
    return res.status(400).json({ error: 'Invalid user id' });
  }
  if (targetUserId !== authUserId) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  db.query(
    'SELECT * FROM dashboard_settings WHERE user_id = ? ORDER BY position',
    [req.params.userId],
    (err, results) => {
      if (err || results.length === 0) {
        // Return defaults if no settings found
        const defaults = [
          { widget_name: 'stats_cards', is_visible: true, position: 0 },
          { widget_name: 'charts', is_visible: true, position: 1 },
          { widget_name: 'recent_issues', is_visible: true, position: 2 },
          { widget_name: 'popular_books', is_visible: true, position: 3 },
          { widget_name: 'overdue_alerts', is_visible: true, position: 4 },
          { widget_name: 'quick_actions', is_visible: true, position: 5 }
        ];
        return res.json(defaults);
      }
      
      res.json(results);
    }
  );
});

const DASHBOARD_WIDGET_WHITELIST = new Set([
  'stats_cards',
  'charts',
  'recent_issues',
  'popular_books',
  'overdue_alerts',
  'quick_actions',
  'recent_activity',
  'borrow_trends',
]);

app.put('/api/dashboard/settings/:userId', (req, res) => {
  const { widgets } = req.body;
  const userId = req.params.userId;

  const authUserId = req.user?.id;
  const targetUserId = Number(userId);
  if (!authUserId) return res.status(401).json({ error: 'Access denied' });
  if (!Number.isFinite(targetUserId) || targetUserId <= 0) {
    return res.status(400).json({ error: 'Invalid user id' });
  }
  if (targetUserId !== authUserId) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  if (widgets !== undefined && !Array.isArray(widgets)) {
    return res.status(400).json({ error: 'widgets must be an array' });
  }

  // Whitelist widget_name so a client can't insert arbitrary rows that
  // later collide with feature-specific lookups (e.g. recent_activity_cutoff).
  const safeWidgets = (widgets || []).filter((w) => w && DASHBOARD_WIDGET_WHITELIST.has(w.widget_name));

  // Delete existing layout settings, but preserve non-layout rows like activity cutoff.
  db.query(
    "DELETE FROM dashboard_settings WHERE user_id = ? AND widget_name <> 'recent_activity_cutoff'",
    [userId],
    (err) => {
      if (err) return res.status(500).json({ error: err.message });

      if (safeWidgets.length === 0) {
        return res.json({ message: 'Settings saved' });
      }

      // Bulk insert with a single round-trip. We never construct a column
      // list from the input widgets, so SQL injection isn't a concern here,
      // but the placeholder count must match the column count exactly.
      const placeholders = safeWidgets.map(() => '(?, ?, ?, ?, ?)').join(', ');
      const params = [];
      safeWidgets.forEach((w, i) => {
        params.push(userId, w.widget_name, !!w.is_visible, i, JSON.stringify(w.settings || {}));
      });
      const insertQuery = `INSERT INTO dashboard_settings (user_id, widget_name, is_visible, position, settings) VALUES ${placeholders}`;
      db.query(insertQuery, params, (err2) => {
        if (err2) return res.status(500).json({ error: err2.message });
        res.json({ message: 'Settings saved' });
      });
    }
  );
});

// ==================== BACKUP & RESTORE ====================

const BACKUP_TABLES = ['books', 'members', 'issues'];

app.get('/api/backup', async (req, res) => {
  const backup = {
    timestamp: new Date().toISOString(),
    version: '2.0',
    data: {},
    errors: {},
  };

  // Sequential await avoids firing N parallel SELECT * queries on huge
  // tables, and gives us a clean per-table error path.
  for (const table of BACKUP_TABLES) {
    try {
      backup.data[table] = await dbQuery(`SELECT * FROM \`${table}\``);
    } catch (err) {
      backup.data[table] = [];
      backup.errors[table] = err.message;
    }
  }

  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Content-Disposition', `attachment; filename=library_backup_${Date.now()}.json`);
  res.json(backup);
});

// Allowed tables and their valid columns for restore (whitelist to prevent SQL injection)
const RESTORE_SCHEMA = {
  books: ['id','isbn','title','author','rack_number','category','publisher','year_published','cover_image','total_copies','available_copies','description','status','created_at'],
  members: ['id','name','email','phone','member_type','membership_date','profile_photo','address','expiry_date','is_active','created_at'],
  issues: ['id','book_id','member_id','issue_date','due_date','return_date','status','fine_amount','returned_at','created_at'],
};

app.post('/api/restore', (req, res) => {
  const { data, clear_existing } = req.body;

  if (!data || typeof data !== 'object') {
    return res.status(400).json({ error: 'No backup data provided' });
  }

  const restoreTable = (table, rows, callback) => {
    if (!rows || !Array.isArray(rows) || rows.length === 0) return callback();

    const allowedCols = RESTORE_SCHEMA[table];
    if (!allowedCols) return callback(); // Skip unknown tables entirely

    if (clear_existing) {
      db.query(`DELETE FROM \`${table}\``, (err) => {
        if (err) console.error(`Error clearing ${table}:`, err.message);
        insertRows();
      });
    } else {
      insertRows();
    }

    function insertRows() {
      // Only use columns that exist in the whitelist
      const columns = Object.keys(rows[0]).filter((c) => allowedCols.includes(c));
      if (columns.length === 0) return callback();

      const escapedCols = columns.map((c) => `\`${c}\``).join(', ');
      const placeholders = columns.map(() => '?').join(', ');
      const query = `INSERT IGNORE INTO \`${table}\` (${escapedCols}) VALUES (${placeholders})`;

      let completed = 0;
      rows.forEach((row) => {
        const values = columns.map((col) => row[col] ?? null);
        db.query(query, values, () => {
          completed++;
          if (completed === rows.length) callback();
        });
      });
    }
  };

  // Restore in order (issues last because of FK dependencies)
  restoreTable('books', data.books, () => {
    restoreTable('members', data.members, () => {
      restoreTable('issues', data.issues, () => {
        res.json({ message: 'Backup restored successfully' });
      });
    });
  });
});

// Export data to CSV format - Optimized for large datasets with streaming
app.get('/api/export/:type', async (req, res) => {
  const { type } = req.params;
  const { format = 'json' } = req.query;

  // Hard cap on export size to protect the server from OOM on multi-million-row
  // tables. Clients that need more should page via /api/books etc.
  const EXPORT_ROW_LIMIT = 10000;
  // Allow more time than the default, but not unlimited: a stuck export
  // shouldn't pin a worker forever.
  const EXPORT_TIMEOUT_MS = 5 * 60 * 1000; // 5 min
  req.setTimeout(EXPORT_TIMEOUT_MS);
  res.setTimeout(EXPORT_TIMEOUT_MS);

  let query = '';
  let filename = '';

  switch (type) {
    case 'books':
      query = 'SELECT id, isbn, title, author, rack_number, category, publisher, year_published, total_copies, available_copies, status, added_date FROM books ORDER BY id LIMIT ' + EXPORT_ROW_LIMIT;
      filename = 'books_export';
      break;
    case 'members':
      query = 'SELECT id, name, email, phone, member_type, membership_date, is_active FROM members ORDER BY id LIMIT ' + EXPORT_ROW_LIMIT;
      filename = 'members_export';
      break;
    case 'issues':
      query = "SELECT i.id, b.title as book_title, b.isbn, m.name as member_name, i.issue_date, i.due_date, i.return_date, i.status FROM issues i JOIN books b ON i.book_id = b.id JOIN members m ON i.member_id = m.id ORDER BY i.id LIMIT " + EXPORT_ROW_LIMIT;
      filename = 'issues_export';
      break;
    default:
      return res.status(400).json({ error: 'Invalid export type' });
  }

  try {
    if (format === 'csv') {
      // CSV: stream rows directly from MySQL to the response so we never
      // hold the full result set in memory. The query already has LIMIT
      // applied; we use the same shape to discover column order.
      const [sample] = await db.promise().query(query);
      if (!sample || sample.length === 0) {
        return res.status(404).json({ error: 'No data to export' });
      }
      const columns = Object.keys(sample[0]);

      // mysql2's streaming API is callback-based, so we go through the
      // (patched) callback getConnection. applyStatementTimeout is wired
      // in by db.getConnection, so a hung export query is killed at 30s.
      const connection = await new Promise((resolve, reject) => {
        db.getConnection((err, conn) => (err ? reject(err) : resolve(conn)));
      });

      try {
        const stream = connection.query(query).stream();

        const csvEscape = (val) => {
          if (val === null || val === undefined) return '';
          const str = String(val);
          if (str.includes(',') || str.includes('"') || str.includes('\n') || str.includes('\r')) {
            return '"' + str.replace(/"/g, '""') + '"';
          }
          return str;
        };

        const now = new Date();
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        const generatedOn = String(now.getDate()).padStart(2, '0') + '-' + months[now.getMonth()] + '-' + now.getFullYear()
          + ' ' + String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0') + ':' + String(now.getSeconds()).padStart(2, '0') + ' IST';

        res.setHeader('Content-Type', 'text/csv; charset=utf-8');
        res.setHeader('Content-Disposition', 'attachment; filename=' + filename + '_' + Date.now() + '.csv');

        res.write('\ufeff');
        res.write('# Generated on: ' + generatedOn + '\n');
        res.write(columns.join(',') + '\n');

        for await (const row of stream) {
          res.write(columns.map((h) => csvEscape(row[h])).join(',') + '\n');
        }
        res.end();
      } finally {
        connection.release();
      }
    } else {
      // JSON export: still load into memory, but cap at EXPORT_ROW_LIMIT.
      const [results] = await db.promise().query(query);
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Content-Disposition', 'attachment; filename=' + filename + '_' + Date.now() + '.json');
      res.json({
        row_count: results.length,
        truncated: results.length === EXPORT_ROW_LIMIT,
        data: results,
      });
    }
  } catch (err) {
    if (err && err.code === 'ER_QUERY_INTERRUPTED') {
      return res.status(504).json({ error: 'Export query was interrupted' });
    }
    if (!res.headersSent) {
      res.status(500).json({ error: err.message });
    } else {
      res.end();
    }
  }
});

// ==================== ROOT ROUTE ====================

app.get('/', (req, res) => {
  res.send('Library Management System API v2.0');
});

// 404 handler for unmatched API routes
app.use('/api', (req, res) => {
  res.status(404).json({ error: `Endpoint not found: ${req.method} ${req.path}` });
});

// Error handling middleware — must have 4 params.
app.use((err, req, res, next) => {
  const statusCode = err.status || err.statusCode || 500;
  const isServerError = statusCode >= 500;

  if (isServerError) {
    console.error(`[ERROR] ${req.method} ${req.path}:`, err);
  }

  const body = {
    success: false,
    error: isProduction && isServerError ? 'Internal server error' : (err.message || 'Internal server error'),
    ...(err.payload || {}),
  };

  if (!isProduction && isServerError && err.stack) {
    body.stack = err.stack.split('\n').slice(0, 4).join('\n');
  }

  res.status(statusCode).json(body);
});

// Start server after all routes are defined.
// IMPORTANT: Export app for tests/tools and only listen when run directly.
let activeServer = null;

const startServer = (port = PORT, host = 'localhost') => {
  // HTTPS support: if SSL_KEY and SSL_CERT env vars are set, create an HTTPS server
  const sslKeyPath = process.env.SSL_KEY;
  const sslCertPath = process.env.SSL_CERT;
  let server;

  if (sslKeyPath && sslCertPath && fs.existsSync(sslKeyPath) && fs.existsSync(sslCertPath)) {
    const httpsOptions = {
      key: fs.readFileSync(sslKeyPath),
      cert: fs.readFileSync(sslCertPath),
    };
    server = https.createServer(httpsOptions, app).listen(port, host, () => {
      console.log(`HTTPS server running on port ${port}`);
    });
  } else {
    server = app.listen(port, host, () => {
      console.log(`Server running on port ${port}${sslKeyPath && !fs.existsSync(sslKeyPath) ? ' (SSL cert not found, falling back to HTTP)' : ''}`);
    });
  }

  activeServer = server;

  server.on('error', (err) => {
    if (err && err.code === 'EADDRINUSE') {
      console.error(
        `Port ${port} is already in use. Stop the existing server process or change PORT in backend/.env`
      );
      process.exit(1);
    }
    console.error('Failed to start server:', err);
    process.exit(1);
  });

  return server;
};

// Graceful shutdown handling
const gracefulShutdown = (signal) => {
  console.log(`\n${signal} received. Starting graceful shutdown...`);
  
  // Stop accepting new connections
  if (activeServer) {
    activeServer.close((err) => {
      if (err) {
        console.error('Error closing server:', err);
        process.exit(1);
      }
      console.log('HTTP server closed.');
      
      // Close database pool
      db.end((dbErr) => {
        if (dbErr) {
          console.error('Error closing database pool:', dbErr);
          process.exit(1);
        }
        console.log('Database connections closed.');
        console.log('Graceful shutdown complete.');
        process.exit(0);
      });
    });
    
    // Force close after 10 seconds if graceful shutdown takes too long
    setTimeout(() => {
      console.error('Graceful shutdown timed out, forcing exit...');
      process.exit(1);
    }, 10000);
  } else {
    process.exit(0);
  }
};

// Handle shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handle uncaught exceptions to prevent silent crashes
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  gracefulShutdown('Uncaught Exception');
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  // Don't exit on unhandled rejections, just log them
});

if (require.main === module) {
  startServer();
}

module.exports = { app, startServer, db, dbQuery };
