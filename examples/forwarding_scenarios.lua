-- examples/forwarding_scenarios.lua
-- 多设备转发场景演示
require("platform")
local json = require("cjson")
local RouterEngine = require("core.router_engine")
local ProtocolBridge = require("core.protocol_bridge")

print("================================================")
print("  Multi-Device Forwarding Scenarios")
print("================================================\n")

-- 创建路由引擎
local engine = RouterEngine.new()
local bridge = ProtocolBridge.new()

-- 配置拓扑：三个设备
local topology = {
    devices = {
        {
            device_id = "A",
            name = "Gateway",
            is_relay = true,
            interfaces = {
                {type = "tcp", port = "8888", priority = 100},
                {type = "ble", port = "00:1A:7D:DA:71:13", priority = 50},
                {type = "rs485", port = "/dev/ttyUSB0", priority = 60}
            }
        },
        {
            device_id = "B",
            name = "Relay",
            is_relay = true,
            interfaces = {
                {type = "tcp", port = "8889", priority = 100},
                {type = "rs485", port = "/dev/ttyUSB1", priority = 60}
            }
        },
        {
            device_id = "C",
            name = "Sensor",
            is_relay = false,
            interfaces = {
                {type = "rs485", port = "/dev/ttyUSB2", priority = 60},
                {type = "ble", port = "00:2A:7D:DA:71:14", priority = 50}
            }
        }
    }
}

-- 注册拓扑
engine:register_device_topology(topology)

print("[Test 1] Direct Connection Check")
print("--------")

-- 检查直接连接
local tcp_rs485_connected = engine:is_directly_connected("A", "B")
print(string.format("A <-> B (同协议连接): %s", tcp_rs485_connected and "YES" or "NO"))

local rs485_ble_connected = engine:is_directly_connected("B", "C")
print(string.format("B <-> C (同协议连接): %s", rs485_ble_connected and "YES" or "NO"))
print("")

print("[Test 2] Path Discovery")
print("--------")

-- 发现A到C的路径
local path = engine:discover_device_path("A", "C")
if path then
    print("Found path from A to C:")
    for i, hop in ipairs(path) do
        print(string.format("  Hop %d: %s -> %s", i, hop.from, hop.to))
    end
    print("")
    
    -- 具体化路径
    local materialized = engine:materialize_path(path)
    print("Materialized interface path:")
    for i, hop in ipairs(materialized) do
        print(string.format("  %d: %s -> %s", i, hop.src_addr, hop.dst_addr))
        print(string.format("     Protocol: %s", hop.protocol))
    end
else
    print("No path found")
end
print("")

print("[Test 3] Message Forwarding")
print("--------")

-- 模拟三个转发场景

-- 场景1: A(TCP) -> B(RS485) -> C(BLE)
print("Scenario 1: A(TCP) -> B(RS485) -> C(BLE)")
print("  Origin: A (TCP) sends sensor data")

local msg1 = {
    msg_id = "msg_001",
    src_device = "A",
    dst_device = "C",
    payload = json.encode({type="sensor", value=25.5}),
    hops = 0
}

local result = engine:forward_to_device(msg1, "A", "C")
print(string.format("  Result: %s", result and "SUCCESS" or "FAILED"))

if msg1.interface_path then
    print("  Interface path:")
    for i, hop in ipairs(msg1.interface_path) do
        local conv = i < #msg1.interface_path and 
            string.format(" (convert %s)", hop.protocol) or ""
        print(string.format("    %d: %s%s", i, hop.protocol, conv))
    end
end
print("")

-- 场景2: A(BLE) -> B(TCP) -> C(RS485)
print("Scenario 2: A(BLE) -> B(TCP) -> C(RS485)")
print("  This requires protocol conversion at B:")
print("  BLE -> TCP -> RS485")

local msg2 = {
    msg_id = "msg_002",
    src_device = "A",
    dst_device = "C",
    payload = json.encode({type="command", action="activate"}),
    hops = 0
}

local result2 = engine:forward_to_device(msg2, "A", "C")
print(string.format("  Result: %s", result2 and "SUCCESS" or "FAILED"))
print("")

-- 场景3: 协议转换演示
print("Scenario 3: Protocol Conversion Demo")
print("  Converting message between protocols")

local tcp_data = json.encode({device_id=1, value=100})
print(string.format("  Original (TCP): %s", tcp_data))

local rs485_data = bridge:convert(tcp_data, "tcp", "rs485")
print(string.format("  Converted (RS485): %s", rs485_data))

local back_to_tcp = bridge:convert(rs485_data, "rs485", "tcp")
print(string.format("  Back to (TCP): %s", back_to_tcp))
print("")

print("================================================")
print("  Demo Complete!")
print("================================================")
