const bcrypt = require('bcrypt');
const hash = '$2b$10$pgExmZsdzG.BAVCyggSv1Oihl3HNBX64g6BEgSHHMwlUE1hSbcJ2m';
bcrypt.compare('admin', hash).then(match => console.log('Match:', match));