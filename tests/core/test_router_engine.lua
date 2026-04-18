-- tests/core/test_router_engine.lua
local RouterEngine = require("core.router_engine")
local TCPInterface = require("interfaces.tcp_interface")
local MQTTAdapter = require("adapters.mqtt_adapter")

print("================================================")
print("  Router Engine Test Suite")
print("================================================\n")

-- 创建路由引擎实例
local engine = RouterEngine.new()
print("[1] RouterEngine instance created ✓\n")

-- 测试 2: 接口注册
print("[2] Testing interface registration...")
local tcp_interface = TCPInterface.new("tcp_test", {
    host = "localhost",
    port = 9999,
    timeout = 5
})
local mqtt_adapter = MQTTAdapter.new(tcp_interface, "localhost", "test_client")

engine:register_interface("tcp_test", tcp_interface, mqtt_adapter)
assert(engine.interfaces["tcp_test"] ~= nil, "Interface not registered")
assert(engine.adapters["tcp_test"] ~= nil, "Adapter not registered")
assert(engine.metrics["tcp_test"] ~= nil, "Metrics not registered")
print("✓ Interface registered successfully\n")

-- 测试 3: 路由规则添加
print("[3] Testing routing rule addition...")
local rule = {
    name = "test_rule",
    device_id = "device_001",
    source_subnet = "192.168.1.0/24",
    target_subnet = "192.168.2.0/24",
    interfaces = {"tcp_test"},
    priority = 100,
    enabled = true
}

engine:add_routing_rule(rule)
assert(#engine.rules == 1, "Rule not added")
assert(engine.rules[1].name == "test_rule", "Rule name mismatch")
print("✓ Routing rule added successfully\n")

-- 测试 4: 子网匹配
print("[4] Testing subnet matching...")
local match = engine:subnet_match("192.168.1.100", "192.168.1.0/24")
assert(match == true, "Subnet should match")

local no_match = engine:subnet_match("192.168.2.100", "192.168.1.0/24")
assert(no_match == false, "Subnet should not match")

local wildcard_match = engine:subnet_match("10.0.0.1", "0.0.0.0/0")
assert(wildcard_match == true, "Wildcard should match")
print("✓ Subnet matching works correctly\n")

-- 测试 5: 路由状态获取
print("[5] Testing routing status retrieval...")
local status = engine:get_routing_status()
assert(status.interfaces ~= nil, "Interfaces status missing")
assert(status.active_routes ~= nil, "Active routes missing")
assert(status.rules ~= nil, "Rules missing")
print("✓ Routing status retrieved successfully\n")

print("================================================")
print("  All tests passed! ✅")
print("================================================")
