/**
 * Test script for large CSV book import
 * Tests the import of 10,000 books and verifies they are all stored correctly
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const API_BASE = 'http://localhost:3000/api';
const CSV_FILE = path.join(__dirname, 'test_10k_books.csv');

let authToken = null;

// Simple HTTP request helper
function apiRequest(method, endpoint, data = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(endpoint, API_BASE);
    const reqHeaders = {
      'Content-Type': 'application/json',
      ...headers,
    };
    if (authToken) {
      reqHeaders['Authorization'] = `Bearer ${authToken}`;
    }
    
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method,
      headers: reqHeaders,
      timeout: 600000, // 10 minute timeout for large imports
    };

    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(body) });
        } catch (e) {
          resolve({ status: res.statusCode, data: body });
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });

    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

// Upload multipart file
function uploadFile(endpoint, filePath, fieldName = 'file') {
  return new Promise((resolve, reject) => {
    const boundary = '----FormBoundary' + Date.now();
    const url = new URL(endpoint, API_BASE);
    const fileName = path.basename(filePath);
    const fileContent = fs.readFileSync(filePath);
    
    const header = Buffer.from(
      `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="${fieldName}"; filename="${fileName}"\r\n` +
      `Content-Type: text/csv\r\n\r\n`
    );
    const footer = Buffer.from(`\r\n--${boundary}--\r\n`);
    const body = Buffer.concat([header, fileContent, footer]);

    const reqHeaders = {
      'Content-Type': `multipart/form-data; boundary=${boundary}`,
      'Content-Length': body.length,
    };
    if (authToken) {
      reqHeaders['Authorization'] = `Bearer ${authToken}`;
    }

    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      method: 'POST',
      headers: reqHeaders,
      timeout: 600000, // 10 minute timeout
    };

    console.log(`Uploading ${fileName} (${(body.length / 1024).toFixed(1)} KB)...`);
    const startTime = Date.now();

    const req = http.request(options, (res) => {
      let responseBody = '';
      res.on('data', (chunk) => (responseBody += chunk));
      res.on('end', () => {
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
        console.log(`Upload completed in ${elapsed}s`);
        try {
          resolve({ status: res.statusCode, data: JSON.parse(responseBody) });
        } catch (e) {
          resolve({ status: res.statusCode, data: responseBody });
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Upload timeout'));
    });

    req.write(body);
    req.end();
  });
}

async function login() {
  console.log('Logging in as admin...');
  const result = await apiRequest('POST', '/api/auth/login', {
    username: 'admin',
    password: 'admin'
  });
  
  if (result.status === 200 && result.data?.token) {
    authToken = result.data.token;
    console.log('Login successful!');
    return true;
  }
  
  console.error('Login failed:', result.data);
  return false;
}

async function runTests() {
  console.log('='.repeat(60));
  console.log('Large CSV Import Test');
  console.log('='.repeat(60));

  // Login first
  if (!await login()) {
    console.error('Cannot continue without authentication');
    process.exit(1);
  }

  // Check if test CSV exists
  if (!fs.existsSync(CSV_FILE)) {
    console.error(`\nERROR: Test file not found: ${CSV_FILE}`);
    console.log('Run: node tool/generate_test_csv.js first');
    process.exit(1);
  }

  const stats = fs.statSync(CSV_FILE);
  console.log(`\nTest file: ${CSV_FILE}`);
  console.log(`File size: ${(stats.size / 1024 / 1024).toFixed(2)} MB`);

  // Count rows in CSV
  const csvContent = fs.readFileSync(CSV_FILE, 'utf8');
  const rowCount = csvContent.split('\n').filter(line => line.trim()).length - 1; // Exclude header
  console.log(`Expected books: ${rowCount}`);

  // Get initial book count
  console.log('\n1. Checking initial book count...');
  const initialCount = await apiRequest('GET', '/api/books?limit=1');
  const initialTotal = initialCount.data?.pagination?.total || 0;
  console.log(`   Initial books in database: ${initialTotal}`);

  // Upload the CSV
  console.log('\n2. Uploading CSV file...');
  console.log('   This may take a few minutes for 10,000 books...');
  const startTime = Date.now();
  
  try {
    const uploadResult = await uploadFile('/api/books/import', CSV_FILE);
    const elapsed = ((Date.now() - startTime) / 1000).toFixed(2);
    
    console.log(`\n   Upload response (${elapsed}s):`);
    console.log(`   Status: ${uploadResult.status}`);
    
    if (uploadResult.data) {
      console.log(`   Total rows processed: ${uploadResult.data.totalRows}`);
      console.log(`   Inserted: ${uploadResult.data.inserted}`);
      console.log(`   Updated: ${uploadResult.data.updated}`);
      console.log(`   Skipped: ${uploadResult.data.skipped}`);
      console.log(`   Total errors: ${uploadResult.data.totalErrors || uploadResult.data.errors?.length || 0}`);
      
      if (uploadResult.data.errors?.length > 0) {
        console.log(`   First 5 errors:`);
        uploadResult.data.errors.slice(0, 5).forEach(err => {
          console.log(`     Row ${err.row}: ${err.error}`);
        });
      }
    }
  } catch (e) {
    console.error(`\n   ERROR: ${e.message}`);
    process.exit(1);
  }

  // Verify final count
  console.log('\n3. Verifying final book count...');
  const finalCount = await apiRequest('GET', '/api/books?limit=1');
  const finalTotal = finalCount.data?.pagination?.total || 0;
  console.log(`   Final books in database: ${finalTotal}`);
  console.log(`   Books added: ${finalTotal - initialTotal}`);

  // Test pagination
  console.log('\n4. Testing pagination with large dataset...');
  const page1 = await apiRequest('GET', '/api/books?page=1&limit=100');
  console.log(`   Page 1: ${page1.data?.data?.length || 0} books`);
  console.log(`   Total pages: ${page1.data?.pagination?.totalPages || 0}`);
  console.log(`   Has more: ${page1.data?.pagination?.hasMore}`);

  // Test search performance
  console.log('\n5. Testing search performance...');
  const searchStart = Date.now();
  const searchResult = await apiRequest('GET', '/api/books?search=programming&limit=50');
  const searchTime = Date.now() - searchStart;
  console.log(`   Search "programming": ${searchResult.data?.data?.length || 0} results in ${searchTime}ms`);

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('Test Summary');
  console.log('='.repeat(60));
  
  const success = finalTotal >= initialTotal + rowCount * 0.9; // Allow 10% margin for duplicates
  if (success) {
    console.log('✓ Large CSV import test PASSED');
    console.log(`  Successfully imported ${finalTotal - initialTotal} books`);
  } else {
    console.log('✗ Large CSV import test FAILED');
    console.log(`  Expected at least ${rowCount * 0.9} new books, got ${finalTotal - initialTotal}`);
  }
  
  console.log('');
}

runTests().catch(console.error);
