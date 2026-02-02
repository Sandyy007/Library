const mysql = require('mysql2');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const db = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'library_management'
});

console.log('Attempting to connect to:', {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  database: process.env.DB_NAME || 'library_management'
});

db.connect((err) => {
  if (err) {
    console.error('Connection failed:', err.message);
    console.error('Error code:', err.code);
    process.exit(1);
  } else {
    console.log('✅ Connected to MySQL database');
    
    db.query('SELECT COUNT(*) as book_count FROM books', (err, results) => {
      if (err) {
        console.error('Query error:', err.message);
      } else {
        console.log('Books in database:', results[0].book_count);
      }
      
      db.end(() => {
        console.log('Connection closed');
        process.exit(0);
      });
    });
  }
});
