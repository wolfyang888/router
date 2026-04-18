-- adapters/tcp_protocol_adapter.lua
local BaseAdapter = require("adapters.base_adapter")

local TCPProtocolAdapter = setmetatable({}, BaseAdapter)
TCPProtocolAdapter.__index = TCPProtocolAdapter

function TCPProtocolAdapter.new(interface)
    local self = BaseAdapter.new(interface)
    setmetatable(self, TCPProtocolAdapter)
    return self
end

function TCPProtocolAdapter:send_message(message)
    local payload = self:serialize(message)
    if not payload then return false end
    return self.interface:send(payload)
end

function TCPProtocolAdapter:receive_message(timeout)
    timeout = timeout or 5.0
    local data = self.interface:receive(timeout)
    if not data then return nil end
    return self:deserialize(data)
end

function TCPProtocolAdapter:serialize(message)
    if type(message) == "string" then
        return message
    else
        return tostring(message)
    end
end

function TCPProtocolAdapter:deserialize(data)
    return data
end

return TCPProtocolAdapter