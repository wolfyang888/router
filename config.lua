-- config.lua
-- 系统配置文件

local config = {
    -- 系统配置
    system = {
        name = "Router Gateway",
        version = "1.0.0",
        log_level = "info",
        max_concurrent_connections = 100,
        default_timeout = 5.0
    },

    -- 接口配置
    interfaces = {
        -- TCP/IP 接口（子网1）
        {
            name = "tcp_subnet1",
            type = "tcp",
            host = "192.168.1.100",
            port = 8888,
            timeout = 10,
            subnet = "192.168.1.0/24",
            enabled = true
        },

        -- TCP/IP 接口（子网2）
        {
            name = "tcp_subnet2",
            type = "tcp",
            host = "192.168.2.100",
            port = 8889,
            timeout = 10,
            subnet = "192.168.2.0/24",
            enabled = true
        },

        -- TCP/IP 接口（子网3）
        {
            name = "tcp_subnet3",
            type = "tcp",
            host = "192.168.3.100",
            port = 8890,
            timeout = 10,
            subnet = "192.168.3.0/24",
            enabled = false
        },

        -- RS485 接口
        {
            name = "rs485_sensor",
            type = "rs485",
            port = "/dev/ttyUSB0",
            baudrate = 9600,
            parity = "N",
            stopbits = 1,
            timeout = 1.0,
            enabled = true
        },

        -- BLE 接口
        {
            name = "ble_device",
            type = "ble",
            address = "00:1A:7D:DA:71:13",
            service_uuid = "0000180a-0000-1000-8000-00805f9b34fb",
            char_uuid = "00002a29-0000-1000-8000-00805f9b34fb",
            enabled = false
        },

        -- 自定义接口
        {
            name = "custom_interface",
            type = "custom",
            protocol = "my_custom_protocol",
            enabled = false,
            protocol_config = {
                serializer = function(message)
                    return "CUSTOM:" .. tostring(message)
                end,
                deserializer = function(data)
                    return data:sub(8) -- 去掉 "CUSTOM:" 前缀
                end
            },
            handler = {
                connect = function(self)
                    print("Custom interface connected")
                    return true
                end,
                disconnect = function(self)
                    print("Custom interface disconnected")
                    return true
                end,
                send = function(self, data, timeout)
                    print("Custom interface sending:       " .. data)
                    return true
                end,
                receive = function(self, timeout)
                    -- 模拟接收数据
                    return "Hello from custom interface"
                end
            }
        },

        -- PLC 接口
        {
            name = "plc_device",
            type = "plc",
            address = "localhost",
            port = 8888,
            protocol = "plc",
            timeout = 5,
            enabled = true,
            handler = {
                connect = function(self)
                    print("PLC interface connected")
                    return true
                end,
                disconnect = function(self)
                    print("PLC interface disconnected")
                    return true
                end,
                send = function(self, data, timeout)
                    print("PLC interface sending:         " .. data)
                    return true
                end,
                receive = function(self, timeout)
                    -- 模拟接收数据
                    return "Hello from PLC interface"
                end
            }
        }
    },

    -- 路由规则配置
    routing_rules = {
        {
            name = "rule_tcp_subnet1",
            device_id = "device_001",
            source_subnet = "192.168.1.0/24",
            target_subnet = "192.168.2.0/24",
            interfaces = {"tcp_subnet1", "tcp_subnet2"},
            timeout = 10.0,
            retry_count = 2,
            priority = 100,
            enabled = true
        },
        {
            name = "rule_rs485_fallback",
            device_id = "device_003",
            source_subnet = "0.0.0.0/0",
            target_subnet = "0.0.0.0/0",
            interfaces = {"rs485_sensor", "tcp_subnet1"},
            timeout = 10.0,
            retry_count = 2,
            priority = 50,
            enabled = true
        },
        {
            name = "rule_custom_interface",
            device_id = "device_004",
            source_subnet = "0.0.0.0/0",
            target_subnet = "0.0.0.0/0",
            interfaces = {"custom_interface", "tcp_subnet1"},
            timeout = 10.0,
            retry_count = 2,
            priority = 75,
            enabled = false
        },
        {
            name = "rule_plc",
            device_id = "device_005",
            source_subnet = "0.0.0.0/0",
            target_subnet = "0.0.0.0/0",
            interfaces = {"plc_device", "tcp_subnet1"},
            timeout = 10.0,
            retry_count = 2,
            priority = 80,
            enabled = true
        }
    },

    -- 适配器配置
    adapters = {
        mqtt = {
            enabled = true,
            broker = "mqtt://test.mosquitto.org",
            client_id = "router_gateway",
            username = "",
            password = "",
            keepalive = 60,
            qos = 1,
            retain = false,
            topics = {
                "sensors/#",
                "devices/#"
            }
        },
        modbus = {
            enabled = false,
            port = "/dev/ttyUSB0",
            baudrate = 9600,
            parity = "N",
            stopbits = 1,
            timeout = 1.0
        },
        custom_protocol = {
            enabled = false,
            protocol = "my_custom_protocol",
            config = {
                key = "value"
            }
        }
    },

    -- 链路质量配置
    link_metrics = {
        sample_window = 100,  -- 采样窗口大小
        timeout_threshold = 5.0,  -- 超时阈值（秒）
        error_weight = 50,  -- 错误权重（0-100）
        latency_weight = 50,  -- 延迟权重（0-100）
        quality_thresholds = {
            excellent = 0.9,  -- 优秀
            good = 0.7,       -- 良好
            fair = 0.5,       -- 一般
            poor = 0.3        -- 较差
        }
    },

    -- 路由策略配置
    routing = {
        default_strategy = "default",  -- default, quality_based, load_balanced
        quality_threshold = 0.5,  -- 质量阈值
        max_hops = 5,  -- 最大跳数
        probe_interval = 10,  -- 路由探测间隔（秒）
        probe_timeout = 2.0   -- 探测超时（秒）
    },

    -- 守护进程配置
    daemon = {
        port = 9000,  -- 守护进程端口
        max_connections = 50,  -- 最大连接数
        heartbeat_interval = 30,  -- 心跳间隔（秒）
        device_timeout = 120,  -- 设备超时（秒）
        log_level = "info"
    }
}

return config