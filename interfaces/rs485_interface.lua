-- interfaces/rs485_interface.lua
local BaseInterface = require("interfaces.base_interface")

local RS485Interface = setmetatable({}, BaseInterface)
RS485Interface.__index = RS485Interface

function RS485Interface.new(name, config)
    local self = BaseInterface.new(name, config)
    setmetatable(self, RS485Interface)
    self.type = "rs485"
    self.fd = nil
    return self
end

function RS485Interface:connect()
    local port = self.config.port or "/dev/ttyUSB0"
    local baudrate = self.config.baudrate or 9600
    
    local cmd = string.format("stty -F %s %d raw -echo 2>/dev/null", port, baudrate)
    os.execute(cmd)
    
    self.fd = io.open(port, "r+b")
    
    if self.fd then
        self.status = "connected"
        return true
    else
        self.status = "error"
        self.error_msg = "Failed to open port"
        return false
    end
end

function RS485Interface:disconnect()
    if self.fd then
        self.fd:close()
        self.status = "disconnected"
        return true
    end
    return false
end

function RS485Interface:send(data, timeout)
    if not self.fd then
        self.status = "error"
        return false
    end
    
    local success, err = self.fd:write(data)
    self.fd:flush()
    
    if success then
        return true
    else
        self.status = "error"
        return false
    end
end

function RS485Interface:receive(timeout)
    if not self.fd then
        self.status = "error"
        return nil
    end
    
    timeout = timeout or self.config.timeout or 1.0
    local data = ""
    local start_time = os.time()
    
    while (os.time() - start_time) < timeout do
        local chunk = self.fd:read(256)
        if chunk and #chunk > 0 then
            data = data .. chunk
        else
            os.execute("sleep 0.01")
        end
    end
    
    return #data > 0 and data or nil
end

return RS485Interface
