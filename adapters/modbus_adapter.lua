-- adapters/modbus_adapter.lua
local BaseAdapter = require("adapters.base_adapter")
local crc = require("utils.crc")

local ModbusAdapter = setmetatable({}, BaseAdapter)
ModbusAdapter.__index = ModbusAdapter

function ModbusAdapter.new(interface)
    local self = BaseAdapter.new(interface)
    setmetatable(self, ModbusAdapter)
    return self
end

function ModbusAdapter:send_message(message)
    local payload = self:serialize(message)
    if not payload then return false end
    return self.interface:send(payload)
end

function ModbusAdapter:receive_message(timeout)
    timeout = timeout or 1.0
    local data = self.interface:receive(timeout)
    if not data then return nil end
    return self:deserialize(data)
end

function ModbusAdapter:serialize(message)
    local slave_id = message.slave_id or 1
    local function_code = message.function_code or 3
    local address = message.address or 0
    local quantity = message.quantity or 1
    
    local data = string.pack("B B I2 I2", slave_id, function_code, address, quantity)
    local crc_value = crc.calculate(data)
    data = data .. string.pack("I2", crc_value)
    
    return data
end

function ModbusAdapter:deserialize(data)
    if #data < 5 then return nil end
    
    local slave_id, function_code, byte_count = string.unpack("B B B", data:sub(1, 3))
    local values = {}
    
    for i = 1, byte_count / 2 do
        local value = string.unpack("I2", data:sub(3 + i * 2 - 1, 3 + i * 2))
        table.insert(values, value)
    end
    
    return {
        slave_id = slave_id,
        function_code = function_code,
        values = values
    }
end

return ModbusAdapter