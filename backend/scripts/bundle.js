// Post-build step for release packaging.
//
// The TypeScript compiler emits the server to `dist/server.js`, but the
// desktop app launcher (BackendService), StartBackend.bat, and the Inno
// Setup installer all run/bundle `backend/server.js` (repo root). This
// script copies the compiled output to that expected location so all the
// run paths line up. `server.js` is self-contained (it only requires
// node_modules), so a plain copy is sufficient.
const fs = require('fs');
const path = require('path');

const distServer = path.join(__dirname, '..', 'dist', 'server.js');
const rootServer = path.join(__dirname, '..', 'server.js');

if (!fs.existsSync(distServer)) {
  console.error('ERROR: dist/server.js not found. Run "npm run build" (tsc) first.');
  process.exit(1);
}

fs.copyFileSync(distServer, rootServer);

// Best-effort copy of the source map (harmless if missing at runtime).
try {
  fs.copyFileSync(
    path.join(__dirname, '..', 'dist', 'server.js.map'),
    path.join(__dirname, '..', 'server.js.map'),
  );
} catch (_) {
  // no sourcemap; ignore
}

console.log('Bundled dist/server.js -> backend/server.js');
