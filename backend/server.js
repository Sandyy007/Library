const express = require('express');
const mysql = require('mysql2');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const path = require('path');
const multer = require('multer');
const fs = require('fs');
const { parse: parseCsv } = require('csv-parse/sync');
const xlsx = require('xlsx');

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
app.set('trust proxy', 1);

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  })
);

const allowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

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

// Rate limiting is mainly for public-facing deployments.
// For local desktop usage (NODE_ENV !== 'production'), it can easily block legitimate UI traffic.
const rateLimitEnabled = String(process.env.RATE_LIMIT_ENABLED ?? 'true').toLowerCase() !== 'false';
if (isProduction && rateLimitEnabled) {
  app.use(
    '/api',
    rateLimit({
      windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000),
      max: Number(process.env.RATE_LIMIT_MAX || 300),
      standardHeaders: true,
      legacyHeaders: false,
    })
  );
}

// Serve uploaded files statically
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

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
    cb(null, uniqueSuffix + path.extname(file.originalname));
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
const importUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 }, // 25MB
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

// Promote overdue issues to "overdue" status before returning data/stats
const refreshOverdueStatuses = () =>
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

// Generate notifications for overdue and due-soon books
const generateNotifications = async () => {
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

// MySQL connection
const db = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'library_management',
  charset: 'utf8mb4',
});

db.connect((err) => {
  if (err) {
    console.error('Database connection failed:', err.message);
    console.log('Server will continue with sample data only');
  } else {
    console.log('Connected to MySQL database');
    // Run migrations on startup (skip in unit tests).
    if (process.env.NODE_ENV !== 'test') {
      runMigrations();
    }
  }
});

// Run database migrations
const runMigrations = () => {
  const dbName = db.config?.database || process.env.DB_NAME || 'library_management';

  const migrations = [
    `ALTER DATABASE \`${dbName}\` CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci`,
    "ALTER TABLE books CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE members CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE issues CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE users CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE notifications CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE member_categories CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE book_categories CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE dashboard_settings CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci",
    "ALTER TABLE books MODIFY COLUMN isbn VARCHAR(20) NULL",
    "ALTER TABLE books ADD COLUMN cover_image TEXT",
    "ALTER TABLE books ADD COLUMN total_copies INT DEFAULT 1",
    "ALTER TABLE books ADD COLUMN available_copies INT DEFAULT 1",
    "ALTER TABLE books ADD COLUMN description TEXT",
    "ALTER TABLE books ADD COLUMN rack_number VARCHAR(50)",
    // Support 'guest' (new name) while remaining backward compatible with existing 'student' values.
    "ALTER TABLE members MODIFY COLUMN member_type ENUM('student', 'guest', 'faculty', 'staff') NOT NULL DEFAULT 'guest'",
    "UPDATE members SET member_type = 'guest' WHERE member_type = 'student'",
    "ALTER TABLE members ADD COLUMN profile_photo TEXT",
    "ALTER TABLE members ADD COLUMN address TEXT",
    "ALTER TABLE members ADD COLUMN expiry_date DATE",
    "ALTER TABLE members ADD COLUMN is_active BOOLEAN DEFAULT TRUE",
    "ALTER TABLE issues ADD COLUMN notes TEXT",
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
    `INSERT IGNORE INTO member_categories (name, max_books, loan_period_days) VALUES
      ('student', 3, 14)`,
    `INSERT IGNORE INTO member_categories (name, max_books, loan_period_days) VALUES
      ('faculty', 10, 30)`,
    `INSERT IGNORE INTO member_categories (name, max_books, loan_period_days) VALUES
      ('staff', 5, 21)`,
    "UPDATE books SET total_copies = 1, available_copies = CASE WHEN status = 'available' THEN 1 ELSE 0 END WHERE total_copies IS NULL"
  ];

  migrations.forEach(sql => {
    db.query(sql, (err) => {
      if (err && !err.message.includes('Duplicate')) {
        // Silently ignore expected errors (column already exists, etc.)
      }
    });
  });
  console.log('Database migrations completed');
};

// Middleware for authentication
const authenticateToken = (req, res, next) => {
  const token = req.header('Authorization')?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Access denied' });

  if (!JWT_SECRET) {
    return res.status(500).json({ error: 'Server misconfigured: missing JWT secret' });
  }

  jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] }, (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid token' });
    req.user = user;
    next();
  });
};

// ==================== AUTH ROUTES ====================

app.post(
  '/api/auth/login',
  body('username').isString().trim().isLength({ min: 1, max: 64 }),
  body('password').isString().isLength({ min: 1, max: 256 }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Invalid login request' });
    }

    const { username, password } = req.body;
  db.query('SELECT * FROM users WHERE username = ?', [username], async (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0) return res.status(401).json({ error: 'Invalid credentials' });

    const user = results[0];
    
    if (user.role !== 'admin') {
      return res.status(403).json({ error: 'Only admin users are allowed to access this system' });
    }
    
    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) return res.status(401).json({ error: 'Invalid credentials' });

    if (!JWT_SECRET) {
      return res.status(500).json({ error: 'Server misconfigured: missing JWT secret' });
    }

    const token = jwt.sign({ id: user.id, role: user.role }, JWT_SECRET, {
      expiresIn: JWT_EXPIRES_IN,
      algorithm: 'HS256',
    });
    res.json({ token, user: { id: user.id, username: user.username, role: user.role } });
  });
  }
);

// Require authentication (admin-only) for all other API routes
app.use('/api', (req, res, next) => {
  if (req.path === '/auth/login') return next();
  authenticateToken(req, res, next);
});

app.use('/api', (req, res, next) => {
  if (req.path === '/auth/login') return next();
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ error: 'Forbidden' });
  }
  next();
});

// Current authenticated user
app.get('/api/auth/me', (req, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Access denied' });
  db.query(
    'SELECT id, username, role FROM users WHERE id = ? LIMIT 1',
    [userId],
    (err, results) => {
      if (err) return res.status(500).json({ error: err.message });
      if (!results || results.length === 0) return res.status(404).json({ error: 'User not found' });
      res.json({ user: results[0] });
    }
  );
});

// ==================== BOOKS ROUTES ====================

app.get('/api/books', (req, res) => {
  const { search, category, author, year, status, available } = req.query;
  let query = 'SELECT * FROM books WHERE 1=1';
  const params = [];
  
  if (search) {
    query += ' AND (title LIKE ? OR author LIKE ? OR isbn LIKE ?)';
    const searchTerm = `%${search}%`;
    params.push(searchTerm, searchTerm, searchTerm);
  }
  if (category) {
    query += ' AND category = ?';
    params.push(category);
  }
  if (author) {
    query += ' AND author LIKE ?';
    params.push(`%${author}%`);
  }
  if (year) {
    query += ' AND year_published = ?';
    params.push(year);
  }
  if (status) {
    query += ' AND status = ?';
    params.push(status);
  }
  if (available === 'true') {
    query += ' AND (available_copies > 0 OR status = "available")';
  }
  
  query += ' ORDER BY title ASC';
  
  db.query(query, params, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
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
    if (newAvailableCopies === 0) {
      newStatus = 'issued';
    } else if (newAvailableCopies < newTotalCopies) {
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

// Import books from CSV/XLSX. Required: title + author. Optional: rack_number, isbn.
// Inserts new books or updates existing by ISBN (if provided) else by (title+author).
app.post('/api/books/import', importUpload.single('file'), async (req, res) => {
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

    const looksLikeLegacyHindi = (text) => {
      const s = String(text || '').trim();
      if (!s) return false;
      // If it already contains Devanagari, it's Unicode Hindi and fine.
      if (/[\u0900-\u097F]/.test(s)) return false;
      // Heuristic for KrutiDev/legacy Hindi text: lots of ASCII letters + frequent ;/* characters.
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

    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const title = String(pick(row, titleKeys) ?? '').trim();
      const author = String(pick(row, authorKeys) ?? '').trim();
      const rackNumber = String(pick(row, rackKeys) ?? '').trim();
      const isbn = String(pick(row, isbnKeys) ?? '').trim();

      if (!title || !author) {
        skipped++;
        errors.push({ row: i + 2, error: 'Missing required Title or Author' });
        continue;
      }

      if (looksLikeLegacyHindi(title) || looksLikeLegacyHindi(author)) {
        legacyHindiRows++;
      }

      const normalizedIsbn = isbn ? isbn : null;
      const normalizedRack = rackNumber ? rackNumber : null;

      try {
        let existing = null;
        if (normalizedIsbn) {
          const found = await dbQuery('SELECT id FROM books WHERE isbn = ? LIMIT 1', [normalizedIsbn]);
          existing = Array.isArray(found) && found.length > 0 ? found[0] : null;
        }
        if (!existing) {
          const found = await dbQuery('SELECT id FROM books WHERE title = ? AND author = ? LIMIT 1', [title, author]);
          existing = Array.isArray(found) && found.length > 0 ? found[0] : null;
        }

        if (existing) {
          await dbQuery(
            'UPDATE books SET title = ?, author = ?, rack_number = ?, isbn = ? WHERE id = ?',
            [title, author, normalizedRack, normalizedIsbn, existing.id]
          );
          updated++;
        } else {
          await dbQuery(
            'INSERT INTO books (isbn, title, author, rack_number, total_copies, available_copies, status) VALUES (?, ?, ?, ?, 1, 1, \'available\')',
            [normalizedIsbn, title, author, normalizedRack]
          );
          inserted++;
        }
      } catch (e) {
        errors.push({ row: i + 2, error: e.message || String(e) });
      }
    }

    return res.json({ inserted, updated, skipped, errors, totalRows: rows.length, legacyHindiRows });
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
      return res.json(defaultCategories.map((name, index) => ({ id: index + 1, name })));
    }
    res.json(results);
  });
});

app.post('/api/categories', (req, res) => {
  const { name, description } = req.body;
  db.query('INSERT INTO book_categories (name, description) VALUES (?, ?)', [name, description], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ id: result.insertId });
  });
});

// ==================== MEMBERS ROUTES ====================

app.get('/api/members', (req, res) => {
  const { search, type, active } = req.query;
  let query = 'SELECT * FROM members WHERE 1=1';
  const params = [];
  
  if (search) {
    query += ' AND (name LIKE ? OR email LIKE ? OR phone LIKE ?)';
    const searchTerm = `%${search}%`;
    params.push(searchTerm, searchTerm, searchTerm);
  }
  if (type) {
    query += ' AND member_type = ?';
    params.push(type);
  }
  if (active !== undefined) {
    query += ' AND (is_active = ? OR is_active IS NULL)';
    params.push(active === 'true');
  }
  
  query += ' ORDER BY name ASC';
  
  db.query(query, params, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
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
  db.query(
    'INSERT INTO members (name, email, phone, member_type, membership_date, profile_photo, address, expiry_date, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, TRUE)',
    [name, email, phone, member_type || 'student', membership_date, profile_photo, address, expiry_date],
    (err, result) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ id: result.insertId });
    }
  );
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
      const email = body.email !== undefined ? body.email : existing.email;
      const phone = body.phone ?? existing.phone;

      // Support both snake_case and camelCase keys from clients.
      const memberTypeRaw = body.member_type ?? body.memberType ?? existing.member_type;
      const membershipDate = body.membership_date ?? body.membershipDate ?? existing.membership_date;
      const profilePhoto = body.profile_photo ?? body.profilePhoto ?? existing.profile_photo;
      const address = body.address !== undefined ? body.address : existing.address;
      const expiryDate = body.expiry_date ?? body.expiryDate ?? existing.expiry_date;

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

      res.json({ message: 'Member updated' });
    } catch (err) {
      res.status(500).json({ error: err?.message || String(err) });
    }
  })();
});

app.put('/api/members/:id/deactivate', (req, res) => {
  db.query('UPDATE members SET is_active = FALSE WHERE id = ?', [req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Member deactivated' });
  });
});

app.put('/api/members/:id/activate', (req, res) => {
  db.query('UPDATE members SET is_active = TRUE WHERE id = ?', [req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Member activated' });
  });
});

app.delete('/api/members/:id', (req, res) => {
  db.query('DELETE FROM members WHERE id = ?', [req.params.id], (err) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ message: 'Member deleted' });
  });
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

// Get member borrowing history
app.get('/api/members/:id/history', (req, res) => {
  db.query(`
    SELECT i.*, b.title, b.author, b.isbn, b.category, b.cover_image
    FROM issues i
    JOIN books b ON i.book_id = b.id
    WHERE i.member_id = ?
    ORDER BY i.issue_date DESC
  `, [req.params.id], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

// Get member borrowing limits based on type
app.get('/api/member-categories', (req, res) => {
  db.query('SELECT * FROM member_categories', (err, results) => {
    if (err || results.length === 0) {
      // Return default values if table doesn't exist
      return res.json([
        { name: 'student', max_books: 3, loan_period_days: 14 },
        { name: 'faculty', max_books: 10, loan_period_days: 30 },
        { name: 'staff', max_books: 5, loan_period_days: 21 }
      ]);
    }
    res.json(results);
  });
});

// ==================== ISSUES ROUTES ====================

app.get('/api/issues', async (req, res) => {
  await refreshOverdueStatuses();
  try {
    await generateNotifications();
  } catch (e) {
    // Ignore notification errors
  }

  const { member_id, book_id, status } = req.query;
  let query = `
    SELECT i.id, i.book_id, i.member_id, i.issue_date, i.due_date, i.return_date, i.status, i.notes,
           b.title, b.author, b.cover_image,
           m.name as member_name, m.profile_photo as member_photo
    FROM issues i
    JOIN books b ON i.book_id = b.id
    JOIN members m ON i.member_id = m.id
    WHERE 1=1
  `;
  const params = [];
  
  if (member_id) {
    query += ' AND i.member_id = ?';
    params.push(member_id);
  }
  if (book_id) {
    query += ' AND i.book_id = ?';
    params.push(book_id);
  }
  if (status) {
    query += ' AND i.status = ?';
    params.push(status);
  }
  
  query += ' ORDER BY i.issue_date DESC';

  db.query(query, params, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

app.post('/api/issues', (req, res) => {
  const { book_id, member_id, due_date } = req.body;
  const now = new Date();
  const issue_date = now.toISOString().split('T')[0];

  // Check if book has available copies
  db.query('SELECT * FROM books WHERE id = ?', [book_id], (err, bookResults) => {
    if (err) return res.status(500).json({ error: err.message });
    if (bookResults.length === 0) return res.status(404).json({ error: 'Book not found' });
    
    const book = bookResults[0];
    const availableCopies = book.available_copies !== undefined ? book.available_copies : (book.status === 'available' ? 1 : 0);
    
    if (availableCopies <= 0) {
      return res.status(400).json({ error: 'No copies available for this book' });
    }

    // Check member exists and their borrowing limit
    db.query(`
      SELECT m.*, mc.max_books 
      FROM members m
      LEFT JOIN member_categories mc ON m.member_type = mc.name
      WHERE m.id = ?
    `, [member_id], (err, memberResults) => {
      if (err) return res.status(500).json({ error: err.message });
      if (memberResults.length === 0) return res.status(404).json({ error: 'Member not found' });

      const member = memberResults[0];
      const maxBooks = member.max_books || 3;

      // Check current borrowed books count
      db.query(
        "SELECT COUNT(*) as count FROM issues WHERE member_id = ? AND status IN ('issued', 'overdue')",
        [member_id],
        (err, countResults) => {
          if (err) return res.status(500).json({ error: err.message });
          
          if (countResults[0].count >= maxBooks) {
            return res.status(400).json({ 
              error: `Member has reached maximum borrowing limit of ${maxBooks} books` 
            });
          }

          // Issue the book
          db.query(
            'INSERT INTO issues (book_id, member_id, issue_date, due_date) VALUES (?, ?, ?, ?)',
            [book_id, member_id, issue_date, due_date],
            (err, result) => {
              if (err) return res.status(500).json({ error: err.message });
              
              // Update book availability
              const newAvailable = availableCopies - 1;
              const newStatus = newAvailable <= 0 ? 'issued' : 'issued';
              
              db.query(
                'UPDATE books SET available_copies = ?, status = ? WHERE id = ?',
                [newAvailable, newStatus, book_id]
              );
              
              res.json({ id: result.insertId });
            }
          );
        }
      );
    });
  });
});

app.put('/api/issues/:id/return', (req, res) => {
  const now = new Date();
  const return_date = now.toISOString().split('T')[0];

  db.query('SELECT * FROM issues WHERE id = ?', [req.params.id], (err, issueResults) => {
    if (err) return res.status(500).json({ error: err.message });
    if (issueResults.length === 0) return res.status(404).json({ error: 'Issue not found' });
    if (issueResults[0].status === 'returned') return res.status(400).json({ error: 'Book is already returned' });

    const issue = issueResults[0];
    
    db.query(
      'UPDATE issues SET return_date = ?, status = "returned" WHERE id = ?',
      [return_date, req.params.id],
      (err) => {
        if (err) return res.status(500).json({ error: err.message });
        
        // Update book availability
        db.query('SELECT * FROM books WHERE id = ?', [issue.book_id], (err, bookResults) => {
          if (!err && bookResults.length > 0) {
            const book = bookResults[0];
            const currentAvailable = book.available_copies !== undefined ? book.available_copies : 0;
            const newAvailable = currentAvailable + 1;
            const totalCopies = book.total_copies || 1;
            const newStatus = newAvailable >= totalCopies ? 'available' : 'issued';
            
            db.query(
              'UPDATE books SET available_copies = ?, status = ? WHERE id = ?',
              [newAvailable, newStatus, issue.book_id]
            );
          }
        });
        
        res.json({ message: 'Book returned successfully' });
      }
    );
  });
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

app.put('/api/issues/:id', (req, res) => {
  const { due_date, return_date, status } = req.body;

  db.query('SELECT * FROM issues WHERE id = ?', [req.params.id], (err, issueResults) => {
    if (err) return res.status(500).json({ error: err.message });
    if (issueResults.length === 0) return res.status(404).json({ error: 'Issue not found' });

    const issue = issueResults[0];
    let updateFields = [];
    let updateValues = [];

    if (due_date !== undefined) {
      updateFields.push('due_date = ?');
      updateValues.push(due_date);
    }

    if (return_date !== undefined) {
      updateFields.push('return_date = ?');
      updateValues.push(return_date);
    }

    if (status !== undefined) {
      updateFields.push('status = ?');
      updateValues.push(status);

      if (status === 'returned') {
        // Update book availability
        db.query('SELECT * FROM books WHERE id = ?', [issue.book_id], (err, bookResults) => {
          if (!err && bookResults.length > 0) {
            const book = bookResults[0];
            const currentAvailable = book.available_copies !== undefined ? book.available_copies : 0;
            const newAvailable = currentAvailable + 1;
            const totalCopies = book.total_copies || 1;
            const newStatus = newAvailable >= totalCopies ? 'available' : 'issued';
            
            db.query(
              'UPDATE books SET available_copies = ?, status = ? WHERE id = ?',
              [newAvailable, newStatus, issue.book_id]
            );
          }
        });
        
        if (return_date === undefined) {
          updateFields.push('return_date = ?');
          updateValues.push(new Date().toISOString().split('T')[0]);
        }
      }
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    updateValues.push(req.params.id);
    const query = `UPDATE issues SET ${updateFields.join(', ')} WHERE id = ?`;

    db.query(query, updateValues, async (err) => {
      if (err) return res.status(500).json({ error: err.message });

      res.json({ message: 'Issue updated successfully' });
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

  const overdueDays = parseNonNegativeInt(req.query.overdue_days, 7);
  const lowStockThreshold = parseNonNegativeInt(req.query.low_stock_threshold, 1);
  const inactiveDays = parsePositiveInt(req.query.inactive_days, 60);
  const limit = parsePositiveInt(req.query.limit, 10);

  const response = {
    overdue: { count: 0, items: [] },
    dueToday: { count: 0, items: [] },
    dueTomorrow: { count: 0, items: [] },
    lowStock: { count: 0, items: [] },
    inactiveMembers: { count: 0, items: [] },
    deactivatedMembers: { count: 0, items: [] },
    kpis: {
      utilization_rate: 0,
      availability_rate: 0,
      avg_checkout_duration_days: 0,
    },
  };

  const withCountsAndItems = (countSql, countParams, itemsSql, itemsParams, assign) =>
    new Promise((resolve) => {
      db.query(countSql, countParams, (err, countRows) => {
        const count = err ? 0 : Number(countRows?.[0]?.count || 0);
        db.query(itemsSql, itemsParams, (err2, itemRows) => {
          const items = err2 ? [] : itemRows;
          assign(count, items);
          resolve();
        });
      });
    });

  try {
    await withCountsAndItems(
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
    );

    await withCountsAndItems(
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
    );

    await withCountsAndItems(
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
    );

    await withCountsAndItems(
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
        LIMIT ?
      `,
      [lowStockThreshold, limit],
      (count, items) => {
        response.lowStock = { count, items };
      }
    );

    await withCountsAndItems(
      `
        SELECT COUNT(*) AS count
        FROM members m
        LEFT JOIN (
          SELECT member_id, MAX(issue_date) AS last_issue_date
          FROM issues
          GROUP BY member_id
        ) li ON li.member_id = m.id
        WHERE (m.is_active = TRUE OR m.is_active IS NULL)
          AND (li.last_issue_date IS NULL OR li.last_issue_date < DATE_SUB(CURDATE(), INTERVAL ? DAY))
      `,
      [inactiveDays],
      `
        SELECT m.id, m.name, m.email, m.phone, m.member_type, m.profile_photo, m.is_active,
               li.last_issue_date
        FROM members m
        LEFT JOIN (
          SELECT member_id, MAX(issue_date) AS last_issue_date
          FROM issues
          GROUP BY member_id
        ) li ON li.member_id = m.id
        WHERE (m.is_active = TRUE OR m.is_active IS NULL)
          AND (li.last_issue_date IS NULL OR li.last_issue_date < DATE_SUB(CURDATE(), INTERVAL ? DAY))
        ORDER BY (li.last_issue_date IS NULL) DESC, li.last_issue_date ASC
        LIMIT ?
      `,
      [inactiveDays, limit],
      (count, items) => {
        response.inactiveMembers = { count, items };
      }
    );

    await withCountsAndItems(
      `
        SELECT COUNT(*) AS count
        FROM members
        WHERE is_active = FALSE
      `,
      [],
      `
        SELECT id, name, email, phone, member_type, profile_photo, is_active, membership_date, expiry_date
        FROM members
        WHERE is_active = FALSE
        ORDER BY name ASC
        LIMIT ?
      `,
      [limit],
      (count, items) => {
        response.deactivatedMembers = { count, items };
      }
    );

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

      // Build the UNION first, then apply the cutoff in an outer WHERE on a unified DATETIME.
      // This makes "Clear" reliable even when source columns are DATE-only.
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
              CAST(i.issue_date AS DATETIME) AS occurred_at,
              (CONCAT('Issued: ', CONVERT(b.title USING utf8mb4)) COLLATE utf8mb4_unicode_ci) AS title,
              (CONCAT(CONVERT(m.name USING utf8mb4), ' borrowed "', CONVERT(b.title USING utf8mb4), '"') COLLATE utf8mb4_unicode_ci) AS description
            FROM issues i
            JOIN books b ON i.book_id = b.id
            JOIN members m ON i.member_id = m.id
          )
          UNION ALL
          (
            SELECT
              CAST('return' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS type,
              i.id AS related_id,
              CAST('issue' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS related_type,
              CAST(i.return_date AS DATETIME) AS occurred_at,
              (CONCAT('Returned: ', CONVERT(b.title USING utf8mb4)) COLLATE utf8mb4_unicode_ci) AS title,
              (CONCAT(CONVERT(m.name USING utf8mb4), ' returned "', CONVERT(b.title USING utf8mb4), '"') COLLATE utf8mb4_unicode_ci) AS description
            FROM issues i
            JOIN books b ON i.book_id = b.id
            JOIN members m ON i.member_id = m.id
            WHERE i.return_date IS NOT NULL
          )
          UNION ALL
          (
            SELECT
              CAST('book_added' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS type,
              b.id AS related_id,
              CAST('book' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS related_type,
              CAST(b.added_date AS DATETIME) AS occurred_at,
              (CONCAT('New book: ', CONVERT(b.title USING utf8mb4)) COLLATE utf8mb4_unicode_ci) AS title,
              (CONCAT('"', CONVERT(b.title USING utf8mb4), '" by ', CONVERT(b.author USING utf8mb4)) COLLATE utf8mb4_unicode_ci) AS description
            FROM books b
          )
          UNION ALL
          (
            SELECT
              CAST('member_added' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS type,
              m.id AS related_id,
              CAST('member' AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci AS related_type,
              CAST(m.membership_date AS DATETIME) AS occurred_at,
              (CONCAT('New member: ', CONVERT(m.name USING utf8mb4)) COLLATE utf8mb4_unicode_ci) AS title,
              (CONCAT(CONVERT(m.name USING utf8mb4), ' registered') COLLATE utf8mb4_unicode_ci) AS description
            FROM members m
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
  db.query(`
    SELECT i.issue_date, i.due_date, b.title, b.author, b.isbn, b.cover_image, m.name as member_name, m.profile_photo
    FROM issues i
    JOIN books b ON i.book_id = b.id
    JOIN members m ON i.member_id = m.id
    WHERE i.return_date IS NULL
    ORDER BY i.issue_date DESC
  `, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

app.get('/api/reports/overdue', async (req, res) => {
  await refreshOverdueStatuses();
  db.query(`
    SELECT i.due_date, i.issue_date, DATEDIFF(CURDATE(), i.due_date) as days_overdue,
           b.title, b.author, b.isbn, b.cover_image, 
           m.name as member_name, m.email, m.phone, m.profile_photo
    FROM issues i
    JOIN books b ON i.book_id = b.id
    JOIN members m ON i.member_id = m.id
    WHERE i.status = 'overdue'
    ORDER BY days_overdue DESC
  `, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
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
  const { unread_only, limit = 50 } = req.query;
  
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

      issueQuery += ' ORDER BY i.issue_date DESC LIMIT 100';

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
      
      // Get books not yet borrowed by member in similar categories/authors
      let query = `
        SELECT b.*
        FROM books b
        WHERE b.id NOT IN (SELECT book_id FROM issues WHERE member_id = ?)
        AND (b.available_copies > 0 OR b.status = 'available')
        AND (b.category IN (?) OR b.author IN (?))
        LIMIT 10
      `;
      
      db.query(query, [memberId, categories.length ? categories : [''], authors.length ? authors : ['']], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
      });
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
  
  // Delete existing layout settings, but preserve non-layout rows like activity cutoff.
  db.query(
    "DELETE FROM dashboard_settings WHERE user_id = ? AND widget_name <> 'recent_activity_cutoff'",
    [userId],
    (err) => {
    if (err) return res.status(500).json({ error: err.message });
    
    if (!widgets || widgets.length === 0) {
      return res.json({ message: 'Settings saved' });
    }
    
    // Insert new settings one by one
    let completed = 0;
    widgets.forEach((w, i) => {
      db.query(
        'INSERT INTO dashboard_settings (user_id, widget_name, is_visible, position, settings) VALUES (?, ?, ?, ?, ?)',
        [userId, w.widget_name, w.is_visible, i, JSON.stringify(w.settings || {})],
        () => {
          completed++;
          if (completed === widgets.length) {
            res.json({ message: 'Settings saved' });
          }
        }
      );
    });
    }
  );
});

// ==================== BACKUP & RESTORE ====================

app.get('/api/backup', (req, res) => {
  const backup = {
    timestamp: new Date().toISOString(),
    version: '2.0',
    data: {}
  };
  
  const tables = ['books', 'members', 'issues'];
  let completed = 0;
  
  tables.forEach(table => {
    db.query(`SELECT * FROM ${table}`, (err, results) => {
      backup.data[table] = err ? [] : results;
      completed++;
      
      if (completed === tables.length) {
        res.setHeader('Content-Type', 'application/json');
        res.setHeader('Content-Disposition', `attachment; filename=library_backup_${Date.now()}.json`);
        res.json(backup);
      }
    });
  });
});

app.post('/api/restore', (req, res) => {
  const { data, clear_existing } = req.body;
  
  if (!data) {
    return res.status(400).json({ error: 'No backup data provided' });
  }
  
  const restoreTable = (table, rows, callback) => {
    if (!rows || rows.length === 0) return callback();
    
    if (clear_existing) {
      db.query(`DELETE FROM ${table}`, (err) => {
        if (err) console.error(`Error clearing ${table}:`, err.message);
        insertRows();
      });
    } else {
      insertRows();
    }
    
    function insertRows() {
      const columns = Object.keys(rows[0]);
      const placeholders = columns.map(() => '?').join(', ');
      const query = `INSERT IGNORE INTO ${table} (${columns.join(', ')}) VALUES (${placeholders})`;
      
      let completed = 0;
      rows.forEach(row => {
        const values = columns.map(col => row[col]);
        db.query(query, values, () => {
          completed++;
          if (completed === rows.length) callback();
        });
      });
    }
  };
  
  // Restore in order
  restoreTable('books', data.books, () => {
    restoreTable('members', data.members, () => {
      restoreTable('issues', data.issues, () => {
        res.json({ message: 'Backup restored successfully' });
      });
    });
  });
});

// Export data to CSV format
app.get('/api/export/:type', (req, res) => {
  const { type } = req.params;
  const { format = 'json' } = req.query;
  
  let query = '';
  let filename = '';
  
  switch (type) {
    case 'books':
      query = 'SELECT id, isbn, title, author, category, publisher, year_published, total_copies, available_copies, status, added_date FROM books';
      filename = 'books_export';
      break;
    case 'members':
      query = 'SELECT id, name, email, phone, member_type, membership_date, is_active FROM members';
      filename = 'members_export';
      break;
    case 'issues':
      query = `
        SELECT i.id, b.title as book_title, b.isbn, m.name as member_name, 
               i.issue_date, i.due_date, i.return_date, i.status
        FROM issues i
        JOIN books b ON i.book_id = b.id
        JOIN members m ON i.member_id = m.id
      `;
      filename = 'issues_export';
      break;
    default:
      return res.status(400).json({ error: 'Invalid export type' });
  }
  
  db.query(query, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    
    if (format === 'csv') {
      if (results.length === 0) {
        return res.status(404).json({ error: 'No data to export' });
      }
      
      const headers = Object.keys(results[0]);
      let csv = headers.join(',') + '\n';
      
      results.forEach(row => {
        csv += headers.map(h => {
          const val = row[h];
          if (val === null || val === undefined) return '';
          const str = String(val);
          return str.includes(',') || str.includes('"') ? `"${str.replace(/"/g, '""')}"` : str;
        }).join(',') + '\n';
      });
      
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename=${filename}_${Date.now()}.csv`);
      res.send(csv);
    } else {
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Content-Disposition', `attachment; filename=${filename}_${Date.now()}.json`);
      res.json(results);
    }
  });
});

// ==================== ROOT ROUTE ====================

app.get('/', (req, res) => {
  res.send('Library Management System API v2.0');
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  // Avoid leaking internal details in production.
  const message = isProduction ? 'Internal server error' : (err.message || 'Internal server error');
  res.status(500).json({ error: message });
});

// Start server after all routes are defined.
// IMPORTANT: Export app for tests/tools and only listen when run directly.
const startServer = (port = PORT, host = 'localhost') => {
  const server = app.listen(port, host, () => {
    console.log(`Server running on port ${port}`);
  });

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

if (require.main === module) {
  startServer();
}

module.exports = { app, startServer, db, dbQuery };
