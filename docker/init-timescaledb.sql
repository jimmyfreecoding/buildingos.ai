-- init-timescaledb.sql
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;


-- 1. 环境指标表 (空调温度、空气质量等数值)
CREATE TABLE iot_sensor_metrics (
    ts            TIMESTAMPTZ NOT NULL,
    code          TEXT NOT NULL,
    category      TEXT NOT NULL,     -- airsensor / airconditioning
    gateway       TEXT,
    location_path TEXT,              -- 从 Topic 提取的路径: HGH-WC/A3/31F/C
    metrics       JSONB              -- 存储数值型: {"temp": 23.3, "humidity": 39.7, "pm25": 7}
);
SELECT create_hypertable('iot_sensor_metrics', 'ts', chunk_time_interval => INTERVAL '1 day');

-- 2. 状态事件表 (照明、开关、人体传感器状态)
CREATE TABLE iot_device_status (
    ts            TIMESTAMPTZ NOT NULL,
    code          TEXT NOT NULL,
    category      TEXT NOT NULL,     -- light / humensensor / airconditioning
    status        TEXT NOT NULL,     -- on/off, free/occupied
    online        SMALLINT,
    raw_status    JSONB              -- 存储原始状态 JSON
);
SELECT create_hypertable('iot_device_status', 'ts', chunk_time_interval => INTERVAL '1 day');

-- 3. 电量专用表 (针对多回路的特殊设计)
CREATE TABLE iot_power_data (
    ts            TIMESTAMPTZ NOT NULL,
    code          TEXT NOT NULL,
    gateway       TEXT,
    total_power   NUMERIC(12,2),
    total_kwh     NUMERIC(12,2),
    details       JSONB              -- 存储具体回路: {"voltage":{...}, "current":{...}, "power":{...}}
);
SELECT create_hypertable('iot_power_data', 'ts', chunk_time_interval => INTERVAL '7 days');

-- 4. 开启压缩策略 (生产环境必备)
ALTER TABLE iot_sensor_metrics SET (timescaledb.compress, timescaledb.compress_segmentby = 'code');
ALTER TABLE iot_device_status SET (timescaledb.compress, timescaledb.compress_segmentby = 'code');
SELECT add_compression_policy('iot_sensor_metrics', INTERVAL '7 days');
SELECT add_compression_policy('iot_device_status', INTERVAL '7 days');