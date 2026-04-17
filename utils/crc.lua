-- utils/crc.lua
local crc = {}

-- CRC-16 (Modbus RTU)
function crc.calculate_crc16(data)
    local crc = 0xFFFF
    
    for i = 1, #data do
        local byte = string.byte(data, i)
        crc = bit32.bxor(crc, byte)
        
        for _ = 1, 8 do
            if bit32.band(crc, 1) == 1 then
                crc = bit32.rshift(crc, 1)
                crc = bit32.bxor(crc, 0xA001)
            else
                crc = bit32.rshift(crc, 1)
            end
        end
    end
    
    return crc
end

-- CRC-32
function crc.calculate_crc32(data)
    local crc = 0xFFFFFFFF
    
    for i = 1, #data do
        local byte = string.byte(data, i)
        crc = bit32.bxor(crc, byte)
        
        for _ = 1, 8 do
            if bit32.band(crc, 1) == 1 then
                crc = bit32.rshift(crc, 1)
                crc = bit32.bxor(crc, 0xEDB88320)
            else
                crc = bit32.rshift(crc, 1)
            end
        end
    end
    
    return bit32.bxor(crc, 0xFFFFFFFF)
end

return crc
