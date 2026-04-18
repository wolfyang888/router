-- interfaces/can_interface.lua
local BaseInterface = require("interfaces.base_interface")

local CANInterface = setmetatable({}, BaseInterface)
CANInterface.__index = CANInterface

function CANInterface.new(name, config)
    local self = BaseInterface.new(name, config)
    setmetatable(self, CANInterface)
    self.type = "can"
    self.socket = nil
    self.can_id = config.can_id or 0x001
    return self
end

function CANInterface:connect()
    local interface = self.config.interface or "can0"
    
    -- 使用系统命令配置 CAN 接口
    local setup_cmd = string.format(
        "sudo ip link set %s type can bitrate %d && sudo ip link set %s up",
        interface, self.config.bitrate or 500000, interface
    )
    
    local result = os.execute(setup_cmd .. " 2>/dev/null")
    
    if result == 0 then
        self.status = "connected"
        self.interface_name = interface
        return true
    else
        self.status = "error"
        self.error_msg = "Failed to initialize CAN interface"
        return false
    end
end

function CANInterface:disconnect()
    if self.status == "connected" then
        local cmd = string.format("sudo ip link set %s down", self.interface_name or "can0")
        os.execute(cmd .. " 2>/dev/null")
        self.status = "disconnected"
        return true
    end
    return false
end

function CANInterface:send(data, timeout)
    if self.status ~= "connected" then
        self.status = "error"
        return false
    end
    
    -- 使用 cansend 命令发送 CAN 帧
    local cmd = string.format(
        "echo '%s#%s' | cansend %s",
        string.format("%03X", self.can_id),
        data:gsub(".", function(c) return string.format("%02X", string.byte(c)) end),
        self.interface_name or "can0"
    )
    
    local result = os.execute(cmd .. " 2>/dev/null")
    return result == 0
end

function CANInterface:receive(timeout)
    if self.status ~= "connected" then
        self.status = "error"
        return nil
    end
    
    timeout = timeout or 1.0
    
    -- 使用 candump 读取 CAN 消息
    local cmd = string.format(
        "timeout %.1f candump %s -c | head -1",
        timeout, self.interface_name or "can0"
    )
    
    local handle = io.popen(cmd .. " 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    
    if result and #result > 0 then
        return result
    end
    
    return nil
end

return CANInterface
