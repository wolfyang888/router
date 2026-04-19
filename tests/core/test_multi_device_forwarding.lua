-- tests/core/test_multi_device_forwarding.lua
-- 多设备转发测试

local RouterEngine = require("core.router_engine")
local ProtocolBridge = require("core.protocol_bridge")
local json = require("cjson")

print("================================================")
print("  Multi-Device Forwarding Tests")
print("================================================\n")

local engine = RouterEngine.new()
local bridge = ProtocolBridge.new()

-- 测试1: 拓扑注册
print("[1] Testing topology registration...")
local topology = {
    devices = {
        {
            device_id = "A",
            is_relay = true,
            interfaces = {
                {type = "tcp", port = "8888"},
                {type = "rs485", port = "/dev/ttyUSB0"}
            }
        },
        {
            device_id = "B",
            is_relay = true,
            interfaces = {
                {type = "rs485", port = "/dev/ttyUSB1"}
            }
        }
    }
}

engine:register_device_topology(topology)
assert(engine.devices["A"] ~= nil, "Device A not registered")
assert(engine.devices["B"] ~= nil, "Device B not registered")
print("✓ Topology registration works\n")

-- 测试2: 地址解析
print("[2] Testing address parsing...")
local addr = engine:parse_device_address("A:tcp:8888:channel1")
assert(addr.device_id == "A", "Device ID mismatch")
assert(addr.protocol == "tcp", "Protocol mismatch")
print("✓ Address parsing works\n")

-- 测试3: 直接连接检查
print("[3] Testing direct connection...")
local connected = engine:is_directly_connected("A", "B")
assert(connected == true, "A and B should be connected via RS485")
print("✓ Direct connection check works\n")

-- 测试4: 路径发现
print("[4] Testing path discovery...")
local path = engine:discover_device_path("A", "B")
assert(path ~= nil, "No path found from A to B")
print(string.format("✓ Found path with %d hops\n", #path))

-- 测试5: 协议转换
print("[5] Testing protocol conversion...")
local tcp_msg = json.encode({device_id=1, value=42})
local rs485_msg = bridge:convert(tcp_msg, "tcp", "rs485")
assert(rs485_msg ~= nil, "Protocol conversion failed")
print("✓ Protocol conversion works\n")

-- 测试6: 往返转换
print("[6] Testing round-trip conversion...")
local back = bridge:convert(rs485_msg, "rs485", "tcp")
local parsed_back = json.decode(back)
assert(parsed_back ~= nil, "Round-trip conversion returned nil")
assert(parsed_back.device_id ~= nil, "Device ID not preserved in round-trip")
print("✓ Round-trip conversion successful\n")

print("================================================")
print("  All Tests Passed! ✅")
print("================================================")
