
const http = require('http');

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/api/books',
  method: 'GET'
};

console.log('Sending request to http://localhost:3000/api/books');

const req = http.request(options, (res) => {
  console.log(`Status Code: ${res.statusCode}`);
  let data = '';
  
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    try {
      const parsed = JSON.parse(data);
      console.log('✅ Books API Response:');
      console.log(parsed);
    } catch (e) {
      console.log('Response (raw):', data.substring(0, 500));
    }
    process.exit(0);
  });
});

req.on('error', (error) => {
  console.error('❌ Request error:', error.message);
  process.exit(1);
});

req.end();
