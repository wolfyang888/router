-- test_plc_interface.lua
-- 测试PLC接口功能

require("platform")
local PLCInterface = require("interfaces.plc_interface")

print("================================================")
print("  PLC Interface Test Suite")
print("================================================\n")

-- 测试 1: 接口创建
print("[1] Testing PLC interface creation...")
local config = {
    address = "localhost",
    port = 8888,
    protocol = "plc",
    timeout = 5
}

local plc_interface = PLCInterface.new("plc_test", config)
assert(plc_interface ~= nil, "Failed to create PLC interface")
assert(plc_interface.name == "plc_test", "Interface name mismatch")
assert(plc_interface.type == "plc", "Interface type mismatch")
assert(plc_interface.address == "localhost", "Address mismatch")
assert(plc_interface.port == 8888, "Port mismatch")
print("✓ PLC interface created successfully\n")

-- 测试 2: 连接
print("[2] Testing connect method...")
local connect_result = plc_interface:connect()
assert(connect_result == true, "Failed to connect")
assert(plc_interface.status == "connected", "Status not connected after connect")
print("✓ Connect successful\n")

-- 测试 3: 发送数据
print("[3] Testing send method...")
local send_result = plc_interface:send("Test message via PLC")
assert(send_result == true, "Failed to send data")
print("✓ Send successful\n")

-- 测试 4: 接收数据
-- 在新设计中，receive从buffer读取数据
print("[4] Testing receive method...")
local received_data = plc_interface:receive()
print(string.format("  Received: %s", received_data))
assert(received_data == "Test message via PLC", "Failed to receive data")
print("✓ Receive successful\n")

-- 测试 5: 获取状态
print("[5] Testing get_status method...")
local status = plc_interface:get_status()
assert(status ~= nil, "Failed to get status")
assert(status.type == "plc", "Status type mismatch")
assert(status.name == "plc_test", "Status name mismatch")
assert(status.status == "connected", "Status value mismatch")
print("✓ Status retrieved successfully\n")

-- 测试 6: 断开连接
print("[6] Testing disconnect method...")
local disconnect_result = plc_interface:disconnect()
assert(disconnect_result == true, "Failed to disconnect")
assert(plc_interface.status == "disconnected", "Status not disconnected after disconnect")
print("✓ Disconnect successful\n")

-- 测试 7: buffer机制
print("[7] Testing buffer mechanism...")
local test_plc = PLCInterface.new("buffer_test", config)
test_plc:connect()
test_plc:send("Message 1")
test_plc:send("Message 2")
local data1 = test_plc:receive()
local data2 = test_plc:receive()
assert(data1 == "Message 1", "First buffer data mismatch")
assert(data2 == "Message 2", "Second buffer data mismatch")
print("✓ Buffer mechanism works correctly\n")

-- 测试 8: 自定义模拟数据
print("[8] Testing custom mock data...")
local mock_plc = PLCInterface.new("mock_test", config)
mock_plc:connect()
table.insert(mock_plc.buffer, "Hello from PLC interface")
local mock_data = mock_plc:receive()
assert(mock_data == "Hello from PLC interface", "Mock data mismatch")
print("✓ Custom mock data works correctly\n")

print("================================================")
print("  All PLC interface tests passed! ✅")
print("================================================")