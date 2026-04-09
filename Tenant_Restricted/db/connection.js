const { Pool } = require('pg');
const config = require('config');

// Create PostgreSQL connection pool
const pool = new Pool({
    user: config.get('db.user'),
    host: config.get('db.host'),
    database: config.get('db.name'),
    password: config.get('db.pw'),
    port: config.get('db.port'),
    connectionTimeoutMillis: config.has('db.connect_timeout_ms') ? config.get('db.connect_timeout_ms') : 10000,
    idleTimeoutMillis: config.has('db.idle_timeout_ms') ? config.get('db.idle_timeout_ms') : 30000,
});

module.exports = pool;