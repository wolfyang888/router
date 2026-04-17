-- interfaces/tcp_interface.lua
local socket = require("socket")
local BaseInterface = require("interfaces.base_interface")

local TCPInterface = setmetatable({}, BaseInterface)
TCPInterface.__index = TCPInterface

function TCPInterface.new(name, config)
    local self = BaseInterface.new(name, config)
    setmetatable(self, TCPInterface)
    self.type = "tcp"
    self.socket = nil
    return self
end

function TCPInterface:connect()
    local host = self.config.host or "localhost"
    local port = self.config.port or 8888
    local timeout = self.config.timeout or 10
    
    self.socket = socket.tcp()
    self.socket:settimeout(timeout)
    
    local success, err = self.socket:connect(host, port)
    
    if success then
        self.status = "connected"
        return true
    else
        self.status = "error"
        self.error_msg = err
        return false
    end
end

function TCPInterface:disconnect()
    if self.socket then
        self.socket:close()
        self.status = "disconnected"
        return true
    end
    return false
end

function TCPInterface:send(data, timeout)
    if not self.socket then
        self.status = "error"
        return false
    end
    
    timeout = timeout or self.config.timeout or 5
    self.socket:settimeout(timeout)
    
    local success, err = self.socket:send(data)
    
    if success then
        return true
    else
        self.status = "error"
        self.error_msg = err
        return false
    end
end

function TCPInterface:receive(timeout)
    if not self.socket then
        self.status = "error"
        return nil
    end
    
    timeout = timeout or self.config.timeout or 5
    self.socket:settimeout(timeout)
    
    local data, err = self.socket:receive("*a")
    
    if data then
        return data
    else
        return nil
    end
end

return TCPInterface
