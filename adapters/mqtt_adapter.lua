-- adapters/mqtt_adapter.lua
local json = nil
local success, json_lib = pcall(require, "cjson")
if success then
    json = json_lib
else
    -- 当cjson库不可用时，使用简单的序列化方式
    json = {
        encode = function(data)
            return tostring(data)
        end,
        decode = function(data)
            return data
        end
    }
end
local BaseAdapter = require("adapters.base_adapter")

local MQTTAdapter = setmetatable({}, BaseAdapter)
MQTTAdapter.__index = MQTTAdapter

function MQTTAdapter.new(interface, broker_addr, client_id)
    local self = BaseAdapter.new(interface)
    setmetatable(self, MQTTAdapter)
    self.broker_addr = broker_addr
    self.client_id = client_id
    return self
end

function MQTTAdapter:send_message(message)
    local payload = self:serialize(message)
    if not payload then return false end
    return self.interface:send(payload)
end

function MQTTAdapter:receive_message(timeout)
    timeout = timeout or 5.0
    local data = self.interface:receive(timeout)
    if not data then return nil end
    return self:deserialize(data)
end

function MQTTAdapter:serialize(message)
    local topic = message.topic or "default"
    local payload = json.encode(message.payload or {})
    return topic .. "|" .. payload
end

function MQTTAdapter:deserialize(data)
    local parts = {}
    for part in string.gmatch(data, "[^|]+") do
        table.insert(parts, part)
    end
    
    if #parts < 1 then return nil end
    
    local topic = parts[1]
    local payload = {}
    
    if #parts > 1 then
        local ok, result = pcall(json.decode, parts[2])
        if ok then payload = result end
    end
    
    return { topic = topic, payload = payload }
end

return MQTTAdapter
