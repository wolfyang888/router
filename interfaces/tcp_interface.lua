-- interfaces/tcp_interface.lua
local uv, is_windows = require("platform")
local BaseInterface = require("interfaces.base_interface")
local log = require("utils.logger")

local TCPInterface = setmetatable({}, BaseInterface)
TCPInterface.__index = TCPInterface

function TCPInterface.new(name, config)
    log.info("[TCPInterface.new] Entry - name: " .. tostring(name))
    local self = BaseInterface.new(name, config)
    setmetatable(self, TCPInterface)
    self.type = "tcp"
    self.socket = nil
    log.info("[TCPInterface.new] Exit - created TCP interface: " .. self.name)
    return self
end

function TCPInterface:connect()
    log.info("[TCPInterface.connect] Entry - interface: " .. self.name)
    local host = self.config.host or "localhost"
    local port = self.config.port or 8888
    local timeout = self.config.timeout or 10

    self.socket = uv.new_tcp()

    local success, err = pcall(function()
        self.socket:connect(host, port, function(err)
            if err then
                self.status = "error"
                self.error_msg = err
            else
                self.status = "connected"
            end
        end)
    end)

    if not success then
        self.status = "error"
        self.error_msg = tostring(err)
        log.error("[TCPInterface.connect] Connection failed - interface: " .. self.name .. ", error: " .. tostring(err))
        log.info("[TCPInterface.connect] Exit - failed")
        return false
    end

    log.info("[TCPInterface.connect] Exit - connected to " .. host .. ":" .. port)
    return true
end

function TCPInterface:disconnect()
    log.info("[TCPInterface.disconnect] Entry - interface: " .. self.name)
    if self.socket then
        self.socket:close()
        self.status = "disconnected"
        log.info("[TCPInterface.disconnect] Exit - disconnected")
        return true
    end
    log.info("[TCPInterface.disconnect] Exit - no socket to close")
    return false
end

function TCPInterface:scan_devices()
    log.info("[TCPInterface.scan_devices] Entry - interface: " .. self.name)
    log.info("Scanning TCP devices on " .. self.name)
    
    -- 通过协议适配器发送发现请求
    if self.adapter and self.adapter.send_message then
        local discovery_message = {
            type = "discovery",
            command = "scan",
            timestamp = os.time()
        }
        log.info("[TCPInterface.scan_devices] Sending discovery request")
        self.adapter:send_message(discovery_message)
    end
    
    -- 模拟 TCP 设备发现
    local devices = {
        {
            id = "tcp_device_" .. self.name,
            name = "TCP Device",
            type = "tcp",
            interfaces = {"tcp"},
            host = self.config.host or "localhost",
            port = self.config.port or 8888
        },
        {
            id = "network_device_" .. self.name,
            name = "Network Device",
            type = "network",
            interfaces = {"tcp"},
            host = self.config.host or "localhost",
            port = (self.config.port or 8888) + 1
        }
    }
    log.info("[TCPInterface.scan_devices] Exit - found " .. #devices .. " devices")
    return devices
end

function TCPInterface:send(data, timeout)
    log.debug("[TCPInterface.send] Entry - interface: " .. self.name .. ", data length: " .. #data)
    if not self.socket then
        self.status = "error"
        log.error("[TCPInterface.send] No socket available - interface: " .. self.name)
        log.debug("[TCPInterface.send] Exit - failed")
        return false
    end

    local success, err = pcall(function()
        self.socket:write(data, function(err)
            if err then
                self.status = "error"
                self.error_msg = err
            end
        end)
    end)

    if not success then
        self.status = "error"
        self.error_msg = tostring(err)
        log.error("[TCPInterface.send] Send failed - interface: " .. self.name .. ", error: " .. tostring(err))
        log.debug("[TCPInterface.send] Exit - failed")
        return false
    end

    log.debug("[TCPInterface.send] Exit - sent " .. #data .. " bytes")
    return true
end

function TCPInterface:receive(timeout)
    log.debug("[TCPInterface.receive] Entry - interface: " .. self.name)
    if not self.socket then
        self.status = "error"
        log.error("[TCPInterface.receive] No socket available - interface: " .. self.name)
        log.debug("[TCPInterface.receive] Exit - failed")
        return nil
    end

    self.receive_buffer = ""

    pcall(function()
        self.socket:read_start(function(err, data)
            if err then
                self.status = "error"
                self.error_msg = err
            elseif data then
                self.receive_buffer = self.receive_buffer .. data
            end
        end)
    end)

    log.debug("[TCPInterface.receive] Exit - received " .. #self.receive_buffer .. " bytes")
    return ""
end

return TCPInterface