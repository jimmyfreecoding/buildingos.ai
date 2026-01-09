-- init-timescaledb.sql
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

--- 1. 环境与数值指标表 (对应 airsensor, airconditioning, smokesensor 等) ---
CREATE TABLE IF NOT EXISTS iot_sensor_metrics (
    ts            TIMESTAMPTZ NOT NULL,
    code          TEXT NOT NULL,
    category      TEXT NOT NULL,        -- 设备类型 (如: airsensor, watermeter)
    gateway       TEXT,
    campus        TEXT,                 -- 园区 (原 Topic 提取)
    building      TEXT,                 -- 楼栋
    floor         TEXT,                 -- 楼层
    area          TEXT,                 -- 区域
    metrics       JSONB NOT NULL,       -- 存储数值: {"temperature":23, "humidity":40}
    PRIMARY KEY (ts, code)
);

--- 2. 状态事件表 (对应 light, door, humensensor, pad 等) ---
CREATE TABLE IF NOT EXISTS iot_device_status (
    ts            TIMESTAMPTZ NOT NULL,
    code          TEXT NOT NULL,
    category      TEXT NOT NULL,
    status        TEXT NOT NULL,        -- 核心状态: on/off, busy/free
    online        SMALLINT DEFAULT 1,   -- 1:在线, 0:离线
    raw_status    JSONB,                -- 全量状态快照
    PRIMARY KEY (ts, code)
);

--- 3. 电量专用表 (维持之前的多回路设计) ---
CREATE TABLE IF NOT EXISTS iot_power_data (
    ts            TIMESTAMPTZ NOT NULL,
    code          TEXT NOT NULL,
    gateway       TEXT,
    total_power   NUMERIC(12,2),
    total_kwh     NUMERIC(12,2),
    details       JSONB,                -- 回路细节: {"current":{"loop1":0.5...}}
    PRIMARY KEY (ts, code)
);

--- 4. 转换为超表 (Hypertables) ---
SELECT create_hypertable('iot_sensor_metrics', 'ts', chunk_time_interval => INTERVAL '1 day', if_not_exists => TRUE);
SELECT create_hypertable('iot_device_status', 'ts', chunk_time_interval => INTERVAL '1 day', if_not_exists => TRUE);
SELECT create_hypertable('iot_power_data', 'ts', chunk_time_interval => INTERVAL '7 days', if_not_exists => TRUE);

--- 5. 开启高性能压缩策略 ---
-- 指标表按设备 code 压缩
ALTER TABLE iot_sensor_metrics SET (timescaledb.compress, timescaledb.compress_segmentby = 'code');
-- 状态表按设备 code 压缩
ALTER TABLE iot_device_status SET (timescaledb.compress, timescaledb.compress_segmentby = 'code');
-- 电量表建议按 code 压缩
ALTER TABLE iot_power_data SET (timescaledb.compress, timescaledb.compress_segmentby = 'code');

-- 自动执行压缩策略 (7天前的数据)
SELECT add_compression_policy('iot_sensor_metrics', INTERVAL '7 days');
SELECT add_compression_policy('iot_device_status', INTERVAL '7 days');
SELECT add_compression_policy('iot_power_data', INTERVAL '14 days');

--- 6. 创建查询优化索引 ---
CREATE INDEX IF NOT EXISTS idx_metrics_geo ON iot_sensor_metrics (campus, building, floor, ts DESC);
CREATE INDEX IF NOT EXISTS idx_status_category ON iot_device_status (category, ts DESC);