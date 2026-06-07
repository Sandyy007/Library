/**
 * Update admin password to Library#123
 * Run this script after changing the default password in schema files
 */

const mysql = require('mysql2/promise');
const bcrypt = require('bcrypt');
require('dotenv').config();

async function updatePassword() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'admin',
    database: process.env.DB_NAME || 'library_management'
  });

  try {
    const newPassword = 'Library#123';
    const hash = await bcrypt.hash(newPassword, 10);
    
    console.log('Updating admin and librarian passwords...');
    
    await connection.execute(
      'UPDATE users SET password_hash = ? WHERE username = ?',
      [hash, 'admin']
    );
    
    await connection.execute(
      'UPDATE users SET password_hash = ? WHERE username = ?',
      [hash, 'librarian']
    );
    
    console.log('Passwords updated successfully!');
    console.log('New password for admin and librarian: Library#123');
  } catch (error) {
    console.error('Error updating password:', error.message);
  } finally {
    await connection.end();
  }
}

updatePassword();
