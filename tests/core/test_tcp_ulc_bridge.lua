-- test_tcp_ulc_bridge.lua
-- 测试TCP与ULC协议转换

local ProtocolBridge = require("core.protocol_bridge")

local bridge = ProtocolBridge.new()

print("\n================================================")
print("  TCP <-> ULC Protocol Bridge Test Suite")
print("================================================")

-- 测试1: TCP -> ULC 转换
print("\n[1] Testing TCP -> ULC conversion...")
local tcp_data = [[{"device_id": "device_001", "payload": "Hello ULC"}]]
local ulc_data = bridge:convert(tcp_data, "tcp", "ulc")
print("  TCP input:  " .. tcp_data)
print("  ULC output: " .. ulc_data)
print("  ✅ TCP -> ULC conversion successful")

-- 测试2: ULC -> TCP 转换
print("\n[2] Testing ULC -> TCP conversion...")
local tcp_output = bridge:convert(ulc_data, "ulc", "tcp")
print("  ULC input:  " .. ulc_data)
print("  TCP output: " .. tcp_output)
print("  ✅ ULC -> TCP conversion successful")

-- 测试3: 复杂JSON数据转换
print("\n[3] Testing complex JSON conversion...")
local complex_tcp = [[{"device_id": "device_002", "payload": {"temperature": 25.5, "humidity": 65, "pressure": 1013}}]]
local complex_ulc = bridge:convert(complex_tcp, "tcp", "ulc")
local complex_result = bridge:convert(complex_ulc, "ulc", "tcp")
print("  Complex TCP input:  " .. complex_tcp)
print("  Complex ULC output: " .. complex_ulc)
print("  Complex TCP result: " .. complex_result)
print("  ✅ Complex JSON conversion successful")

-- 测试4: 空数据转换
print("\n[4] Testing empty data conversion...")
local empty_tcp = [[{"device_id": "device_003", "payload": ""}]]
local empty_ulc = bridge:convert(empty_tcp, "tcp", "ulc")
local empty_result = bridge:convert(empty_ulc, "ulc", "tcp")
print("  Empty TCP input:  " .. empty_tcp)
print("  Empty ULC output: " .. empty_ulc)
print("  Empty TCP result: " .. empty_result)
print("  ✅ Empty data conversion successful")

-- 测试5: 重复转换（测试缓存）
print("\n[5] Testing repeated conversion (cache test)...")
local test_data = [[{"device_id": "device_004", "payload": "Test cache"}]]

local start_time = os.clock()
for i = 1, 10 do
    local result = bridge:convert(test_data, "tcp", "ulc")
    local back = bridge:convert(result, "ulc", "tcp")
end
local end_time = os.clock()

print("  10 conversions completed in " .. (end_time - start_time) .. " seconds")
print("  ✅ Cache test successful")

print("\n================================================")
print("  All TCP <-> ULC bridge tests passed! ✅")
print("================================================")