-- tests/adapters/test_mqtt_adapter.lua
local uv, _ = require("platform")
local json = require("cjson")
local MQTTAdapter = require("adapters.mqtt_adapter")

-- 创建模拟接口
local MockInterface = {
    name = "mock",
    status = "connected",
    send = function(self, data) return true end,
    receive = function(self, timeout) return nil end,
    get_status = function(self) 
        return {status = self.status, name = self.name}
    end
}

print("================================================")
print("  MQTT Adapter Test Suite")
print("================================================\n")

-- 测试 1: 适配器创建
print("[1] Testing MQTT adapter creation...")
local adapter = MQTTAdapter.new(MockInterface, "test.broker", "test_client")
assert(adapter ~= nil, "Failed to create MQTT adapter")
assert(adapter.broker_addr == "test.broker", "Broker address mismatch")
assert(adapter.client_id == "test_client", "Client ID mismatch")
print("✓ MQTT adapter created successfully\n")

-- 测试 2: 序列化
print("[2] Testing serialization...")
local message = {
    topic = "sensors/temperature",
    payload = { value = 25.5, unit = "celsius" }
}

local serialized = adapter:serialize(message)
assert(serialized ~= nil, "Serialization failed")
assert(string.find(serialized, "sensors/temperature"), "Topic not in serialized data")
assert(string.find(serialized, "25.5"), "Payload value not in serialized data")
print(string.format("✓ Serialized: %s\n", serialized))

-- 测试 3: 反序列化
print("[3] Testing deserialization...")
local deserialized = adapter:deserialize(serialized)
assert(deserialized ~= nil, "Deserialization failed")
assert(deserialized.topic == "sensors/temperature", "Topic mismatch")
assert(deserialized.payload.value == 25.5, "Payload value mismatch")
assert(deserialized.payload.unit == "celsius", "Payload unit mismatch")
print("✓ Deserialization works correctly\n")

-- 测试 4: 往返测试 (Round-trip)
print("[4] Testing round-trip serialization...")
local original = {
    topic = "system/status",
    payload = { state = "running", uptime = 86400 }
}

local encoded = adapter:serialize(original)
local decoded = adapter:deserialize(encoded)

assert(decoded.topic == original.topic, "Topic mismatch after round-trip")
assert(decoded.payload.state == original.payload.state, "State mismatch after round-trip")
assert(decoded.payload.uptime == original.payload.uptime, "Uptime mismatch after round-trip")
print("✓ Round-trip serialization successful\n")

-- 测试 5: 复杂 payload
print("[5] Testing complex payload...")
local complex_msg = {
    topic = "device/001/data",
    payload = {
        sensors = {
            temperature = 23.5,
            humidity = 65,
            pressure = 1013
        },
        timestamp = os.time(),
        status = "ok"
    }
}

local complex_encoded = adapter:serialize(complex_msg)
local complex_decoded = adapter:deserialize(complex_encoded)

assert(complex_decoded.payload.sensors.temperature == 23.5, "Complex payload failed")
assert(complex_decoded.payload.status == "ok", "Status field failed")
print("✓ Complex payload handling successful\n")

print("================================================")
print("  All tests passed! ✅")
print("================================================")