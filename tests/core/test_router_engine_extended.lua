-- tests/core/test_router_engine_extended.lua
local RouterEngine = require("core.router_engine")
local TCPInterface = require("interfaces.tcp_interface")
local RS485Interface = require("interfaces.rs485_interface")
local BLEInterface = require("interfaces.ble_interface")
local CustomInterface = require("interfaces.custom_interface")
local TCPProtocolAdapter = require("adapters.tcp_protocol_adapter")
local ModbusAdapter = require("adapters.modbus_adapter")
local MQTTAdapter = require("adapters.mqtt_adapter")
local CustomProtocolAdapter = require("adapters.custom_protocol_adapter")

local function test_subnet_match()
    print("\n[1] Testing subnet match functionality...")
    local router = RouterEngine.new()
    
    -- 测试CIDR子网匹配
    local test_cases = {
        { ip = "192.168.1.100", subnet = "192.168.1.0/24", expected = true },
        { ip = "192.168.2.100", subnet = "192.168.1.0/24", expected = false },
        { ip = "10.0.0.5", subnet = "10.0.0.0/8", expected = true },
        { ip = "172.16.0.1", subnet = "172.16.0.0/16", expected = true },
        { ip = "192.168.1.100", subnet = "0.0.0.0/0", expected = true }
    }
    
    for i, test_case in ipairs(test_cases) do
        local result = router:subnet_match(test_case.ip, test_case.subnet)
        if result == test_case.expected then
            print(string.format("Test %d: PASS - %s matches %s", i, test_case.ip, test_case.subnet))
        else
            print(string.format("Test %d: FAIL - %s should %s match %s", i, test_case.ip, test_case.expected and "" or "not", test_case.subnet))
        end
    end
end

local function test_routing_strategies()
    print("\n[2] Testing routing strategies...")
    local router = RouterEngine.new()
    
    -- 创建测试接口和适配器
    local tcp_interface = TCPInterface.new("tcp_test", { host = "localhost", port = 8888 })
    local tcp_adapter = TCPProtocolAdapter.new(tcp_interface)
    
    local rs485_interface = RS485Interface.new("rs485_test", { port = "/dev/ttyUSB0" })
    local rs485_adapter = ModbusAdapter.new(rs485_interface)
    
    -- 注册接口
    router:register_interface("tcp_test", tcp_interface, tcp_adapter)
    router:register_interface("rs485_test", rs485_interface, rs485_adapter)
    
    -- 添加路由规则
    router:add_routing_rule({
        name = "test_rule",
        device_id = "test_device",
        source_subnet = "192.168.1.0/24",
        target_subnet = "192.168.2.0/24",
        interfaces = {"tcp_test", "rs485_test"},
        priority = 100,
        enabled = true
    })
    
    -- 测试默认策略
    print("Testing default strategy...")
    router:set_routing_strategy("default")
    local interface1 = router:select_best_interface("test_device", "192.168.1.0/24", "192.168.2.0/24")
    print(string.format("Default strategy selected: %s", interface1 or "nil"))
    
    -- 测试基于质量的策略
    print("Testing quality-based strategy...")
    router:set_routing_strategy("quality_based")
    local interface2 = router:select_best_interface("test_device", "192.168.1.0/24", "192.168.2.0/24")
    print(string.format("Quality-based strategy selected: %s", interface2 or "nil"))
    
    -- 测试负载均衡策略
    print("Testing load-balanced strategy...")
    router:set_routing_strategy("load_balanced")
    local interface3 = router:select_best_interface("test_device", "192.168.1.0/24", "192.168.2.0/24")
    print(string.format("Load-balanced strategy selected: %s", interface3 or "nil"))
end

local function test_route_probing()
    print("\n[3] Testing route probing...")
    local router = RouterEngine.new()
    
    -- 创建测试接口和适配器
    local tcp_interface = TCPInterface.new("tcp_test", { host = "localhost", port = 8888 })
    local tcp_adapter = TCPProtocolAdapter.new(tcp_interface)
    
    -- 注册接口
    router:register_interface("tcp_test", tcp_interface, tcp_adapter)
    
    -- 测试路由探测
    local success, latency = router:probe_route("tcp_test", "test message")
    if type(latency) == "number" then
        print(string.format("Route probe result: success=%s, latency=%.1fms", tostring(success), latency))
    else
        print(string.format("Route probe result: success=%s, latency=%s", tostring(success), tostring(latency)))
    end
    
    -- 测试所有路由探测
    local results = router:probe_all_routes("test message")
    print("All routes probe results:")
    for interface_name, result in pairs(results) do
        if type(result.latency) == "number" then
            print(string.format("%s: success=%s, latency=%.1fms", interface_name, tostring(result.success), result.latency))
        else
            print(string.format("%s: success=%s, latency=%s", interface_name, tostring(result.success), tostring(result.latency)))
        end
    end
end

local function test_custom_strategy()
    print("\n[4] Testing custom routing strategy...")
    local router = RouterEngine.new()
    
    -- 创建自定义路由策略
    local custom_strategy = function(self, device_id, src_subnet, dst_subnet)
        print("Custom strategy called for device:", device_id)
        return "tcp_test" -- 总是选择tcp_test接口
    end
    
    -- 添加自定义策略
    router:add_custom_strategy("my_custom_strategy", custom_strategy)
    
    -- 设置使用自定义策略
    router:set_routing_strategy("my_custom_strategy")
    
    -- 创建测试接口和适配器
    local tcp_interface = TCPInterface.new("tcp_test", { host = "localhost", port = 8888 })
    local tcp_adapter = TCPProtocolAdapter.new(tcp_interface)
    
    -- 注册接口
    router:register_interface("tcp_test", tcp_interface, tcp_adapter)
    
    -- 测试自定义策略
    local interface = router:select_best_interface("test_device", "192.168.1.0/24", "192.168.2.0/24")
    print(string.format("Custom strategy selected: %s", interface or "nil"))
end

local function test_custom_interface()
    print("\n[5] Testing custom interface...")
    local router = RouterEngine.new()
    
    -- 创建自定义接口配置
    local custom_config = {
        protocol = "my_custom_protocol",
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
                return "CUSTOM:Hello from custom interface"
            end
        }
    }
    
    -- 创建自定义接口和适配器
    local custom_interface = CustomInterface.new("custom_test", custom_config)
    local custom_adapter = CustomProtocolAdapter.new(custom_interface, custom_config.protocol_config)
    
    -- 注册接口
    router:register_interface("custom_test", custom_interface, custom_adapter)
    
    -- 测试接口连接
    local connected = custom_interface:connect()
    print(string.format("Custom interface connected: %s", tostring(connected)))
    
    -- 测试发送消息
    local sent = custom_adapter:send_message("Test message")
    print(string.format("Custom adapter sent message: %s", tostring(sent)))
    
    -- 测试接收消息
    local received = custom_adapter:receive_message()
    print(string.format("Custom adapter received message: %s", received))
    
    -- 测试接口断开
    local disconnected = custom_interface:disconnect()
    print(string.format("Custom interface disconnected: %s", tostring(disconnected)))
end

-- 运行所有测试
print("=== Running Router Engine Extended Tests ===")
test_subnet_match()
test_routing_strategies()
test_route_probing()
test_custom_strategy()
test_custom_interface()
print("=== All Tests Completed ===")
