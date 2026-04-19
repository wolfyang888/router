-- interfaces/base_interface.lua
-- 基础接口类
-- Handler作为可重写的连接/发送/接收实现
-- 子类可以选择重写方法或通过handler实现

local Error = require("utils.error")
local log = require("utils.logger")

local BaseInterface = {}
BaseInterface.__index = BaseInterface

function BaseInterface.new(name, config)
    local self = setmetatable({}, BaseInterface)
    self.name = name
    self.config = config or {}
    self.status = "disconnected"
    self.error_msg = nil
    self.buffer = {}
    return self
end

function BaseInterface:connect()
    log.info(self.name .. " interface connected")
    self.status = "connected"
    return true
end

function BaseInterface:disconnect()
    log.info(self.name .. " interface disconnected")
    self.status = "disconnected"
    return true
end

function BaseInterface:send(data, timeout)
    log.info(self.name .. " interface sending: " .. data)
    table.insert(self.buffer, data)
    return true
end

function BaseInterface:receive(timeout)
    if #self.buffer > 0 then
        return table.remove(self.buffer, 1)
    end
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

function BaseInterface:scan_devices()
    log.warn(self.name .. " interface does not implement scan_devices")
    return {}
end

return BaseInterface
