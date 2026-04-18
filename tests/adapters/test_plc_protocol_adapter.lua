-- test_plc_protocol_adapter.lua
-- 测试PLC协议适配器

require("platform")
local PLCProtocolAdapter = require("adapters.plc_protocol_adapter")
local PLCInterface = require("interfaces.plc_interface")

print("================================================")
print("  PLC Protocol Adapter Test Suite")
print("================================================\n")

-- 创建模拟接口
local MockInterface = {
    name = "mock_plc",
    status = "connected",
    send = function(self, data)
        print("  [Send] " .. data)
        return true
    end,
    receive = function(self, timeout)
        return "[PLC:1.0:00000001:0019:{\"device\":\"plc01\",\"value\":25.5}]"
    end,
    get_status = function(self)
        return {status = self.status, name = self.name}
    end
}

-- 创建PLC协议适配器
print("[1] Creating PLC protocol adapter...")
local adapter = PLCProtocolAdapter.new(MockInterface)
assert(adapter ~= nil, "Failed to create PLC protocol adapter")
assert(adapter.protocol_version == "1.0", "Protocol version mismatch")
print("✓ PLC protocol adapter created successfully\n")

-- 测试序列化 - 字符串消息
print("[2] Testing serialization of string message...")
local text_msg = "Hello PLC"
local serialized = adapter:serialize(text_msg)
print(string.format("  Serialized: %s", serialized))
assert(serialized ~= nil, "Serialization failed")
assert(string.find(serialized, "%[PLC:"), "PLC header not found")
assert(string.find(serialized, "Hello PLC"), "Message content not found")
print("✓ String serialization successful\n")

-- 测试序列化 - JSON消息
print("[3] Testing serialization of JSON message...")
local json_msg = {device = "plc01", value = 25.5, unit = "celsius"}
local json_serialized = adapter:serialize(json_msg)
print(string.format("  Serialized: %s", json_serialized))
assert(json_serialized ~= nil, "JSON serialization failed")
assert(string.find(json_serialized, "%[PLC:"), "PLC header not found")
print("✓ JSON serialization successful\n")

-- 测试序列化 - 带类型的消息
print("[4] Testing serialization of typed message...")
local typed_msg = {type = "DATA", payload = "Temperature reading"}
local typed_serialized = adapter:serialize(typed_msg)
print(string.format("  Serialized: %s", typed_serialized))
assert(typed_serialized ~= nil, "Typed serialization failed")
assert(string.find(typed_serialized, "%[PLC:"), "PLC header not found")
print("✓ Typed serialization successful\n")

-- 测试发送消息
print("[5] Testing send_message...")
local send_result = adapter:send_message("Test message")
assert(send_result == true, "Failed to send message")
print("✓ Send message successful\n")

-- 测试接收消息
print("[6] Testing receive_message...")
local received = adapter:receive_message(5.0)
print(string.format("  Received type: %s", type(received)))
print(string.format("  Received data: %s", tostring(received)))
assert(received ~= nil, "Failed to receive message")
assert(received.type == "PLC", "Message type mismatch")
assert(received.payload ~= nil, "Payload missing")
print("✓ Receive message successful\n")

-- 测试消息ID生成
print("[7] Testing message ID generation...")
local msg_id1 = adapter:get_message_id()
local another_msg = adapter:serialize("Another test")
local msg_id2 = adapter:get_message_id()
assert(msg_id1 < msg_id2, "Message ID not incrementing")
print(string.format("  Message IDs: %d < %d", msg_id1, msg_id2))
print("✓ Message ID generation working\n")

-- 测试反序列化
print("[8] Testing deserialization of raw data...")
local raw_data = "[PLC:1.0:00000001:000D:Hello PLC]"
local deserialized = adapter:deserialize(raw_data)
print(string.format("  Deserialized: %s", tostring(deserialized)))
assert(deserialized ~= nil, "Deserialization failed")
print("✓ Deserialization successful\n")

-- 测试复杂JSON消息
print("[9] Testing complex JSON message...")
local complex_msg = {
    device_id = "device_001",
    timestamp = os.time(),
    sensors = {
        temperature = 23.5,
        humidity = 65,
        pressure = 1013
    },
    status = "ok"
}
local complex_serialized = adapter:serialize(complex_msg)
print(string.format("  Complex serialized: %s", complex_serialized))
local complex_deserialized = adapter:deserialize(complex_serialized)
print(string.format("  Complex deserialized: %s", tostring(complex_deserialized)))
print("✓ Complex JSON handling successful\n")

print("================================================")
print("  All PLC protocol adapter tests passed! ✅")
print("================================================")