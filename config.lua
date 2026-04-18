-- config.lua - Hybrid Routing Gateway Configuration

-- 日志配置
local config = {
    log = {
        level = "INFO",  -- DEBUG, INFO, WARN, ERROR
        file = "gateway.log",
        console = true
    },
    
    -- 接口配置
    interfaces = {
        -- TCP/IP 接口
        {
            name = "tcp_main",
            type = "tcp",
            host = "192.168.1.100",
            port = 8888,
            timeout = 10,
            enabled = true
        },
        {
            name = "tcp_secondary",
            type = "tcp",
            host = "192.168.1.101",
            port = 8889,
            timeout = 10,
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
        
        -- CAN 接口
        {
            name = "can_bus",
            type = "can",
            interface = "can0",
            bitrate = 500000,
            can_id = 0x001,
            enabled = false
        },
        
        -- BLE 接口
        {
            name = "ble_device",
            type = "ble",
            address = "00:1A:7D:DA:71:13",
            service_uuid = "0000180a-0000-1000-8000-00805f9b34fb",
            char_uuid = "00002a29-0000-1000-8000-00805f9b34fb",
            enabled = false
        }
    },
    
    -- 路由规则
    routing_rules = {
        {
            name = "rule_subnet1_to_subnet2",
            device_id = "device_001",
            source_subnet = "192.168.1.0/24",
            target_subnet = "192.168.2.0/24",
            interfaces = {"tcp_main", "rs485_sensor"},
            timeout = 5.0,
            retry_count = 3,
            priority = 100,
            enabled = true
        },
        {
            name = "rule_rs485_fallback",
            device_id = "device_002",
            source_subnet = "0.0.0.0/0",
            target_subnet = "0.0.0.0/0",
            interfaces = {"rs485_sensor", "tcp_main"},
            timeout = 10.0,
            retry_count = 2,
            priority = 50,
            enabled = true
        },
        {
            name = "rule_ble_primary",
            device_id = "device_003",
            source_subnet = "0.0.0.0/0",
            target_subnet = "0.0.0.0/0",
            interfaces = {"ble_device", "tcp_main"},
            timeout = 10.0,
            retry_count = 2,
            priority = 75,
            enabled = false
        }
    },
    
    -- 适配器配置
    adapters = {
        mqtt = {
            enabled = true,
            broker = "192.168.1.50",
            port = 1883,
            client_id = "hybrid_gateway_01"
        },
        tcp_protocol = {
            enabled = true,
            port = 9999,
            max_connections = 100
        },
        modbus = {
            enabled = true,
            slave_id = 1
        }
    },
    
    -- 探测配置
    probing = {
        enabled = true,
        interval = 10,  -- 秒
        timeout = 2.0,
        packet_size = 64
    }
}

return config
