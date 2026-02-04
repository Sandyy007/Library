/**
 * Generate a large test CSV file with 10,000 books for testing imports
 */

const fs = require('fs');
const path = require('path');

const NUM_BOOKS = 10000;
const OUTPUT_FILE = path.join(__dirname, 'test_10k_books.csv');

const categories = [
  'Fiction', 'Non-Fiction', 'Science', 'Technology', 'History', 
  'Biography', 'Self-Help', 'Children', 'Romance', 'Mystery',
  'Fantasy', 'Science Fiction', 'Horror', 'Poetry', 'Drama'
];

const publishers = [
  'Penguin Random House', 'HarperCollins', 'Simon & Schuster',
  'Macmillan Publishers', 'Hachette Book Group', 'Oxford University Press',
  'Cambridge University Press', 'Scholastic', 'Pearson', 'McGraw-Hill'
];

const firstNames = [
  'James', 'John', 'Robert', 'Michael', 'William', 'David', 'Richard',
  'Mary', 'Patricia', 'Jennifer', 'Linda', 'Barbara', 'Elizabeth',
  'Sarah', 'Emily', 'Jessica', 'Ashley', 'Amanda', 'Raj', 'Amit',
  'Priya', 'Kavita', 'Rahul', 'Vijay', 'Anita', 'Sunita'
];

const lastNames = [
  'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller',
  'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez',
  'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Sharma', 'Patel',
  'Kumar', 'Singh', 'Gupta', 'Joshi', 'Verma', 'Rao'
];

const adjectives = [
  'Complete', 'Essential', 'Ultimate', 'Modern', 'Classic', 'Advanced',
  'Beginner\'s', 'Professional', 'Practical', 'Comprehensive', 'Quick',
  'Easy', 'Master', 'Expert', 'Fundamental', 'Basic', 'Intermediate'
];

const nouns = [
  'Guide', 'Handbook', 'Manual', 'Introduction', 'Course', 'Tutorial',
  'Reference', 'Companion', 'Workbook', 'Collection', 'Journey', 'Story',
  'Adventure', 'Mystery', 'Chronicles', 'Tales', 'Secrets', 'World'
];

const topics = [
  'Programming', 'Data Science', 'Machine Learning', 'Web Development',
  'Mobile Apps', 'Database Design', 'Cloud Computing', 'Cybersecurity',
  'Business Strategy', 'Leadership', 'Marketing', 'Finance', 'Economics',
  'Psychology', 'Philosophy', 'Art History', 'Music Theory', 'Cooking',
  'Gardening', 'Photography', 'Travel', 'Health', 'Fitness', 'Meditation'
];

function randomElement(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function generateISBN() {
  const prefix = '978';
  const group = Math.floor(Math.random() * 2); // 0 or 1
  const publisher = String(Math.floor(Math.random() * 100000)).padStart(5, '0');
  const title = String(Math.floor(Math.random() * 1000)).padStart(3, '0');
  const check = Math.floor(Math.random() * 10);
  return `${prefix}-${group}-${publisher}-${title}-${check}`;
}

function generateTitle(index) {
  const type = index % 4;
  switch (type) {
    case 0:
      return `The ${randomElement(adjectives)} ${randomElement(nouns)} to ${randomElement(topics)}`;
    case 1:
      return `${randomElement(topics)}: A ${randomElement(adjectives)} ${randomElement(nouns)}`;
    case 2:
      return `${randomElement(adjectives)} ${randomElement(topics)} ${randomElement(nouns)}`;
    default:
      return `${randomElement(topics)} for ${randomElement(['Beginners', 'Professionals', 'Everyone', 'Students', 'Experts'])}`;
  }
}

function generateAuthor() {
  return `${randomElement(firstNames)} ${randomElement(lastNames)}`;
}

function generateRack() {
  const section = String.fromCharCode(65 + Math.floor(Math.random() * 26)); // A-Z
  const row = Math.floor(Math.random() * 50) + 1;
  const shelf = Math.floor(Math.random() * 10) + 1;
  return `${section}-${row}-${shelf}`;
}

function generateYear() {
  return 1950 + Math.floor(Math.random() * 75); // 1950-2024
}

function generateCopies() {
  return Math.floor(Math.random() * 5) + 1; // 1-5 copies
}

function escapeCSV(value) {
  if (value == null) return '';
  const str = String(value);
  if (str.includes(',') || str.includes('"') || str.includes('\n')) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

console.log(`Generating ${NUM_BOOKS} books to ${OUTPUT_FILE}...`);

const header = 'ISBN,Title,Author,Category,Publisher,Year,Rack Number,Copies\n';
let content = header;

for (let i = 1; i <= NUM_BOOKS; i++) {
  const book = {
    isbn: generateISBN(),
    title: generateTitle(i),
    author: generateAuthor(),
    category: randomElement(categories),
    publisher: randomElement(publishers),
    year: generateYear(),
    rack: generateRack(),
    copies: generateCopies()
  };
  
  content += [
    escapeCSV(book.isbn),
    escapeCSV(book.title),
    escapeCSV(book.author),
    escapeCSV(book.category),
    escapeCSV(book.publisher),
    book.year,
    escapeCSV(book.rack),
    book.copies
  ].join(',') + '\n';
  
  if (i % 1000 === 0) {
    console.log(`Generated ${i} books...`);
  }
}

fs.writeFileSync(OUTPUT_FILE, content, 'utf8');
console.log(`\nDone! Generated ${NUM_BOOKS} books.`);
console.log(`File size: ${(fs.statSync(OUTPUT_FILE).size / 1024 / 1024).toFixed(2)} MB`);
console.log(`File path: ${OUTPUT_FILE}`);
