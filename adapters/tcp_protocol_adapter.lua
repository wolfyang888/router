-- adapters/tcp_protocol_adapter.lua
local BaseAdapter = require("adapters.base_adapter")
local log = require("utils.logger")

local TCPProtocolAdapter = setmetatable({}, BaseAdapter)
TCPProtocolAdapter.__index = TCPProtocolAdapter

function TCPProtocolAdapter.new(interface)
    log.info("[TCPProtocolAdapter.new] Entry - interface: " .. tostring(interface and interface.name))
    local self = BaseAdapter.new(interface)
    setmetatable(self, TCPProtocolAdapter)
    log.info("[TCPProtocolAdapter.new] Exit - created TCPProtocolAdapter")
    return self
end

function TCPProtocolAdapter:send_message(message)
    log.info("[TCPProtocolAdapter.send_message] Entry - message type: " .. type(message))
    local payload = self:serialize(message)
    if not payload then
        log.error("[TCPProtocolAdapter.send_message] Serialize failed")
        log.info("[TCPProtocolAdapter.send_message] Exit - failed")
        return false
    end
    local result = self.interface:send(payload)
    log.info("[TCPProtocolAdapter.send_message] Exit - result: " .. tostring(result))
    return result
end

function TCPProtocolAdapter:receive_message(timeout)
    log.debug("[TCPProtocolAdapter.receive_message] Entry - timeout: " .. tostring(timeout))
    timeout = timeout or 5.0
    local data = self.interface:receive(timeout)
    if not data then
        log.debug("[TCPProtocolAdapter.receive_message] Exit - no data received")
        return nil
    end
    local message = self:deserialize(data)
    log.debug("[TCPProtocolAdapter.receive_message] Exit - received message")
    return message
end

function TCPProtocolAdapter:serialize(message)
    log.debug("[TCPProtocolAdapter.serialize] Entry - message type: " .. type(message))
    local result
    if type(message) == "string" then
        result = message
    else
        result = tostring(message)
    end
    log.debug("[TCPProtocolAdapter.serialize] Exit - result length: " .. #result)
    return result
end

function TCPProtocolAdapter:deserialize(data)
    log.debug("[TCPProtocolAdapter.deserialize] Entry - data length: " .. #data)
    log.debug("[TCPProtocolAdapter.deserialize] Exit - returning data")
    return data
end

return TCPProtocolAdapter