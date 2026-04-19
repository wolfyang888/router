# Daemon.lua 守护进程文档

## 概述

daemon.lua 是路由网关的守护进程，负责设备注册、组网、发现、心跳检测和报文转发功能。

## 启动流程

```
main()
  └── Daemon:new()           创建Daemon实例
        └── RouterEngine:new()  创建路由引擎
  └── Daemon:start()         启动服务
        ├── 检查 config.daemon.enabled
        ├── 创建 TCP 服务器 (uv.new_tcp)
        ├── 绑定端口 9000
        ├── 监听连接
        ├── start_heartbeat_monitor()  启动心跳监控协程
        └── start_message_processor()  启动消息处理协程
  └── Daemon:run()          运行事件循环
```

## 核心数据结构

```lua
self.clients = {
    [client_id] = {
        socket = tcp_socket,           -- TCP socket对象
        id = client_id,                -- 客户端唯一ID
        last_heartbeat = os.time(),   -- 最后心跳时间戳
        status = "connected",          -- 连接状态
        device_info = {               -- 注册的设备信息
            id = "device_001",
            interfaces = {...}
        },
        buffer = ""                    -- 接收数据缓冲区
    }
}

self.router = RouterEngine:new()       -- 路由引擎实例

self.message_queue = {}                -- 消息队列
```

## 消息类型

| 消息类型 | 方向 | 说明 |
|---------|------|------|
| register | 设备→daemon | 设备注册，将设备信息注册到RouterEngine |
| heartbeat | 设备→daemon | 心跳保活，更新last_heartbeat |
| forward | 设备→daemon | 消息转发，发送到目标设备 |
| discover | 设备→daemon | 设备发现，获取已注册设备列表 |

## 消息格式

### 1. 注册消息 (register)

**请求：**
```lua
{
    type = "register",
    device_info = {
        id = "device_001",
        interfaces = {
            { type = "tcp", address = "192.168.1.100", port = 8888 },
            { type = "rs485", address = "/dev/ttyUSB0" }
        }
    }
}
```

**响应：**
```lua
{
    type = "register_response",
    status = "success",
    device_id = "device_001"
}
```

### 2. 心跳消息 (heartbeat)

**请求：**
```lua
{
    type = "heartbeat",
    timestamp = 1713520000
}
```

**响应：**
```lua
{
    type = "heartbeat_response",
    timestamp = 1713520030
}
```

### 3. 转发消息 (forward)

**请求：**
```lua
{
    type = "forward",
    source_device = "device_001",
    target_device = "device_002",
    message = "Hello"
}
```

**响应：**
```lua
{
    type = "forward_response",
    status = "success",
    path = {"tcp_01", "tcp_02"}
}
```

### 4. 发现消息 (discover)

**请求：**
```lua
{
    type = "discover"
}
```

**响应：**
```lua
{
    type = "discover_response",
    devices = {
        { device_id = "device_001", interfaces = {...} },
        { device_id = "device_002", interfaces = {...} }
    }
}
```

## 客户端处理流程

```
客户端连接
  └── handle_new_client()
        ├── 生成 client_id (格式: client_时间戳_随机数)
        ├── 创建客户端记录
        ├── 发送 welcome 消息
        └── client:read_start() 开始异步读取数据

收到数据
  └── process_client_data()
        ├── 按 '\n' 分割数据
        └── handle_client_message() 处理每条消息

handle_client_message() 根据 type 分发:
  ├── "register"    → handle_device_register()  注册设备
  ├── "heartbeat"   → handle_heartbeat()        更新心跳
  ├── "forward"      → handle_message_forward()   转发消息
  └── "discover"     → handle_device_discover()  发现设备
```

## 后台协程

### 心跳监控 (start_heartbeat_monitor)

- **运行频率**：每 5 秒检查一次
- **检查逻辑**：如果 (当前时间 - last_heartbeat) > heartbeat_timeout，则断开连接
- **超时时间**：config.daemon.heartbeat_timeout (默认120秒)

```lua
function Daemon:start_heartbeat_monitor()
    local function heartbeat_monitor()
        while true do
            local current_time = os.time()
            for client_id, client_info in pairs(self.clients) do
                if current_time - client_info.last_heartbeat > config.daemon.heartbeat_timeout then
                    Error.warn(Error.HEARTBEAT_TIMEOUT, "client: %s", client_id)
                    self:disconnect_client(client_id)
                end
            end
            uv.sleep(5000)
        end
    end
    coroutine.create(heartbeat_monitor)
end
```

### 消息处理 (start_message_processor)

- **运行频率**：每 10 毫秒检查一次
- **处理逻辑**：从消息队列取出消息并处理

## 设备注销触发条件

1. **主动断开**：客户端关闭连接
2. **心跳超时**：超过 120 秒无心跳响应
3. **注销调用**：`self.router:unregister_device(device_id)`

## 配置项 (config.lua)

```lua
daemon = {
    port = 9000,                -- TCP监听端口
    max_connections = 50,       -- 最大连接数
    heartbeat_interval = 30,   -- 心跳发送间隔(秒)
    heartbeat_timeout = 120    -- 心跳超时断开(秒)
}
```

## 完整通信时序

```
设备                      Daemon                    RouterEngine
  │                         │                            │
  │──── TCP 连接 ──────────>│                            │
  │                         │                            │
  │──── register ─────────>│── register_device ───────->│
  │<── register_response ───│                            │
  │                         │                            │
  │──── heartbeat ─────────>│ (更新last_heartbeat)        │
  │<── heartbeat_response ──│                            │
  │                         │                            │
  │──── forward ──────────>│── forward_to_device ───────>│
  │<── forward_response ────│                            │
  │                         │                            │
  │──── discover ──────────>│── get_registered_devices ─>│
  │<── discover_response ───│                            │
  │                         │                            │
  │ (120秒无心跳)            │                            │
  │<──── 超时断开 ──────────│── unregister_device ───────>│
```

## 错误处理

| 错误类型 | 错误码 | 说明 |
|---------|--------|------|
| LIBUV_NOT_AVAILABLE | 3 | Libuv库不可用，使用模拟实现 |
| DAEMON_NOT_ENABLED | 4 | 守护进程未启用 |
| DAEMON_NOT_STARTED | 5 | 守护进程未启动 |
| SERVER_BIND_FAILED | 500 | 服务器绑定失败 |
| SERVER_START_FAILED | 501 | 服务器启动失败 |
| SERVER_ACCEPT_ERROR | 502 | 服务器接受连接错误 |
| CLIENT_NOT_CONNECTED | 503 | 客户端未连接 |
| CLIENT_DISCONNECTED | 504 | 客户端已断开 |
| CLIENT_SEND_FAILED | 505 | 客户端发送失败 |
| CLIENT_READ_ERROR | 506 | 客户端读取错误 |
| HEARTBEAT_TIMEOUT | 507 | 心跳超时 |
| DEVICE_INFO_MISSING | 303 | 设备信息缺失 |
| DEVICE_REGISTER_FAILED | 301 | 设备注册失败 |
| FORWARD_MESSAGE_INVALID | 404 | 转发消息无效 |
| NO_PATH_FOUND | 202 | 未找到可用路径 |
| UNKNOWN_MESSAGE_TYPE | 403 | 未知消息类型 |

## 依赖模块

| 模块 | 说明 |
|-----|------|
| config | 系统配置 |
| core.router_engine | 路由引擎 |
| platform | 跨平台支持，Libuv加载 |
| utils.error | 错误处理和日志 |

## 使用方法

```bash
# 启动守护进程
lua daemon.lua run

# 或直接运行
lua daemon.lua
```
