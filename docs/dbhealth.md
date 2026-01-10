# Database Health Report & Diagnostic Guide

## 1. 最近一次健康检查快照 (Snapshot)
**时间**: 2026-01-09
**环境**: Production (Docker: `buildingos-postgres-prod`)

| 核心指标 | 状态值 | 评价 |
| :--- | :--- | :--- |
| **数据库总大小** | **2.2 GB** | 正常增长 |
| **缓存命中率** | **98.81%** | 🌟 **极佳** (大部分读取在内存中完成) |
| **索引使用率** | **> 99%** | 🌟 **极佳** (几乎无全表扫描) |
| **平均写入耗时** | **~1 ms** | 🚀 **极快** |
| **连接池状态** | **13 总连接 / 0 等待** | ✅ **健康** (无积压，无长事务) |

---

## 2. 常用诊断查询指令 (Core Diagnostics)

你可以通过 Docker 直接执行这些命令，或者进入容器内的 `psql` 终端执行。

**进入容器终端:**
```bash
docker exec -it buildingos-postgres-prod psql -U buildingos -d buildingos
```

### 2.1 基础概览
**查看数据库大小:**
```sql
SELECT pg_size_pretty(pg_database_size('buildingos')) as db_size;
```

**查看缓存命中率 (Cache Hit Ratio):**
*目标: > 99%*
```sql
SELECT 
  sum(heap_blks_read) as disk_read, 
  sum(heap_blks_hit) as buffer_hit, 
  round(cast(sum(heap_blks_hit) as numeric) / (sum(heap_blks_hit) + sum(heap_blks_read)) * 100, 2) as cache_hit_ratio 
FROM pg_statio_user_tables;
```

### 2.2 存储与表分析
**Top 10 大表排名 (按磁盘占用):**
```sql
SELECT 
  relname as table_name, 
  pg_size_pretty(pg_total_relation_size(relid)) as total_size 
FROM pg_catalog.pg_statio_user_tables 
ORDER BY pg_total_relation_size(relid) DESC 
LIMIT 10;
```

**Top 10 数据量(行数)最大的表:**
*注意：使用统计值估算 (n_live_tup)，在大表上比 count(*) 快得多*
```sql
SELECT 
  relname as table_name, 
  n_live_tup as row_count_estimate,
  pg_size_pretty(pg_total_relation_size(relid)) as total_size
FROM pg_stat_user_tables 
ORDER BY n_live_tup DESC 
LIMIT 10;
```

**TimescaleDB 超表状态 (含压缩情况):**
```sql
SELECT 
  h.hypertable_name, 
  pg_size_pretty((hypertable_detailed_size(format('%I.%I', h.hypertable_schema, h.hypertable_name)::regclass)).total_bytes) as total_size, 
  h.num_chunks, 
  h.compression_enabled 
FROM timescaledb_information.hypertables h;
```

### 2.3 性能分析
**索引使用率检查:**
*用于发现缺失索引的表 (seq_scan 高且 idx_scan_pct 低)*
```sql
SELECT 
  relname, 
  seq_scan, 
  idx_scan, 
  round(cast(idx_scan as numeric) / (seq_scan + idx_scan + 1) * 100, 2) as idx_scan_pct 
FROM pg_stat_user_tables 
WHERE seq_scan + idx_scan > 1000 
ORDER BY idx_scan_pct ASC 
LIMIT 10;
```

**Top 5 慢查询/高频查询:**
*需要开启 `pg_stat_statements` 插件*
```sql
SELECT 
  round(total_exec_time::numeric, 2) as total_ms, 
  calls, 
  round(mean_exec_time::numeric, 2) as avg_ms, 
  substring(query, 1, 80) as query 
FROM pg_stat_statements 
ORDER BY total_exec_time DESC 
LIMIT 5;
```

### 2.4 连接与并发
**连接池状态监控:**
*重点关注 `idle in transaction` (应为 0) 和 `waiting` 状态*
```sql
SELECT 
  count(*) as total_conns, 
  sum(case when state = 'active' then 1 else 0 end) as active_conns, 
  sum(case when state = 'idle' then 1 else 0 end) as idle_conns, 
  sum(case when state = 'idle in transaction' then 1 else 0 end) as idle_in_trans,
  round(cast(max(extract(epoch from now() - query_start)) as numeric), 2) as max_duration_sec
FROM pg_stat_activity 
WHERE datname = 'buildingos';
```

---

## 3. 进阶故障排查 (Advanced Troubleshooting)

### 3.1 查找被锁阻塞的查询 (Blocking Queries)
当应用响应变慢时，检查是否有锁等待：
```sql
SELECT 
    pid, 
    usename, 
    pg_blocking_pids(pid) as blocked_by, 
    query as blocked_query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
```

### 3.2 正在运行的长查询 (Running Long Queries)
查找运行超过 1 秒的活跃查询：
```sql
SELECT 
  pid, 
  now() - query_start as duration, 
  query, 
  state 
FROM pg_stat_activity 
WHERE state = 'active' 
  AND (now() - query_start) > interval '1 second';
```

### 3.3 检查死元组与自动清理 (Dead Tuples & Autovacuum)
如果表膨胀过大，可能是 autovacuum 没跟上：
```sql
SELECT 
  relname, 
  n_live_tup, 
  n_dead_tup, 
  last_autovacuum, 
  autovacuum_count 
FROM pg_stat_user_tables 
ORDER BY n_dead_tup DESC 
LIMIT 10;
```

### 3.4 终止特定连接 (Kill Connection)
紧急情况下终止卡住的进程 (替换 `<pid>`):
```sql
SELECT pg_terminate_backend(<pid>);
```

---

## 4. 维护指令 (Maintenance)

**重置统计信息 (Reset Stats):**
*在进行重大性能优化前后，可以重置计数器以便观察效果*
```sql
SELECT pg_stat_statements_reset();
```

**手动触发清理 (Manual Vacuum):**
*通常不需要手动执行，除非出现严重膨胀*
```sql
VACUUM (VERBOSE, ANALYZE) table_name;
```
