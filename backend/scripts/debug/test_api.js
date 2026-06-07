const http = require('http');

http.get('http://localhost:3000/api/members', (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log('Members response:');
    console.log(JSON.stringify(JSON.parse(data), null, 2));
  });
}).on('error', (e) => {
  console.error(`Error: ${e.message}`);
});

http.get('http://localhost:3000/api/issues', (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log('\nIssues response:');
    console.log(JSON.stringify(JSON.parse(data), null, 2));
  });
}).on('error', (e) => {
  console.error(`Error: ${e.message}`);
});

http.get('http://localhost:3000/api/reports/issued', (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log('\nIssued Reports response:');
    console.log(JSON.stringify(JSON.parse(data), null, 2));
  });
}).on('error', (e) => {
  console.error(`Error: ${e.message}`);
});

http.get('http://localhost:3000/api/reports/overdue', (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    console.log('\nOverdue Reports response:');
    console.log(JSON.stringify(JSON.parse(data), null, 2));
  });
}).on('error', (e) => {
  console.error(`Error: ${e.message}`);
});
