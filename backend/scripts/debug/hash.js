const bcrypt = require('bcrypt');
// Hash for Library#123 password
bcrypt.hash('Library#123', 10).then(hash => console.log(hash));