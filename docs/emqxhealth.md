# EMQX MQTT Broker Diagnostic Guide

## 1. 快速健康检查 (Quick Health Check)
**环境**: Docker (`buildingos-emqx-prod`)
**Dashboard端口**: 18083

### 1.1 容器状态
```bash
docker ps --filter "name=emqx"
```
*检查 `STATUS` 是否为 `Up (healthy)`。如果是 `unhealthy`，请查看日志。*

### 1.2 HTTP 探针 (最轻量级)
无需认证，快速检查服务是否存活：
```powershell
curl.exe http://localhost:18083/status
```
*预期输出: `Node ... is started`, `emqx is running`*

---

## 2. CLI 诊断 (容器内部)
需要进入容器执行。如果节点负载极高，这些命令可能会超时。

**进入容器:**
```bash
docker exec -it buildingos-emqx-prod sh
```

**核心指令:**
```bash
# 检查节点运行状态
emqx ctl status

# 查看监听端口 (1883, 8083 等)
emqx ctl listeners

# 查看当前连接的客户端列表 (慎用，客户端多时会刷屏)
emqx ctl clients list --limit 10

# 查看插件/功能状态
emqx ctl broker
```

---

## 3. API 诊断 (外部调用)
使用 EMQX V5 HTTP API 获取详细监控数据。
**默认认证**: `admin` / `emqx_prod_2024` (或 `public`)

> **注意 (Windows PowerShell 用户):**
> 1. 必须使用 `curl.exe` 而不是 `curl` (后者是 Invoke-WebRequest 的别名)。
> 2. 没有 `json_pp` 工具，请使用 `| ConvertFrom-Json | ConvertTo-Json` 格式化输出。

### 3.1 获取节点详情 (Nodes)
检查内存、CPU、Erlang 进程数等关键指标。
```powershell
curl.exe -s -u "admin:emqx_prod_2024" http://localhost:18083/api/v5/nodes | ConvertFrom-Json | ConvertTo-Json
```

### 3.2 获取核心统计 (Stats)
包含连接数(connections)、会话数(sessions)、订阅数(subscriptions)等。
```powershell
curl.exe -s -u "admin:emqx_prod_2024" http://localhost:18083/api/v5/stats | ConvertFrom-Json | ConvertTo-Json
```

### 3.3 获取吞吐指标 (Metrics)
包含收发字节数、消息丢弃数(dropped)等。
```powershell
curl.exe -s -u "admin:emqx_prod_2024" http://localhost:18083/api/v5/metrics | ConvertFrom-Json | ConvertTo-Json
```

### 3.4 诊断客户端连接
查找特定客户端 (例如 ID 为 `mqttx_xxx`):
```powershell
curl.exe -s -u "admin:emqx_prod_2024" http://localhost:18083/api/v5/clients/mqttx_xxx | ConvertFrom-Json | ConvertTo-Json
```

---

## 4. 常见问题排查 (Troubleshooting)

### 4.1 "Node not responding to pings"
**现象**: 执行 `emqx ctl` 报错，容器状态可能为 `unhealthy`。
**原因**:
1. Erlang 虚拟机负载过高，无法响应控制命令。
2. 节点名称 (Node Name) 配置不匹配。
**排查**:
1. 检查日志: `docker logs buildingos-emqx-prod --tail 100`
2. 检查宿主机资源 (CPU/内存) 是否耗尽。
3. 尝试重启容器: `docker restart buildingos-emqx-prod`

### 4.2 API 返回 "BAD_API_KEY_OR_SECRET"
**原因**: Dashboard 密码错误。
**解决**:
如果忘记密码，可以在容器内重置 admin 密码 (需要节点处于运行状态):
```bash
docker exec buildingos-emqx-prod emqx ctl admins passwd admin <new_password>
```
*注意：如果 `emqx ctl` 也无法执行（提示 Node not responding），可能是因为 Cookie 不匹配或节点过载。这种情况下，如果你不介意丢失数据（会话、保留消息等），可以尝试重置数据卷：*
```bash
docker stop buildingos-emqx-prod
docker rm buildingos-emqx-prod
docker volume rm buildingos_prod_emqx_data
# 然后重新部署容器
```

### 4.3 客户端频繁断连 (Client Flapping)
**现象**: 日志中出现大量 `unexpected_info` 或 `socket_error`。
**排查**:
1. 检查 API `/api/v5/clients/{clientid}` 查看该客户端的 `connected_at` 时间。
2. 检查网络延迟或防火墙设置。
3. 检查是否有相同的 ClientID 在不同位置重复登录 (会导致互踢)。
