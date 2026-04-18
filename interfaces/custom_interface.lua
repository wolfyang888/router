-- interfaces/custom_interface.lua
local BaseInterface = require("interfaces.base_interface")

local CustomInterface = setmetatable({}, BaseInterface)
CustomInterface.__index = CustomInterface

function CustomInterface.new(name, config)
    local self = BaseInterface.new(name, config)
    setmetatable(self, CustomInterface)
    self.type = "custom"
    self.protocol = config.protocol or "custom"
    self.handler = config.handler
    return self
end

function CustomInterface:connect()
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
        self.status = "connected"
        return true
    end
end

function CustomInterface:disconnect()
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

function CustomInterface:send(data, timeout)
    if self.status ~= "connected" then
        self.status = "error"
        return false
    end
    
    if self.handler and self.handler.send then
        return self.handler.send(self, data, timeout)
    else
        return false
    end
end

function CustomInterface:receive(timeout)
    if self.status ~= "connected" then
        self.status = "error"
        return nil
    end
    
    if self.handler and self.handler.receive then
        return self.handler.receive(self, timeout)
    else
        return nil
    end
end

return CustomInterface