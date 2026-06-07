// Simple API Testing Script
const http = require('http');

const tests = [];
let passedTests = 0;
let failedTests = 0;

function makeRequest(method, path, body = null) {
    return new Promise((resolve) => {
        const options = {
            hostname: 'localhost',
            port: 3000,
            path: `/api${path}`,
            method: method,
            headers: {
                'Content-Type': 'application/json'
            }
        };

        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
                resolve({ status: res.statusCode, data, headers: res.headers });
            });
        });

        req.on('error', (err) => {
            resolve({ status: 0, error: err.message });
        });

        if (body) {
            req.write(JSON.stringify(body));
        }
        req.end();
    });
}

function logTest(name, status, code, message) {
    if (status === 'PASS') {
        console.log(`✅ PASS | ${name}`);
        console.log(`   Status: ${code} | ${message}`);
        passedTests++;
    } else {
        console.log(`❌ FAIL | ${name}`);
        console.log(`   Error: ${message}`);
        failedTests++;
    }
}

async function runTests() {
    console.log('\n' + '='.repeat(70));
    console.log('Library Management System - API Testing Report');
    console.log('='.repeat(70) + '\n');

    // Test 1: Books API
    console.log('[1] BOOKS API TESTS');
    console.log('-'.repeat(70));
    
    let result = await makeRequest('GET', '/books');
    if (result.status === 200) {
        const books = JSON.parse(result.data);
        logTest('Get All Books', 'PASS', result.status, `Retrieved ${Array.isArray(books) ? books.length : 0} books`);
    } else {
        logTest('Get All Books', 'FAIL', result.status, result.error || 'Status: ' + result.status);
    }

    // Test 2: Members API
    console.log('\n[2] MEMBERS API TESTS');
    console.log('-'.repeat(70));
    
    result = await makeRequest('GET', '/members');
    if (result.status === 200) {
        const members = JSON.parse(result.data);
        logTest('Get All Members', 'PASS', result.status, `Retrieved ${Array.isArray(members) ? members.length : 0} members`);
    } else {
        logTest('Get All Members', 'FAIL', result.status, result.error || 'Status: ' + result.status);
    }

    // Test 3: Issues API
    console.log('\n[3] ISSUES API TESTS');
    console.log('-'.repeat(70));
    
    result = await makeRequest('GET', '/issues');
    if (result.status === 200) {
        const issues = JSON.parse(result.data);
        logTest('Get All Issues', 'PASS', result.status, `Retrieved ${Array.isArray(issues) ? issues.length : 0} issues`);
    } else {
        logTest('Get All Issues', 'FAIL', result.status, result.error || 'Status: ' + result.status);
    }

    // Test 4: Create Book
    console.log('\n[4] CREATE BOOK TEST');
    console.log('-'.repeat(70));
    
    const newBook = {
        isbn: `ISBN-${Date.now()}`,
        title: `Test Book ${new Date().getTime()}`,
        author: 'Test Author',
        category: 'Fiction',
        publisher: 'Test Publisher',
        yearPublished: 2024,
        totalCopies: 5
    };
    
    result = await makeRequest('POST', '/books', newBook);
    if (result.status === 201 || result.status === 200) {
        const book = JSON.parse(result.data);
        logTest('Create Book', 'PASS', result.status, `Created book with ID: ${book.id || book.insertId || 'unknown'}`);
    } else {
        logTest('Create Book', 'FAIL', result.status, result.error || 'Status: ' + result.status);
    }

    // Test 5: Create Member
    console.log('\n[5] CREATE MEMBER TEST');
    console.log('-'.repeat(70));
    
    const newMember = {
        name: `Test Member ${Date.now()}`,
        email: `test${Date.now()}@example.com`,
        phone: `9${Math.floor(Math.random() * 9000000000 + 1000000000)}`,
        memberType: 'student',
        membershipDate: new Date().toISOString().split('T')[0],
        expiryDate: new Date(Date.now() + 365*24*60*60*1000).toISOString().split('T')[0]
    };
    
    result = await makeRequest('POST', '/members', newMember);
    if (result.status === 201 || result.status === 200) {
        const member = JSON.parse(result.data);
        logTest('Create Member', 'PASS', result.status, `Created member with ID: ${member.id || member.insertId || 'unknown'}`);
    } else {
        logTest('Create Member', 'FAIL', result.status, result.error || 'Status: ' + result.status);
    }

    // Test 6: Search Books
    console.log('\n[6] SEARCH & FILTER TESTS');
    console.log('-'.repeat(70));
    
    result = await makeRequest('GET', '/books?category=Fiction');
    if (result.status === 200) {
        const books = JSON.parse(result.data);
        logTest('Search by Category', 'PASS', result.status, `Found ${Array.isArray(books) ? books.length : 0} Fiction books`);
    } else {
        logTest('Search by Category', 'FAIL', result.status, result.error || 'Status: ' + result.status);
    }

    result = await makeRequest('GET', '/members?status=active');
    if (result.status === 200) {
        const members = JSON.parse(result.data);
        logTest('Filter Active Members', 'PASS', result.status, `Found ${Array.isArray(members) ? members.length : 0} active members`);
    } else {
        logTest('Filter Active Members', 'FAIL', result.status, result.error || 'Status: ' + result.status);
    }

    // Summary
    console.log('\n' + '='.repeat(70));
    console.log('TEST SUMMARY');
    console.log('='.repeat(70));
    const total = passedTests + failedTests;
    const successRate = total > 0 ? ((passedTests / total) * 100).toFixed(2) : 0;
    console.log(`\nTotal Tests: ${total}`);
    console.log(`Passed: ${passedTests} ✅`);
    console.log(`Failed: ${failedTests} ❌`);
    console.log(`Success Rate: ${successRate}%\n`);

    if (failedTests === 0) {
        console.log('✅ ALL TESTS PASSED!\n');
    } else {
        console.log('⚠️  SOME TESTS FAILED - CHECK ABOVE\n');
    }

    process.exit(failedTests === 0 ? 0 : 1);
}

runTests().catch(console.error);
