const mysql = require('mysql2');
require('dotenv').config();

const db = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'library_management'
});

db.connect((err) => {
  if (err) {
    console.error('Connection failed:', err);
    return;
  }
  console.log('Connected to database\n');

  // Check books
  db.query('SELECT COUNT(*) as count FROM books', (err, results) => {
    console.log(`Books count: ${results[0].count}`);
    db.query('SELECT * FROM books LIMIT 2', (err, results) => {
      console.log('Sample books:', results);
    });
  });

  // Check members
  db.query('SELECT COUNT(*) as count FROM members', (err, results) => {
    console.log(`\nMembers count: ${results[0].count}`);
    db.query('SELECT * FROM members LIMIT 2', (err, results) => {
      console.log('Sample members:', results);
    });
  });

  // Check issues
  db.query('SELECT COUNT(*) as count FROM issues', (err, results) => {
    console.log(`\nIssues count: ${results[0].count}`);
    db.query('SELECT * FROM issues LIMIT 2', (err, results) => {
      console.log('Sample issues:', results);
    });
  });

  // Check users
  db.query('SELECT COUNT(*) as count FROM users', (err, results) => {
    console.log(`\nUsers count: ${results[0].count}`);
    db.query('SELECT id, username, role FROM users', (err, results) => {
      console.log('Users:', results);
      db.end();
    });
  });
});
