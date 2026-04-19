-- adapters/plc_protocol_adapter.lua
-- PLC (Programmable Logic Controller) 协议适配器
-- 实现PLC协议的序列化和反序列化

local BaseAdapter = require("adapters.base_adapter")
local log = require("utils.logger")

local PLCProtocolAdapter = setmetatable({}, BaseAdapter)
PLCProtocolAdapter.__index = PLCProtocolAdapter

function PLCProtocolAdapter.new(interface)
    log.info("[PLCProtocolAdapter.new] Entry - interface: " .. tostring(interface and interface.name))
    local self = BaseAdapter.new(interface)
    setmetatable(self, PLCProtocolAdapter)
    self.protocol_version = "1.0"
    self.message_id = 0
    log.info("[PLCProtocolAdapter.new] Exit - created PLCProtocolAdapter")
    return self
end

function PLCProtocolAdapter:send_message(message)
    log.info("[PLCProtocolAdapter.send_message] Entry - message type: " .. tostring(message and message.type))
    local payload = self:serialize(message)
    if not payload then
        log.error("[PLCProtocolAdapter.send_message] Serialize failed")
        log.info("[PLCProtocolAdapter.send_message] Exit - failed")
        return false
    end
    local result = self.interface:send(payload)
    log.info("[PLCProtocolAdapter.send_message] Exit - result: " .. tostring(result))
    return result
end

function PLCProtocolAdapter:receive_message(timeout)
    log.debug("[PLCProtocolAdapter.receive_message] Entry - timeout: " .. tostring(timeout))
    timeout = timeout or 5.0
    local data = self.interface:receive(timeout)
    if not data then
        log.debug("[PLCProtocolAdapter.receive_message] Exit - no data received")
        return nil
    end
    local message = self:deserialize(data)
    log.debug("[PLCProtocolAdapter.receive_message] Exit - received message type: " .. tostring(message and message.type))
    return message
end

function PLCProtocolAdapter:serialize(message)
    log.debug("[PLCProtocolAdapter.serialize] Entry - message type: " .. type(message))
    local result
    if type(message) == "string" then
        result = self:wrap_message("TEXT", message)
    elseif type(message) == "table" then
        if message.type then
            result = self:wrap_message(message.type, message.payload or message.data or "")
        else
            result = self:encode_json(message)
        end
    else
        result = self:wrap_message("TEXT", tostring(message))
    end
    log.debug("[PLCProtocolAdapter.serialize] Exit - result length: " .. #result)
    return result
end

function PLCProtocolAdapter:deserialize(data)
    log.debug("[PLCProtocolAdapter.deserialize] Entry - data length: " .. #data)
    local msg_type, payload = self:unwrap_message(data)
    local message
    if not msg_type then
        message = self:decode_json(data)
    else
        message = {
            type = msg_type,
            payload = payload,
            timestamp = os.time()
        }

        if msg_type == "TEXT" then
            message.data = payload
        elseif msg_type == "JSON" then
            message.data = self:decode_json(payload)
        elseif msg_type == "BINARY" then
            message.data = payload
        end
    end
    log.debug("[PLCProtocolAdapter.deserialize] Exit - message type: " .. tostring(message and message.type))
    return message
end

function PLCProtocolAdapter:wrap_message(msg_type, payload)
    log.debug("[PLCProtocolAdapter.wrap_message] Entry - msg_type: " .. msg_type)
    self.message_id = self.message_id + 1
    local msg_id = string.format("%08X", self.message_id)
    local length = #payload
    local result = string.format("[PLC:%s:%s:%04X:%s]", self.protocol_version, msg_id, length, payload)
    log.debug("[PLCProtocolAdapter.wrap_message] Exit - wrapped message length: " .. #result)
    return result
end

function PLCProtocolAdapter:unwrap_message(data)
    log.debug("[PLCProtocolAdapter.unwrap_message] Entry - data: " .. tostring(data))
    local version, msg_id, length, payload = string.match(data, "%[PLC:(%d+.%d+):(%x+):(%x+):(.+)%]")
    if not version then
        log.debug("[PLCProtocolAdapter.unwrap_message] Exit - no match, returning nil")
        return nil, nil
    end
    log.debug("[PLCProtocolAdapter.unwrap_message] Exit - msg_type: PLC, payload length: " .. #payload)
    return "PLC", payload
end

function PLCProtocolAdapter:encode_json(message)
    log.debug("[PLCProtocolAdapter.encode_json] Entry")
    local json = require("cjson")
    local encoded = json.encode(message)
    self.message_id = self.message_id + 1
    local msg_id = string.format("%08X", self.message_id)
    local result = string.format("[PLC:%s:%s:%04X:%s]", self.protocol_version, msg_id, #encoded, encoded)
    log.debug("[PLCProtocolAdapter.encode_json] Exit - encoded length: " .. #result)
    return result
end

function PLCProtocolAdapter:decode_json(data)
    log.debug("[PLCProtocolAdapter.decode_json] Entry - data length: " .. #data)
    local json = require("cjson")
    local msg_type, payload = self:unwrap_message(data)
    local result
    if payload then
        local success, decoded = pcall(json.decode, payload)
        if success then
            log.debug("[PLCProtocolAdapter.decode_json] Exit - decoded from payload")
            return decoded
        end
    end
    local success, decoded = pcall(json.decode, data)
    if success then
        log.debug("[PLCProtocolAdapter.decode_json] Exit - decoded from data")
        return decoded
    end
    log.debug("[PLCProtocolAdapter.decode_json] Exit - returning raw data")
    return {data = data}
end

function PLCProtocolAdapter:get_message_id()
    log.debug("[PLCProtocolAdapter.get_message_id] Entry/Exit - message_id: " .. self.message_id)
    return self.message_id
end

return PLCProtocolAdapter