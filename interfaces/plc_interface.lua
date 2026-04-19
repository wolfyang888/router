-- interfaces/plc_interface.lua
-- PLC (Programmable Logic Controller) 接口类型
-- 实现PLC设备的通信接口，支持任意路由

local BaseInterface = require("interfaces.base_interface")
local log = require("utils.logger")

local PLCInterface = setmetatable({}, BaseInterface)
PLCInterface.__index = PLCInterface

function PLCInterface.new(name, config)
    log.info("[PLCInterface.new] Entry - name: " .. tostring(name))
    local self = BaseInterface.new(name, config)
    setmetatable(self, PLCInterface)
    self.type = "plc"
    self.protocol = config.protocol or "plc"
    self.address = config.address or "localhost"
    self.port = config.port or 8888
    log.info("[PLCInterface.new] Exit - created PLC interface: " .. self.name)
    return self
end

function PLCInterface:get_status()
    log.debug("[PLCInterface.get_status] Entry - interface: " .. self.name)
    local status = {
        type = self.type,
        name = self.name,
        status = self.status,
        error = self.error_msg,
        address = self.address,
        port = self.port,
        protocol = self.protocol
    }
    log.debug("[PLCInterface.get_status] Exit - status: " .. status.status)
    return status
end

function PLCInterface:scan_devices()
    log.info("[PLCInterface.scan_devices] Entry - interface: " .. self.name)
    log.info("Scanning PLC devices on " .. self.name)
    
    -- 通过协议适配器发送发现请求
    if self.adapter and self.adapter.send_message then
        local discovery_message = {
            type = "discovery",
            command = "scan",
            timestamp = os.time()
        }
        log.info("[PLCInterface.scan_devices] Sending discovery request")
        self.adapter:send_message(discovery_message)
    end
    
    -- 模拟 PLC 设备发现
    local devices = {
        {
            id = "plc_device_" .. self.name,
            name = "PLC Controller",
            type = "plc",
            interfaces = {"plc"},
            address = self.address,
            port = self.port
        },
        {
            id = "hmi_device_" .. self.name,
            name = "HMI Panel",
            type = "hmi",
            interfaces = {"plc"},
            address = self.address,
            port = self.port + 1
        }
    }
    log.info("[PLCInterface.scan_devices] Exit - found " .. #devices .. " devices")
    return devices
end

return PLCInterface