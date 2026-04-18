-- interfaces/plc_interface.lua
-- PLC (Programmable Logic Controller) 接口类型
-- 实现PLC设备的通信接口，支持任意路由

local BaseInterface = require("interfaces.base_interface")

local PLCInterface = setmetatable({}, BaseInterface)
PLCInterface.__index = PLCInterface

function PLCInterface.new(name, config)
    local self = BaseInterface.new(name, config)
    setmetatable(self, PLCInterface)
    self.type = "plc"
    self.protocol = config.protocol or "plc"
    self.address = config.address or "localhost"
    self.port = config.port or 8888
    self.timeout = config.timeout or 5
    self.handler = config.handler
    self.buffer = {}
    return self
end

function PLCInterface:connect()
    if self.handler and self.handler.connect then
        local success, err = self.handler.connect(self)
        if success then
            self.status = "connected"
            return true
        else
            self.status = "error"
            self.error_msg = err
            return false
        end
    else
        -- 模拟连接成功
        self.status = "connected"
        return true
    end
end

function PLCInterface:disconnect()
    if self.handler and self.handler.disconnect then
        local success = self.handler.disconnect(self)
        if success then
            self.status = "disconnected"
            return true
        else
            return false
        end
    else
        self.status = "disconnected"
        return true
    end
end

function PLCInterface:send(data, timeout)
    if self.status ~= "connected" then
        self.status = "error"
        return false
    end

    if self.handler and self.handler.send then
        return self.handler.send(self, data, timeout or self.timeout)
    else
        -- 模拟发送成功
        table.insert(self.buffer, data)
        return true
    end
end

function PLCInterface:receive(timeout)
    if self.status ~= "connected" then
        self.status = "error"
        return nil
    end

    if self.handler and self.handler.receive then
        return self.handler.receive(self, timeout or self.timeout)
    else
        -- 模拟接收数据
        if #self.buffer > 0 then
            return table.remove(self.buffer, 1)
        end
        return nil
    end
end

function PLCInterface:get_status()
    return {
        type = self.type,
        name = self.name,
        status = self.status,
        error = self.error_msg,
        address = self.address,
        port = self.port,
        protocol = self.protocol
    }
end

return PLCInterface