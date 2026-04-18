-- core/protocol_bridge.lua
-- 协议转换和转发桥接

local json = require("cjson")

local ProtocolBridge = {}
ProtocolBridge.__index = ProtocolBridge

function ProtocolBridge.new()
    local self = setmetatable({}, ProtocolBridge)
    self.converters = {}
    return self
end

-- TCP <-> RS485 转换
function ProtocolBridge:tcp_rs485_bridge()
    return {
        tcp_to_rs485 = function(data)
            -- TCP (JSON) -> RS485 (Modbus)
            local msg = json.decode(data)
            local device_id = msg.device_id or 1
            local func_code = msg.function_code or 3
            local payload = msg.payload or ""
            
            -- 格式: [设备ID][功能码][数据][校验和]
            return string.format("%02X%02X%s", device_id, func_code, payload)
        end,
        
        rs485_to_tcp = function(data)
            -- RS485 (Modbus) -> TCP (JSON)
            local device_id = tonumber(string.sub(data, 1, 2), 16)
            local func_code = tonumber(string.sub(data, 3, 4), 16)
            local payload = string.sub(data, 5)
            
            return json.encode({
                device_id = device_id,
                function_code = func_code,
                payload = payload
            })
        end
    }
end

-- TCP <-> BLE 转换
function ProtocolBridge:tcp_ble_bridge()
    return {
        tcp_to_ble = function(data)
            -- TCP (JSON) -> BLE (GATT)
            return data  -- BLE使用UTF-8字符串
        end,
        
        ble_to_tcp = function(data)
            -- BLE (GATT) -> TCP (JSON)
            return data  -- 直接透传
        end
    }
end

-- RS485 <-> BLE 转换
function ProtocolBridge:rs485_ble_bridge()
    return {
        rs485_to_ble = function(data)
            -- RS485 (Modbus) -> BLE (Binary)
            local device_id = tonumber(string.sub(data, 1, 2), 16)
            return json.encode({
                device_id = device_id,
                data = string.sub(data, 3)
            })
        end,
        
        ble_to_rs485 = function(data)
            -- BLE (Binary) -> RS485 (Modbus)
            local msg = json.decode(data)
            local device_id = msg.device_id or 1
            return string.format("%02X%s", device_id, msg.data or "")
        end
    }
end

-- TCP <-> ULC 转换
function ProtocolBridge:tcp_ulc_bridge()
    return {
        tcp_to_ulc = function(data)
            -- TCP (JSON) -> ULC (Custom)
            local msg = json.decode(data)
            local device_id = msg.device_id or "device_001"
            local payload = msg.payload or ""
            
            -- 格式: [ULC:version:msg_id:payload]
            local version = "1.0"
            local msg_id = string.format("%08X", math.random(0, 0xFFFFFFFF))
            return string.format("[ULC:%s:%s:%s]", version, msg_id, payload)
        end,
        
        ulc_to_tcp = function(data)
            -- ULC (Custom) -> TCP (JSON)
            local version, msg_id, payload = string.match(data, "%[ULC:(%d+%.%d+):(%x+):(.*)%]")
            if not version then
                error("Invalid ULC format")
            end
            
            return json.encode({
                version = version,
                message_id = msg_id,
                payload = payload
            })
        end
    }
end

-- 执行协议转换
function ProtocolBridge:convert(data, from_protocol, to_protocol)
    local key = from_protocol .. "_to_" .. to_protocol
    
    -- 查找转换器
    if self.converters[key] then
        return self.converters[key](data)
    end
    
    -- 检查是否需要创建新的转换
    if from_protocol == "tcp" and to_protocol == "rs485" then
        local bridge = self:tcp_rs485_bridge()
        self.converters[key] = bridge.tcp_to_rs485
        return self.converters[key](data)
    end
    
    if from_protocol == "rs485" and to_protocol == "tcp" then
        local bridge = self:tcp_rs485_bridge()
        self.converters[key] = bridge.rs485_to_tcp
        return self.converters[key](data)
    end
    
    if from_protocol == "tcp" and to_protocol == "ble" then
        local bridge = self:tcp_ble_bridge()
        self.converters[key] = bridge.tcp_to_ble
        return self.converters[key](data)
    end
    
    if from_protocol == "ble" and to_protocol == "tcp" then
        local bridge = self:tcp_ble_bridge()
        self.converters[key] = bridge.ble_to_tcp
        return self.converters[key](data)
    end
    
    if from_protocol == "rs485" and to_protocol == "ble" then
        local bridge = self:rs485_ble_bridge()
        self.converters[key] = bridge.rs485_to_ble
        return self.converters[key](data)
    end
    
    if from_protocol == "ble" and to_protocol == "rs485" then
        local bridge = self:rs485_ble_bridge()
        self.converters[key] = bridge.ble_to_rs485
        return self.converters[key](data)
    end
    
    if from_protocol == "tcp" and to_protocol == "ulc" then
        local bridge = self:tcp_ulc_bridge()
        self.converters[key] = bridge.tcp_to_ulc
        return self.converters[key](data)
    end
    
    if from_protocol == "ulc" and to_protocol == "tcp" then
        local bridge = self:tcp_ulc_bridge()
        self.converters[key] = bridge.ulc_to_tcp
        return self.converters[key](data)
    end
    
    -- 如果两个协议相同，直接返回
    if from_protocol == to_protocol then
        return data
    end
    
    error(string.format("No conversion available from %s to %s", 
          from_protocol, to_protocol))
end

return ProtocolBridge
