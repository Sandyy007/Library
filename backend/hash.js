const bcrypt = require('bcrypt');
bcrypt.hash('admin', 10).then(hash => console.log(hash));