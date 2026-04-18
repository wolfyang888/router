-- interfaces/tcp_interface.lua
local uv = nil
local success, uv_lib = pcall(require, "uv")
if success then
    uv = uv_lib
else
    -- 当uv库不可用时，使用模拟实现
    uv = {
        new_tcp = function()
            return {
                connect = function() return false, "UV library not available" end,
                close = function() end,
                read_start = function() end,
                write = function() return false, "UV library not available" end
            }
        end
    }
end
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
    
    self.socket = uv.new_tcp()
    
    local success, err = self.socket:connect(host, port, function(err)
        if err then
            self.status = "error"
            self.error_msg = err
        else
            self.status = "connected"
        end
    end)
    
    if not success then
        self.status = "error"
        self.error_msg = err
        return false
    end
    
    return true
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
    
    local success, err = self.socket:write(data, function(err)
        if err then
            self.status = "error"
            self.error_msg = err
        end
    end)
    
    if not success then
        self.status = "error"
        self.error_msg = err
        return false
    end
    
    return true
end

function TCPInterface:receive(timeout)
    if not self.socket then
        self.status = "error"
        return nil
    end
    
    -- 对于UV库，我们使用异步接收
    -- 这里简化实现，实际使用时可能需要更复杂的处理
    self.receive_buffer = ""
    
    self.socket:read_start(function(err, data)
        if err then
            self.status = "error"
            self.error_msg = err
        elseif data then
            self.receive_buffer = self.receive_buffer .. data
        end
    end)
    
    -- 由于是异步接收，这里返回空，实际使用时需要通过回调处理
    return ""
end

return TCPInterface
