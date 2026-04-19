# 配置文件详解

## 目录

- [system](#system-系统配置)
- [log](#log-日志配置)
- [interfaces](#interfaces-接口配置)
- [routing_rules](#routing_rules-路由规则配置)
- [adapters](#adapters-适配器配置)
- [link_metrics](#link_metrics-链路质量配置)
- [routing](#routing-路由策略配置)
- [daemon](#daemon-守护进程配置)

---

## system 系统配置

系统级基础配置。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `name` | string | "Router Gateway" | 系统名称 |
| `version` | string | "1.0.0" | 版本号 |
| `log_level` | string | "info" | 日志级别，可选：debug, info, warn, error |
| `max_concurrent_connections` | number | 100 | 最大并发连接数 |
| `default_timeout` | number | 5.0 | 默认超时时间（秒） |

---

## log 日志配置

日志文件输出配置。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `file` | string | "router.log" | 日志文件路径（相对于运行目录） |
| `enabled` | boolean | true | 是否启用文件日志 |

---

## interfaces 接口配置

系统支持的物理/虚拟接口列表。数组中每个元素代表一个接口实例。

### 通用字段

所有接口类型的通用字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | 接口唯一名称，在路由规则中引用 |
| `type` | string | 接口类型：tcp, rs485, ble, plc, custom |
| `enabled` | boolean | 是否启用该接口 |
| `timeout` | number | 操作超时时间（秒） |

### TCP 接口 (type = "tcp")

| 字段 | 类型 | 说明 |
|------|------|------|
| `host` | string | 服务器主机地址 |
| `port` | number | 服务器端口 |
| `subnet` | string | 接口所属子网，格式：IP/前缀长度 |

```lua
{
    name = "tcp_subnet1",
    type = "tcp",
    host = "192.168.1.100",
    port = 8888,
    timeout = 10,
    subnet = "192.168.1.0/24",
    enabled = true
}
```

### RS485 接口 (type = "rs485")

| 字段 | 类型 | 说明 |
|------|------|------|
| `port` | string | 串口设备路径，如 /dev/ttyUSB0 |
| `baudrate` | number | 波特率，常用值：9600, 19200, 115200 |
| `parity` | string | 校验位：N(无), E(偶), O(奇) |
| `stopbits` | number | 停止位：1 或 2 |
| `timeout` | number | 通信超时（秒） |

### BLE 接口 (type = "ble")

| 字段 | 类型 | 说明 |
|------|------|------|
| `address` | string | BLE 设备 MAC 地址 |
| `service_uuid` | string | 服务 UUID |
| `char_uuid` | string | 特征值 UUID |

### PLC 接口 (type = "plc")

| 字段 | 类型 | 说明 |
|------|------|------|
| `address` | string | PLC 地址 |
| `port` | number | 端口号 |
| `protocol` | string | 协议类型，如 "plc" |

### 自定义接口 (type = "custom")

| 字段 | 类型 | 说明 |
|------|------|------|
| `protocol` | string | 自定义协议名称 |
| `protocol_config` | table | 协议配置，包含 serializer 和 deserializer 函数 |

```lua
protocol_config = {
    serializer = function(message)
        return "CUSTOM:" .. tostring(message)
    end,
    deserializer = function(data)
        return data:sub(8)
    end
}
```

---

## routing_rules 路由规则配置

定义设备间的路由策略。数组中每条规则按 `priority` 从高到低排序。

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | 规则唯一名称 |
| `device_id` | string | 目标设备 ID |
| `source_subnet` | string | 源子网，0.0.0.0/0 表示任意 |
| `target_subnet` | string | 目标子网，0.0.0.0/0 表示任意 |
| `interfaces` | array | 接口列表，按顺序优先级查找 |
| `timeout` | number | 路由超时（秒） |
| `retry_count` | number | 最大重试次数 |
| `priority` | number | 规则优先级，数值越大优先级越高 |
| `enabled` | boolean | 是否启用该规则 |

### 接口选择逻辑

1. 按 `priority` 从高到低遍历所有匹配规则
2. 对于每条规则，按 `interfaces` 数组顺序查找第一个可用接口
3. 接口可用条件：已连接 且 链路质量 >= FAIR (0.5)

```lua
{
    name = "rule_tcp_subnet1",
    device_id = "device_001",
    source_subnet = "192.168.1.0/24",
    target_subnet = "192.168.2.0/24",
    interfaces = {"tcp_subnet1", "tcp_subnet2"},  -- tcp_subnet1 优先
    timeout = 10.0,
    retry_count = 2,
    priority = 100,
    enabled = true
}
```

**示例说明**：
- 当 device_001 需要访问 192.168.2.0/24 子网时
- 先尝试使用 `tcp_subnet1`
- 如果 `tcp_subnet1` 不可用，则尝试 `tcp_subnet2`

---

## adapters 适配器配置

外部协议适配器配置。

### MQTT 适配器 (mqtt)

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enabled` | boolean | false | 是否启用 |
| `broker` | string | - | MQTT broker 地址 |
| `client_id` | string | - | 客户端 ID |
| `username` | string | "" | 用户名 |
| `password` | string | "" | 密码 |
| `keepalive` | number | 60 | 保活间隔（秒） |
| `qos` | number | 1 | QoS 级别：0, 1, 2 |
| `retain` | boolean | false | 是否保留消息 |
| `topics` | array | - | 订阅主题列表 |

### Modbus 适配器 (modbus)

| 字段 | 类型 | 说明 |
|------|------|------|
| `port` | string | 串口路径 |
| `baudrate` | number | 波特率 |
| `parity` | string | 校验位 |
| `stopbits` | number | 停止位 |
| `timeout` | number | 超时时间 |

### 自定义协议适配器 (custom_protocol)

| 字段 | 类型 | 说明 |
|------|------|------|
| `protocol` | string | 协议名称 |
| `config` | table | 协议特定配置 |

---

## link_metrics 链路质量配置

链路质量评估参数。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `sample_window` | number | 100 | 采样窗口大小 |
| `timeout_threshold` | number | 5.0 | 超时阈值（秒） |
| `error_weight` | number | 50 | 错误权重 (0-100) |
| `latency_weight` | number | 50 | 延迟权重 (0-100) |
| `quality_thresholds.excellent` | number | 0.9 | 优秀阈值 |
| `quality_thresholds.good` | number | 0.7 | 良好阈值 |
| `quality_thresholds.fair` | number | 0.5 | 一般阈值 |
| `quality_thresholds.poor` | number | 0.3 | 较差阈值 |

### 质量等级

| 等级 | 阈值 | 说明 |
|------|------|------|
| excellent | >= 0.9 | 优秀 |
| good | >= 0.7 | 良好 |
| fair | >= 0.5 | 一般 |
| poor | >= 0.3 | 较差 |
| bad | < 0.3 | 不可用 |

### 质量计算公式

```
quality = 1 - (error_rate * error_weight + latency_penalty * latency_weight) / 100
```

---

## routing 路由策略配置

全局路由策略设置。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `default_strategy` | string | "default" | 默认策略：default, quality_based, load_balanced |
| `quality_threshold` | number | 0.5 | 质量阈值，低于此值不使用该路由 |
| `max_hops` | number | 5 | 最大跳数 |
| `probe_interval` | number | 10 | 路由探测间隔（秒） |
| `probe_timeout` | number | 2.0 | 探测超时（秒） |

### 路由策略类型

| 策略 | 说明 |
|------|------|
| `default` | 按规则顺序选择第一个可用接口 |
| `quality_based` | 选择质量最好的接口 |
| `load_balanced` | 负载均衡模式 |

---

## daemon 守护进程配置

本地守护进程配置，用于系统管理和监控。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `port` | number | 9000 | 守护进程监听端口 |
| `max_connections` | number | 50 | 最大连接数 |
| `heartbeat_interval` | number | 30 | 心跳间隔（秒） |
| `device_timeout` | number | 120 | 设备超时时间（秒） |
| `log_level` | string | "info" | 日志级别 |

---

## 配置示例

```lua
local config = {
    system = {
        name = "Router Gateway",
        version = "1.0.0",
        log_level = "info",
        max_concurrent_connections = 100,
        default_timeout = 5.0
    },

    log = {
        file = "router.log",
        enabled = true
    },

    interfaces = {
        {
            name = "tcp_primary",
            type = "tcp",
            host = "192.168.1.100",
            port = 8888,
            timeout = 10,
            subnet = "192.168.1.0/24",
            enabled = true
        },
        {
            name = "tcp_backup",
            type = "tcp",
            host = "192.168.1.101",
            port = 8888,
            timeout = 10,
            subnet = "192.168.1.0/24",
            enabled = true
        }
    },

    routing_rules = {
        {
            name = "primary_rule",
            device_id = "device_001",
            source_subnet = "192.168.1.0/24",
            target_subnet = "192.168.2.0/24",
            interfaces = {"tcp_primary", "tcp_backup"},
            timeout = 10.0,
            retry_count = 2,
            priority = 100,
            enabled = true
        }
    },

    routing = {
        default_strategy = "default",
        quality_threshold = 0.5,
        max_hops = 5,
        probe_interval = 10,
        probe_timeout = 2.0
    },

    daemon = {
        port = 9000,
        max_connections = 50,
        heartbeat_interval = 30,
        device_timeout = 120,
        log_level = "info"
    }
}
```