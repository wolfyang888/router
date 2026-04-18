-- adapters/custom_protocol_adapter.lua
local BaseAdapter = require("adapters.base_adapter")

local CustomProtocolAdapter = setmetatable({}, BaseAdapter)
CustomProtocolAdapter.__index = CustomProtocolAdapter

function CustomProtocolAdapter.new(interface, protocol_config)
    local self = BaseAdapter.new(interface)
    setmetatable(self, CustomProtocolAdapter)
    self.protocol_config = protocol_config or {}
    self.serializer = protocol_config.serializer
    self.deserializer = protocol_config.deserializer
    return self
end

function CustomProtocolAdapter:send_message(message)
    local payload = self:serialize(message)
    if not payload then return false end
    return self.interface:send(payload)
end

function CustomProtocolAdapter:receive_message(timeout)
    timeout = timeout or 5.0
    local data = self.interface:receive(timeout)
    if not data then return nil end
    return self:deserialize(data)
end

function CustomProtocolAdapter:serialize(message)
    if self.serializer then
        return self.serializer(message)
    else
        if type(message) == "string" then
            return message
        else
            return tostring(message)
        end
    end
end

function CustomProtocolAdapter:deserialize(data)
    if self.deserializer then
        return self.deserializer(data)
    else
        return data
    end
end

return CustomProtocolAdapter