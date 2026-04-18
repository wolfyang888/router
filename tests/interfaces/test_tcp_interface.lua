-- tests/interfaces/test_tcp_interface.lua
local TCPInterface = require("interfaces.tcp_interface")

print("================================================")
print("  TCP Interface Test Suite")
print("================================================\n")

-- 测试 1: TCP 接口创建
print("[1] Testing TCP interface creation...")
local interface = TCPInterface.new("tcp_test", {
    host = "127.0.0.1",
    port = 9999,
    timeout = 5
})

assert(interface ~= nil, "Failed to create TCP interface")
assert(interface.name == "tcp_test", "Interface name mismatch")
assert(interface.type == "tcp", "Interface type should be TCP")
assert(interface.status == "disconnected", "Initial status should be disconnected")
print("✓ TCP interface created successfully\n")

-- 测试 2: 获取状态
print("[2] Testing get_status method...")
local status = interface:get_status()
assert(status.name == "tcp_test", "Status name mismatch")
assert(status.type == "tcp", "Status type mismatch")
assert(status.status == "disconnected", "Status should be disconnected")
print("✓ get_status returns correct information\n")

-- 测试 3: 测试配置
print("[3] Testing configuration parameters...")
assert(interface.config.host == "127.0.0.1", "Host config mismatch")
assert(interface.config.port == 9999, "Port config mismatch")
assert(interface.config.timeout == 5, "Timeout config mismatch")
print("✓ Configuration parameters correct\n")

-- 测试 4: 错误处理
print("[4] Testing error handling...")
local bad_interface = TCPInterface.new("bad_tcp", {
    host = "invalid.host.nonexistent",
    port = 99999,
    timeout = 1
})

-- 尝试连接到无效地址（应该失败但不会崩溃）
bad_interface:connect()
assert(bad_interface.status == "error" or bad_interface.status == "disconnected", 
    "Should handle connection errors gracefully")
print("✓ Error handling works correctly\n")

print("================================================")
print("  All tests passed! ✅")
print("================================================")
