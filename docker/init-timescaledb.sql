-- init-timescaledb.sql
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;


-- ==========================================
-- New TSH Tables (Migrated from User Script)
-- ==========================================

--- 空气传感器超级表
CREATE TABLE IF NOT EXISTS tsh_airsensor (
  ts timestamptz NOT NULL,
  pm25 int,
  pm10 int,
  tvoc int,
  co2 int,
  formaldehyde float,
  noise float,
  temperature float,
  humidity float,
  light int,
  nh3 int,
  so2 float,
  o3 float,
  o2 float,
  h2s int,
  ch4 int,
  co int,
  no2 float,
  h2 int,
  odor float,
  position VARCHAR(200),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20),
  device_code VARCHAR(100),
  device_id int,
  factory VARCHAR(50),
  model VARCHAR(50)
);
SELECT create_hypertable('tsh_airsensor', 'ts', chunk_time_interval => INTERVAL '30 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_airsensor ON tsh_airsensor (space, floor_area, floor, area, device_code, ts DESC);

--- 人体传感器超级表
CREATE TABLE IF NOT EXISTS tsh_humensensor (
  ts timestamptz NOT NULL,
  status int,
  position VARCHAR(200),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20),
  device_code VARCHAR(100),
  device_id int,
  factory VARCHAR(50),
  model VARCHAR(50)
);
SELECT create_hypertable('tsh_humensensor', 'ts', chunk_time_interval => INTERVAL '10 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_humensensor ON tsh_humensensor (space, floor_area, floor, area, device_code, ts DESC);

--- AI摄像头超级表-人密算法
CREATE TABLE IF NOT EXISTS tsh_aicamerasensor_densitycount (
  ts timestamptz NOT NULL,
  people_count int,
  img_url VARCHAR(500),
  video_url VARCHAR(500),
  position VARCHAR(200),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20),
  device_code VARCHAR(100),
  device_id int,
  factory VARCHAR(50),
  model VARCHAR(50)
);
SELECT create_hypertable('tsh_aicamerasensor_densitycount', 'ts', chunk_time_interval => INTERVAL '1 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_aicamerasensor_densitycount ON tsh_aicamerasensor_densitycount (space, floor_area, floor, area, device_code, ts DESC);

--- AI摄像头超级表-人员流量算法
CREATE TABLE IF NOT EXISTS tsh_aicamerasensor_crosscount (
  ts timestamptz NOT NULL,
  cross_entry int,
  cross_exit int,
  img_url VARCHAR(500),
  video_url VARCHAR(500),
  position VARCHAR(200),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20),
  device_code VARCHAR(100),
  device_id int,
  factory VARCHAR(50),
  model VARCHAR(50)
);
SELECT create_hypertable('tsh_aicamerasensor_crosscount', 'ts', chunk_time_interval => INTERVAL '1 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_aicamerasensor_crosscount ON tsh_aicamerasensor_crosscount (space, floor_area, floor, area, device_code, ts DESC);

--- AI摄像头超级表-抽烟检测算法
CREATE TABLE IF NOT EXISTS tsh_aicamerasensor_smokingcall (
  ts timestamptz NOT NULL,
  smoking int,
  img_url VARCHAR(500),
  video_url VARCHAR(500),
  position VARCHAR(200),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20),
  device_code VARCHAR(100),
  device_id int,
  factory VARCHAR(50),
  model VARCHAR(50)
);
SELECT create_hypertable('tsh_aicamerasensor_smokingcall', 'ts', chunk_time_interval => INTERVAL '1 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_aicamerasensor_smokingcall ON tsh_aicamerasensor_smokingcall (space, floor_area, floor, area, device_code, ts DESC);

--- AI摄像头超级表-黑名单检测算法
CREATE TABLE IF NOT EXISTS tsh_aicamerasensor_face_recognition (
  ts timestamptz NOT NULL,
  people_name VARCHAR(50),
  img_url VARCHAR(500),
  position VARCHAR(200),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20),
  device_code VARCHAR(100),
  device_id int,
  factory VARCHAR(50),
  model VARCHAR(50)
);
SELECT create_hypertable('tsh_aicamerasensor_face_recognition', 'ts', chunk_time_interval => INTERVAL '1 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_aicamerasensor_face_recognition ON tsh_aicamerasensor_face_recognition (space, floor_area, floor, area, device_code, ts DESC);

--- 烟雾传感器超级表
CREATE TABLE IF NOT EXISTS tsh_smokesensor (
  ts timestamptz NOT NULL,
  smoke int,
  position VARCHAR(200),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20),
  device_code VARCHAR(100),
  device_id int,
  factory VARCHAR(50),
  model VARCHAR(50)
);
SELECT create_hypertable('tsh_smokesensor', 'ts', chunk_time_interval => INTERVAL '30 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_smokesensor ON tsh_smokesensor (space, floor_area, floor, area, device_code, ts DESC);

--- 电量传感器分路电量超级表
CREATE TABLE IF NOT EXISTS tsh_powersensor_loop (
  ts timestamptz NOT NULL,
  current float,
  power float,
  kwh float,
  type VARCHAR(20),
  loop VARCHAR(20),
  loop_code VARCHAR(20),
  loop_name VARCHAR(50),
  position VARCHAR(200),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20),
  device_code VARCHAR(100),
  device_id int,
  factory VARCHAR(50),
  model VARCHAR(50)
);
SELECT create_hypertable('tsh_powersensor_loop', 'ts', chunk_time_interval => INTERVAL '30 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_powersensor_loop ON tsh_powersensor_loop (space, floor_area, floor, area, device_code, ts DESC);

--- 电量传感器超级表
CREATE TABLE IF NOT EXISTS tsh_powersensor (
  ts timestamptz NOT NULL,
  voltage1 float,
  voltage2 float,
  voltage3 float,
  current1 float,
  current2 float,
  current3 float,
  current4 float,
  current5 float,
  current6 float,
  current7 float,
  current8 float,
  current9 float,
  current10 float,
  current11 float,
  current12 float,
  current13 float,
  current14 float,
  current15 float,
  current16 float,
  current17 float,
  current18 float,
  current19 float,
  current20 float,
  current21 float,
  current22 float,
  current23 float,
  current24 float,
  current25 float,
  current26 float,
  current27 float,
  power1 float,
  power2 float,
  power3 float,
  power4 float,
  power5 float,
  power6 float,
  power7 float,
  power8 float,
  power9 float,
  power10 float,
  power11 float,
  power12 float,
  power13 float,
  power14 float,
  power15 float,
  power16 float,
  power17 float,
  power18 float,
  power19 float,
  power20 float,
  power21 float,
  power22 float,
  power23 float,
  power24 float,
  power25 float,
  power26 float,
  power27 float,
  kwh1 float,
  kwh2 float,
  kwh3 float,
  kwh4 float,
  kwh5 float,
  kwh6 float,
  kwh7 float,
  kwh8 float,
  kwh9 float,
  kwh10 float,
  kwh11 float,
  kwh12 float,
  kwh13 float,
  kwh14 float,
  kwh15 float,
  kwh16 float,
  kwh17 float,
  kwh18 float,
  kwh19 float,
  kwh20 float,
  kwh21 float,
  kwh22 float,
  kwh23 float,
  kwh24 float,
  kwh25 float,
  kwh26 float,
  kwh27 float,
  total_power float,
  total_kwh float,
  position VARCHAR(200),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20),
  device_code VARCHAR(100),
  device_id int,
  factory VARCHAR(50),
  model VARCHAR(50)
);
SELECT create_hypertable('tsh_powersensor', 'ts', chunk_time_interval => INTERVAL '30 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_powersensor ON tsh_powersensor (space, floor_area, floor, area, device_code, ts DESC);

--- 厕位传感器超级表
CREATE TABLE IF NOT EXISTS tsh_wcsensor (
  ts timestamptz NOT NULL,
  status int,
  position VARCHAR(200),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20),
  device_code VARCHAR(100),
  device_id int,
  factory VARCHAR(50),
  model VARCHAR(50)
);
SELECT create_hypertable('tsh_wcsensor', 'ts', chunk_time_interval => INTERVAL '30 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_wcsensor ON tsh_wcsensor (space, floor_area, floor, area, device_code, ts DESC);

--- 告警数据超级表
CREATE TABLE IF NOT EXISTS tsh_systemalarm (
  ts timestamptz NOT NULL,
  type VARCHAR(5),
  type_name VARCHAR(200),
  device_address VARCHAR(200),
  alarm_code VARCHAR(200),
  alarm_msg VARCHAR(500),
  base_unit VARCHAR(200),
  base_value VARCHAR(200),
  real_value VARCHAR(200),
  position VARCHAR(200),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20),
  device_code VARCHAR(100),
  device_id int,
  factory VARCHAR(50),
  model VARCHAR(50)
);
SELECT create_hypertable('tsh_systemalarm', 'ts', chunk_time_interval => INTERVAL '30 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_systemalarm ON tsh_systemalarm (space, floor_area, floor, area, device_code, ts DESC);

--- 门牌状态超级表
CREATE TABLE IF NOT EXISTS tsh_pad (
  ts timestamptz NOT NULL,
  status int,
  position VARCHAR(200),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20),
  device_code VARCHAR(100),
  device_id int,
  factory VARCHAR(50),
  model VARCHAR(50)
);
SELECT create_hypertable('tsh_pad', 'ts', chunk_time_interval => INTERVAL '30 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_pad ON tsh_pad (space, floor_area, floor, area, device_code, ts DESC);

--- 通行日志超级表
CREATE TABLE IF NOT EXISTS tsh_door_pass_log (
  ts timestamptz NOT NULL,
  platform VARCHAR(20),
  person_name VARCHAR(50),
  person_id VARCHAR(50),
  person_type VARCHAR(10),
  person_phone VARCHAR(20),
  person_email VARCHAR(50),
  person_emp_no VARCHAR(50),
  service_id VARCHAR(50),
  service_name VARCHAR(50),
  door_id VARCHAR(50),
  door_name VARCHAR(255),
  pass_type VARCHAR(10),
  pass_direction VARCHAR(10),
  face_url VARCHAR(300),
  card_num VARCHAR(20),
  space VARCHAR(20)
);
SELECT create_hypertable('tsh_door_pass_log', 'ts', chunk_time_interval => INTERVAL '30 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_door_pass_log ON tsh_door_pass_log (space, ts DESC);

--- 物联网操作日志超级表
CREATE TABLE IF NOT EXISTS tsh_iot_control_log (
  ts timestamptz NOT NULL,
  source_type VARCHAR(20),
  source_name VARCHAR(255),
  user_id VARCHAR(50),
  user_emp_no VARCHAR(20),
  user_name VARCHAR(50),
  device_type VARCHAR(20),
  action_topic VARCHAR(500),
  action_data VARCHAR(500),
  space VARCHAR(20),
  floor_area VARCHAR(20),
  floor VARCHAR(20),
  area VARCHAR(20)
);
SELECT create_hypertable('tsh_iot_control_log', 'ts', chunk_time_interval => INTERVAL '30 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_iot_control_log ON tsh_iot_control_log (space, floor_area, floor, area, ts DESC);

--- 电梯运行数据超级表
CREATE TABLE IF NOT EXISTS tsh_elevator (
  ts timestamptz NOT NULL,
  elevator_id int,
  garden_id int,
  name VARCHAR(255),
  num VARCHAR(255),
  create_time VARCHAR(30),
  create_date VARCHAR(30),
  type VARCHAR(2),
  status int,
  fully_loaded int,
  door int,
  communicate int,
  overhaul int,
  fault int,
  fire_fighting int,
  earthquake_control int,
  fire int,
  emergency_power_supply int,
  lock_ladder int,
  low_speed_standby int,
  del_status int,
  floor int,
  floor_name VARCHAR(30),
  is_push int,
  dev_type int,
  space VARCHAR(20)
);
SELECT create_hypertable('tsh_elevator', 'ts', chunk_time_interval => INTERVAL '30 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_elevator ON tsh_elevator (space, ts DESC);

--- 室外温度超级表
CREATE TABLE IF NOT EXISTS tsh_weather (
  ts timestamptz NOT NULL,
  pm25 int,
  wind float,
  humidity int,
  temperature float,
  weather VARCHAR(50),
  aiq int,
  space VARCHAR(20)
);
SELECT create_hypertable('tsh_weather', 'ts', chunk_time_interval => INTERVAL '30 day', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_tsh_weather ON tsh_weather (space, ts DESC);


-- ==========================================
-- Compression Policies for TSH Tables
-- ==========================================

-- tsh_airsensor
ALTER TABLE tsh_airsensor SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_code');
SELECT add_compression_policy('tsh_airsensor', INTERVAL '30 days');

-- tsh_humensensor
ALTER TABLE tsh_humensensor SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_code');
SELECT add_compression_policy('tsh_humensensor', INTERVAL '11 days');

-- tsh_aicamerasensor_densitycount
ALTER TABLE tsh_aicamerasensor_densitycount SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_code');
SELECT add_compression_policy('tsh_aicamerasensor_densitycount', INTERVAL '7 days');

-- tsh_aicamerasensor_crosscount
ALTER TABLE tsh_aicamerasensor_crosscount SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_code');
SELECT add_compression_policy('tsh_aicamerasensor_crosscount', INTERVAL '7 days');

-- tsh_aicamerasensor_smokingcall
ALTER TABLE tsh_aicamerasensor_smokingcall SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_code');
SELECT add_compression_policy('tsh_aicamerasensor_smokingcall', INTERVAL '7 days');

-- tsh_aicamerasensor_face_recognition
ALTER TABLE tsh_aicamerasensor_face_recognition SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_code');
SELECT add_compression_policy('tsh_aicamerasensor_face_recognition', INTERVAL '7 days');

-- tsh_smokesensor
ALTER TABLE tsh_smokesensor SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_code');
SELECT add_compression_policy('tsh_smokesensor', INTERVAL '31 days');

-- tsh_powersensor_loop
ALTER TABLE tsh_powersensor_loop SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_code');
SELECT add_compression_policy('tsh_powersensor_loop', INTERVAL '31 days');

-- tsh_powersensor
ALTER TABLE tsh_powersensor SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_code');
SELECT add_compression_policy('tsh_powersensor', INTERVAL '31 days');

-- tsh_wcsensor
ALTER TABLE tsh_wcsensor SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_code');
SELECT add_compression_policy('tsh_wcsensor', INTERVAL '31 days');

-- tsh_systemalarm
ALTER TABLE tsh_systemalarm SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_code');
SELECT add_compression_policy('tsh_systemalarm', INTERVAL '31 days');

-- tsh_pad
ALTER TABLE tsh_pad SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_code');
SELECT add_compression_policy('tsh_pad', INTERVAL '31 days');

-- tsh_door_pass_log (Segment by door_id)
ALTER TABLE tsh_door_pass_log SET (timescaledb.compress, timescaledb.compress_segmentby = 'door_id');
SELECT add_compression_policy('tsh_door_pass_log', INTERVAL '31 days');

-- tsh_iot_control_log (Segment by device_type, space)
ALTER TABLE tsh_iot_control_log SET (timescaledb.compress, timescaledb.compress_segmentby = 'device_type');
SELECT add_compression_policy('tsh_iot_control_log', INTERVAL '31 days');

-- tsh_elevator (Segment by elevator_id)
ALTER TABLE tsh_elevator SET (timescaledb.compress, timescaledb.compress_segmentby = 'elevator_id');
SELECT add_compression_policy('tsh_elevator', INTERVAL '31 days');

-- tsh_weather (Segment by space)
ALTER TABLE tsh_weather SET (timescaledb.compress, timescaledb.compress_segmentby = 'space');
SELECT add_compression_policy('tsh_weather', INTERVAL '31 days');
