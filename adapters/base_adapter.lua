-- adapters/base_adapter.lua
local BaseAdapter = {}
BaseAdapter.__index = BaseAdapter

function BaseAdapter.new(interface)
    local self = setmetatable({}, BaseAdapter)
    self.interface = interface
    self.message_queue = {}
    self.response_handlers = {}
    return self
end

function BaseAdapter:send_message(message)
    return false
end

function BaseAdapter:receive_message(timeout)
    return nil
end

function BaseAdapter:serialize(message)
    return nil
end

function BaseAdapter:deserialize(data)
    return nil
end

return BaseAdapter
