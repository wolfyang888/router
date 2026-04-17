-- interfaces/base_interface.lua
local BaseInterface = {}
BaseInterface.__index = BaseInterface

function BaseInterface.new(name, config)
    local self = setmetatable({}, BaseInterface)
    self.name = name
    self.config = config or {}
    self.status = "disconnected"
    self.error_msg = nil
    return self
end

function BaseInterface:connect()
    return false
end

function BaseInterface:disconnect()
    return false
end

function BaseInterface:send(data, timeout)
    return false
end

function BaseInterface:receive(timeout)
    return nil
end

function BaseInterface:get_status()
    return {
        type = self.type,
        name = self.name,
        status = self.status,
        error = self.error_msg
    }
end

return BaseInterface
