-- interfaces/ble_interface.lua
local BaseInterface = require("interfaces.base_interface")

local BLEInterface = setmetatable({}, BaseInterface)
BLEInterface.__index = BLEInterface

function BLEInterface.new(name, config)
    local self = BaseInterface.new(name, config)
    setmetatable(self, BLEInterface)
    self.type = "ble"
    self.handle = nil
    self.characteristic = nil
    self.address = config.address or "00:00:00:00:00:00"
    return self
end

function BLEInterface:connect()
    local address = self.address
    
    -- 检查设备是否可用
    local cmd = string.format("hcitool scan | grep '%s'", address)
    local result = os.execute(cmd .. " > /dev/null 2>&1")
    
    if result == 0 then
        self.status = "connected"
        return true
    else
        self.status = "error"
        self.error_msg = "BLE device not found"
        return false
    end
end

function BLEInterface:disconnect()
    if self.status == "connected" then
        self.status = "disconnected"
        return true
    end
    return false
end

function BLEInterface:send(data, timeout)
    if self.status ~= "connected" then
        self.status = "error"
        return false
    end
    
    local char_uuid = self.config.char_uuid or "0000180a-0000-1000-8000-00805f9b34fb"
    local hex_data = data:gsub(".", function(c)
        return string.format("%02X", string.byte(c))
    end)
    
    local cmd = string.format(
        "gatttool -b %s --char-write-req -a %s -n %s",
        self.address, char_uuid, hex_data
    )
    
    local result = os.execute(cmd .. " > /dev/null 2>&1")
    return result == 0
end

function BLEInterface:receive(timeout)
    if self.status ~= "connected" then
        self.status = "error"
        return nil
    end
    
    local char_uuid = self.config.char_uuid or "0000180a-0000-1000-8000-00805f9b34fb"
    local cmd = string.format(
        "gatttool -b %s --char-read -a %s 2>/dev/null | grep 'Attribute' | awk '{print $NF}'",
        self.address, char_uuid
    )
    
    local handle = io.popen(cmd)
    local data = handle:read("*a")
    handle:close()
    
    return #data > 0 and data or nil
end

return BLEInterface
