process.env.NODE_ENV = 'test';
// Keep timeouts reasonable for slower CI/DB.
jest.setTimeout(30000);

afterAll((done) => {
	try {
		// Each Jest test file has its own runtime/module registry.
		const { db } = require('./server');
		if (db && typeof db.end === 'function') {
			db.end(() => done());
			return;
		}
	} catch (_) {
		// ignore
	}
	done();
});
