-- adapters/plc_protocol_adapter.lua
-- PLC (Programmable Logic Controller) 协议适配器
-- 实现PLC协议的序列化和反序列化

local BaseAdapter = require("adapters.base_adapter")

local PLCProtocolAdapter = setmetatable({}, BaseAdapter)
PLCProtocolAdapter.__index = PLCProtocolAdapter

function PLCProtocolAdapter.new(interface)
    local self = BaseAdapter.new(interface)
    setmetatable(self, PLCProtocolAdapter)
    self.protocol_version = "1.0"
    self.message_id = 0
    return self
end

function PLCProtocolAdapter:send_message(message)
    local payload = self:serialize(message)
    if not payload then return false end
    return self.interface:send(payload)
end

function PLCProtocolAdapter:receive_message(timeout)
    timeout = timeout or 5.0
    local data = self.interface:receive(timeout)
    if not data then return nil end
    return self:deserialize(data)
end

function PLCProtocolAdapter:serialize(message)
    if type(message) == "string" then
        return self:wrap_message("TEXT", message)
    elseif type(message) == "table" then
        if message.type then
            return self:wrap_message(message.type, message.payload or message.data or "")
        else
            return self:encode_json(message)
        end
    else
        return self:wrap_message("TEXT", tostring(message))
    end
end

function PLCProtocolAdapter:deserialize(data)
    local msg_type, payload = self:unwrap_message(data)
    if not msg_type then
        return self:decode_json(data)
    end

    local message = {
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

    return message
end

function PLCProtocolAdapter:wrap_message(msg_type, payload)
    self.message_id = self.message_id + 1
    local msg_id = string.format("%08X", self.message_id)
    local length = #payload
    return string.format("[PLC:%s:%s:%04X:%s]", self.protocol_version, msg_id, length, payload)
end

function PLCProtocolAdapter:unwrap_message(data)
    local version, msg_id, length, payload = string.match(data, "%[PLC:(%d+.%d+):(%x+):(%x+):(.+)%]")
    if not version then
        return nil, nil
    end
    return "PLC", payload
end

function PLCProtocolAdapter:encode_json(message)
    local json = require("cjson")
    local encoded = json.encode(message)
    self.message_id = self.message_id + 1
    local msg_id = string.format("%08X", self.message_id)
    return string.format("[PLC:%s:%s:%04X:%s]", self.protocol_version, msg_id, #encoded, encoded)
end

function PLCProtocolAdapter:decode_json(data)
    local json = require("cjson")
    local msg_type, payload = self:unwrap_message(data)
    if payload then
        local success, decoded = pcall(json.decode, payload)
        if success then
            return decoded
        end
    end
    local success, decoded = pcall(json.decode, data)
    if success then
        return decoded
    end
    return {data = data}
end

function PLCProtocolAdapter:get_message_id()
    return self.message_id
end

return PLCProtocolAdapter