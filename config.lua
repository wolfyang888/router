local config = {
    log = {
        level = "INFO",  -- DEBUG, INFO, WARN, ERROR
        file = "gateway.log",
        console = true
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
                    print("Custom interface sending:", data)
                    return true
                end,
                receive = function(self, timeout)
                    -- 模拟接收数据
                    return "CUSTOM:Hello from custom interface"
                end
            }
        }
    },
    
    -- 路由规则
    routing_rules = {
        {
            name = "rule_subnet1_to_subnet2",
            device_id = "device_001",
            source_subnet = "192.168.1.0/24",
            target_subnet = "192.168.2.0/24",
            interfaces = {"tcp_subnet1", "tcp_subnet2", "rs485_sensor"},
            timeout = 5.0,
            retry_count = 3,
            priority = 100,
            enabled = true
        },
        {
            name = "rule_subnet2_to_subnet3",
            device_id = "device_002",
            source_subnet = "192.168.2.0/24",
            target_subnet = "192.168.3.0/24",
            interfaces = {"tcp_subnet2", "tcp_subnet3", "ble_device"},
            timeout = 5.0,
            retry_count = 3,
            priority = 90,
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