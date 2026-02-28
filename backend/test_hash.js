const bcrypt = require('bcrypt');
// Test hash verification for Library#123
const hash = '$2b$10$8ESTtromiUQPTQgcCUrEWOUIzjru2P5lYDRDK.WgHuNOAIJ4vFkJu';
bcrypt.compare('Library#123', hash).then(match => console.log('Match:', match));