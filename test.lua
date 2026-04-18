-- test.lua
#!/usr/bin/env lua

local json = nil
local success, json_lib = pcall(require, "cjson")
if success then
    json = json_lib
else
    -- 当cjson库不可用时，使用简单的序列化方式
    json = {
        encode = function(data)
            return tostring(data)
        end
    }
end
local HybridGateway = require("gateway")

print("================================================")
print("  Hybrid Routing Gateway - Test Suite")
print("================================================")
print("")

-- 创建网关实例
local gateway = HybridGateway.new("config")

-- 初始化
print("[1] Initializing gateway...")
gateway:initialize()
print("✓ Gateway initialized\n")

-- 测试消息路由
print("[2] Testing message routing...")
local test_messages = {
    {
        device_id = "device_001",
        src_subnet = "192.168.1.0/24",
        dst_subnet = "192.168.2.0/24",
        data = {
            type = "data",
            data = { temp = 25.5, humidity = 60 }
        }
    },
    {
        device_id = "device_002",
        src_subnet = "0.0.0.0/0",
        dst_subnet = "0.0.0.0/0",
        data = {
            type = "command",
            data = { action = "turn_on", device = "light_01" }
        }
    }
}

for i, msg in ipairs(test_messages) do
    print(string.format("  Test %d: Sending message from %s", i, msg.device_id))
    local result = gateway:handle_message(msg.device_id, msg)
    print(string.format("  Result: %s\n", result and "SUCCESS" or "FAILED"))
end

-- 显示路由状态
print("[3] Displaying routing status...")
local status = gateway.router_engine:get_routing_status()
print(json.encode(status, {indent = true}))

print("")
print("================================================")
print("  Test Suite Complete")
print("================================================")
