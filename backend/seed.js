const mysql = require('mysql2/promise');

async function seedDatabase() {
  const connection = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: 'admin',
    database: 'library_management'
  });

  try {
    console.log('Starting data insertion...');

    // Insert sample books
    const bookQueries = [
      ["INSERT INTO books (isbn, title, author, category, publisher, year_published, status) VALUES ('978-0-7432-7356-5', 'The Great Gatsby', 'F. Scott Fitzgerald', 'Fiction', 'Scribner', 1925, 'available')"],
      ["INSERT INTO books (isbn, title, author, category, publisher, year_published, status) VALUES ('978-0-06-112008-4', 'To Kill a Mockingbird', 'Harper Lee', 'Fiction', 'J.B. Lippincott', 1960, 'available')"],
      ["INSERT INTO books (isbn, title, author, category, publisher, year_published, status) VALUES ('978-0-14-028329-7', '1984', 'George Orwell', 'Fiction', 'Secker & Warburg', 1949, 'available')"],
      ["INSERT INTO books (isbn, title, author, category, publisher, year_published, status) VALUES ('978-0-7432-7357-2', 'Pride and Prejudice', 'Jane Austen', 'Fiction', 'T. Egerton', 1813, 'available')"],
      ["INSERT INTO books (isbn, title, author, category, publisher, year_published, status) VALUES ('978-0-451-52494-2', 'Moby Dick', 'Herman Melville', 'Fiction', 'Richard Bentley', 1851, 'available')"],
    ];

    for (const query of bookQueries) {
      try {
        await connection.execute(query[0]);
        console.log('Book inserted');
      } catch (err) {
        console.log('Error inserting book (may already exist):', err.message);
      }
    }

    // Insert sample members
    const memberQueries = [
      ["INSERT INTO members (name, email, phone, member_type, membership_date) VALUES ('John Doe', 'john@example.com', '555-1234', 'student', '2024-01-01')"],
      ["INSERT INTO members (name, email, phone, member_type, membership_date) VALUES ('Jane Smith', 'jane@example.com', '555-5678', 'staff', '2024-01-05')"],
      ["INSERT INTO members (name, email, phone, member_type, membership_date) VALUES ('Bob Johnson', 'bob@example.com', '555-9012', 'student', '2024-01-10')"],
      ["INSERT INTO members (name, email, phone, member_type, membership_date) VALUES ('Alice Williams', 'alice@example.com', '555-3456', 'staff', '2024-01-15')"],
    ];

    for (const query of memberQueries) {
      try {
        await connection.execute(query[0]);
        console.log('Member inserted');
      } catch (err) {
        console.log('Error inserting member (may already exist):', err.message);
      }
    }

    // Get IDs for creating issues
    const [books] = await connection.execute('SELECT id FROM books LIMIT 1');
    const [members] = await connection.execute('SELECT id FROM members LIMIT 1');
    
    if (books.length > 0 && members.length > 0) {
      const bookId = books[0].id;
      const memberId = members[0].id;

      // Insert sample issues
      const issueQueries = [
        [
          "INSERT INTO issues (book_id, member_id, issue_date, due_date, return_date, status) VALUES (?, ?, '2024-01-15', '2024-02-15', NULL, 'issued')",
          [bookId, memberId]
        ],
      ];

      for (const query of issueQueries) {
        try {
          await connection.execute(query[0], query[1]);
          console.log('Issue inserted');
        } catch (err) {
          console.log('Error inserting issue:', err.message);
        }
      }
    }

    // Verify data
    const [bookCount] = await connection.execute('SELECT COUNT(*) as count FROM books');
    const [memberCount] = await connection.execute('SELECT COUNT(*) as count FROM members');
    const [issueCount] = await connection.execute('SELECT COUNT(*) as count FROM issues');

    console.log('\n=== Data Summary ===');
    console.log('Books:', bookCount[0].count);
    console.log('Members:', memberCount[0].count);
    console.log('Issues:', issueCount[0].count);

  } catch (error) {
    console.error('Fatal error:', error.message);
  } finally {
    await connection.end();
    process.exit(0);
  }
}

seedDatabase();
