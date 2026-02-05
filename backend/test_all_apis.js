const http = require('http');

// Helper function to make HTTP requests
function makeRequest(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json'
      },
      timeout: 5000
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, data: data });
        }
      });
    });

    req.on('error', (e) => reject(e));
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function runTests() {
  console.log('====================================');
  console.log('  API Test Suite');
  console.log('====================================\n');

  try {
    // Test 1: Login
    console.log('1. Testing Login Endpoint...');
    const loginRes = await makeRequest('POST', '/api/auth/login', {
      username: 'admin',
      password: 'Library#123'
    });
    
    if (loginRes.status === 200 && loginRes.data.token) {
      console.log('✓ Login successful');
      console.log(`  Token: ${loginRes.data.token.substring(0, 20)}...`);
      var token = loginRes.data.token;
    } else {
      console.log('✗ Login failed:', loginRes.status, loginRes.data);
      process.exit(1);
    }

    // Test 2: Get Books (paginated response)
    console.log('\n2. Testing GET /api/books...');
    const booksRes = await makeRequest('GET', '/api/books', null, token);
    const booksData = booksRes.data.data || booksRes.data;
    if (booksRes.status === 200 && Array.isArray(booksData)) {
      console.log(`✓ Books retrieved: ${booksData.length} books (page ${booksRes.data.pagination?.page || 1})`);
      booksData.slice(0, 5).forEach((book, i) => {
        console.log(`  ${i + 1}. ${book.title} by ${book.author}`);
      });
      if (booksData.length > 5) console.log(`  ... and ${booksData.length - 5} more`);
    } else {
      console.log('✗ Get books failed:', booksRes.status);
    }

    // Test 3: Get Members (paginated response)
    console.log('\n3. Testing GET /api/members...');
    const membersRes = await makeRequest('GET', '/api/members', null, token);
    const membersData = membersRes.data.data || membersRes.data;
    if (membersRes.status === 200 && Array.isArray(membersData)) {
      console.log(`✓ Members retrieved: ${membersData.length} members`);
      membersData.forEach((member, i) => {
        console.log(`  ${i + 1}. ${member.name} (${member.email})`);
      });
    } else {
      console.log('✗ Get members failed:', membersRes.status);
    }

    // Test 4: Get Issues (paginated response)
    console.log('\n4. Testing GET /api/issues...');
    const issuesRes = await makeRequest('GET', '/api/issues', null, token);
    const issuesData = issuesRes.data.data || issuesRes.data;
    if (issuesRes.status === 200 && Array.isArray(issuesData)) {
      console.log(`✓ Issues retrieved: ${issuesData.length} issues`);
      issuesData.forEach((issue, i) => {
        console.log(`  ${i + 1}. ${issue.member_name} - ${issue.title}`);
      });
    } else {
      console.log('✗ Get issues failed:', issuesRes.status);
    }

    // Test 5: Get Dashboard Stats
    console.log('\n5. Testing GET /api/dashboard/stats...');
    const statsRes = await makeRequest('GET', '/api/dashboard/stats', null, token);
    if (statsRes.status === 200) {
      console.log('✓ Dashboard stats retrieved:');
      console.log('  ', JSON.stringify(statsRes.data, null, 2));
    } else {
      console.log('✗ Get stats failed:', statsRes.status);
    }

    // Test 6: Get Issued Reports
    console.log('\n6. Testing GET /api/reports/issued...');
    const issuedRes = await makeRequest('GET', '/api/reports/issued', null, token);
    if (issuedRes.status === 200 && Array.isArray(issuedRes.data)) {
      console.log(`✓ Issued reports retrieved: ${issuedRes.data.length} records`);
    } else {
      console.log('✗ Get issued reports failed:', issuedRes.status);
    }

    // Test 7: Get Overdue Reports
    console.log('\n7. Testing GET /api/reports/overdue...');
    const overdueRes = await makeRequest('GET', '/api/reports/overdue', null, token);
    if (overdueRes.status === 200 && Array.isArray(overdueRes.data)) {
      console.log(`✓ Overdue reports retrieved: ${overdueRes.data.length} records`);
    } else {
      console.log('✗ Get overdue reports failed:', overdueRes.status);
    }

    console.log('\n====================================');
    console.log('  All tests completed!');
    console.log('====================================\n');

  } catch (error) {
    console.error('\n✗ Test failed with error:', error?.message || error);
    if (error?.stack) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

runTests();
