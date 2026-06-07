const mysql = require('mysql2/promise');

async function test() {
  try {
    console.log('Connecting to database...');
    const connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'admin',
      database: 'library_management'
    });
    console.log('Connected!');
    
    const [result] = await connection.execute('SELECT COUNT(*) as count FROM books');
    console.log('Current books count:', result[0].count);
    
    await connection.end();
  } catch (error) {
    console.error('Error:', error.message);
  }
}

test();
