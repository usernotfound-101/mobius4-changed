// mobius 4 version number: 0.1.0

// load environment variables from .env
require('dotenv').config();

function deepMerge(target, source) {
    const output = { ...target };

    Object.keys(source).forEach((key) => {
        const sourceValue = source[key];
        const targetValue = output[key];

        if (
            sourceValue &&
            typeof sourceValue === 'object' &&
            !Array.isArray(sourceValue) &&
            targetValue &&
            typeof targetValue === 'object' &&
            !Array.isArray(targetValue)
        ) {
            output[key] = deepMerge(targetValue, sourceValue);
        } else {
            output[key] = sourceValue;
        }
    });

    return output;
}

function parseInteger(value, variableName) {
    const parsed = Number.parseInt(value, 10);
    if (Number.isNaN(parsed)) {
        console.warn(`[mobius4] ignoring ${variableName}: expected integer, got "${value}"`);
        return undefined;
    }
    return parsed;
}

function parsePoaList(value) {
    if (!value) {
        return undefined;
    }

    const trimmed = value.trim();
    if (!trimmed) {
        return undefined;
    }

    if (trimmed.startsWith('[')) {
        try {
            const parsed = JSON.parse(trimmed);
            if (Array.isArray(parsed)) {
                return parsed;
            }
            console.warn('[mobius4] ignoring CSE_POA: JSON value is not an array');
            return undefined;
        } catch (err) {
            console.warn(`[mobius4] ignoring CSE_POA: invalid JSON (${err.message})`);
            return undefined;
        }
    }

    const poaList = trimmed
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean);

    return poaList.length ? poaList : undefined;
}

function readEnv(...names) {
    for (const name of names) {
        const value = process.env[name];
        if (value !== undefined && value !== null && String(value).trim() !== '') {
            return String(value).trim();
        }
    }
    return undefined;
}

function applyRuntimeEnvOverrides() {
    const overrides = {};
    let hasOverrides = false;

    const setOverride = (path, value) => {
        if (value === undefined) {
            return;
        }

        hasOverrides = true;
        let cursor = overrides;
        for (let i = 0; i < path.length - 1; i += 1) {
            const key = path[i];
            if (!cursor[key] || typeof cursor[key] !== 'object' || Array.isArray(cursor[key])) {
                cursor[key] = {};
            }
            cursor = cursor[key];
        }
        cursor[path[path.length - 1]] = value;
    };

    const cseTypeRaw = readEnv('CSE_TYPE');
    setOverride(['cse', 'cse_type'], cseTypeRaw ? parseInteger(cseTypeRaw, 'CSE_TYPE') : undefined);
    setOverride(['cse', 'cse_id'], readEnv('CSE_ID', 'MOBIUS_CSE_ID'));
    setOverride(['cse', 'csebase_rn'], readEnv('CSE_BASE_RN', 'MOBIUS_BASE_RN'));
    setOverride(['cse', 'admin'], readEnv('CSE_ADMIN', 'MOBIUS_ADMIN'));

    const poaRaw = readEnv('CSE_POA');
    setOverride(['cse', 'poa'], poaRaw ? parsePoaList(poaRaw) : undefined);

    setOverride(['cse', 'registrar', 'ip'], readEnv('REGISTRAR_IP', 'REGISTRAR_HOST'));
    const registrarPortRaw = readEnv('REGISTRAR_PORT');
    setOverride(
        ['cse', 'registrar', 'port'],
        registrarPortRaw ? parseInteger(registrarPortRaw, 'REGISTRAR_PORT') : undefined
    );
    setOverride(['cse', 'registrar', 'cse_id'], readEnv('REGISTRAR_CSE_ID'));
    setOverride(['cse', 'registrar', 'csebase_rn'], readEnv('REGISTRAR_BASE_RN'));

    const httpPortRaw = readEnv('HTTP_PORT', 'MOBIUS_CONTAINER_HTTP_PORT');
    setOverride(['http', 'port'], httpPortRaw ? parseInteger(httpPortRaw, 'HTTP_PORT') : undefined);
    const httpsPortRaw = readEnv('HTTPS_PORT', 'MOBIUS_CONTAINER_HTTPS_PORT');
    setOverride(['https', 'port'], httpsPortRaw ? parseInteger(httpsPortRaw, 'HTTPS_PORT') : undefined);

    setOverride(['mqtt', 'ip'], readEnv('MQTT_IP', 'MQTT_HOST'));
    const mqttPortRaw = readEnv('MQTT_PORT', 'MQTT_BROKER_PORT');
    setOverride(['mqtt', 'port'], mqttPortRaw ? parseInteger(mqttPortRaw, 'MQTT_PORT') : undefined);

    setOverride(['db', 'host'], readEnv('DB_HOST', 'MOBIUS_DB_HOST'));
    setOverride(['db', 'name'], readEnv('DB_NAME', 'MOBIUS_DB_NAME'));
    setOverride(['db', 'user'], readEnv('DB_USER', 'MOBIUS_DB_USER'));
    setOverride(['db', 'pw'], readEnv('DB_PASSWORD', 'MOBIUS_DB_PASSWORD'));
    const dbPortRaw = readEnv('DB_PORT', 'MOBIUS_DB_PORT');
    setOverride(['db', 'port'], dbPortRaw ? parseInteger(dbPortRaw, 'DB_PORT') : undefined);

    if (!hasOverrides) {
        return;
    }

    let existing = {};
    if (process.env.NODE_CONFIG) {
        try {
            existing = JSON.parse(process.env.NODE_CONFIG);
        } catch (err) {
            console.warn(`[mobius4] ignoring invalid NODE_CONFIG JSON (${err.message})`);
        }
    }

    process.env.NODE_CONFIG = JSON.stringify(deepMerge(existing, overrides));
}

applyRuntimeEnvOverrides();

const config = require('config');
const logger = require('./logger');
const db = require('./db/init');
const mqtt = require('./bindings/mqtt');

let cleanupIntervalId;

function fatalAndExit(message, err) {
    logger.fatal({ err }, message);

    // pino transport can be async; also print to stderr so startup failures are always visible.
    const details = err && err.message ? `: ${err.message}` : '';
    console.error(`[mobius4] ${message}${details}`);

    try {
        if (typeof logger.flush === 'function') {
            logger.flush();
        }
    } catch (_) {
        // Best effort only.
    }

    process.exit(1);
}

async function main() {
    logger.info('mobius4 starting up');

    // db connect
    try {
        await db.init_db();
    } catch (err) {
        fatalAndExit('database initialization failed, shutting down', err);
    }

    // start http server
    require('./bindings/http');

    // start mqtt client
    await mqtt.init_client();

    // start CSE registration if this is MN-CSE or ASN-CSE
    const cseType = Number(config.cse.cse_type);
    if (cseType === 2 || cseType === 3) {
        const { registree } = require('./cse/registree');
        registree();
    }

    // start expired resource cleanup
    const { expired_resource_cleanup } = require('./cse/hostingCSE');
    const cleanupIntervalMs = config.cse.expired_resource_cleanup_interval_days * 24 * 60 * 60 * 1000;
    cleanupIntervalId = setInterval(expired_resource_cleanup, cleanupIntervalMs);
    logger.info({ intervalDays: config.cse.expired_resource_cleanup_interval_days }, 'expired resource cleanup scheduled');
}

main()
    .then(() => {
        if (process.send) process.send('ready'); // PM2 wait_ready 연동
    })
    .catch((err) => {
        fatalAndExit('unhandled startup error', err);
    });

// graceful shutdown
async function shutdown(signal) {
    logger.info({ signal }, 'shutdown initiated');

    const timeout = setTimeout(() => {
        logger.fatal('forced shutdown after timeout');
        process.exit(1);
    }, 30000);

    try {
        // 1. 인터벌 정지 (새 작업 스케줄링 차단)
        if (cleanupIntervalId) clearInterval(cleanupIntervalId);
        require('./cse/datasetManager').shutdown();

        // 2. HTTP 서버 종료 — 새 연결 차단 + keep-alive 커넥션 즉시 해제
        const { server, https_server } = require('./bindings/http');
        await new Promise((resolve) => { server.close(resolve); server.closeAllConnections(); });
        await new Promise((resolve) => { https_server.close(resolve); https_server.closeAllConnections(); });

        // 3. MQTT 연결 해제
        await mqtt.disconnect();

        // 4. DB 커넥션 종료
        const sequelize = require('./db/sequelize');
        await sequelize.close();
        const pool = require('./db/connection');
        await pool.end();

        clearTimeout(timeout);
        logger.info('shutdown complete');
        process.exit(0);
    } catch (err) {
        logger.error({ err }, 'error during shutdown');
        process.exit(1);
    }
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
