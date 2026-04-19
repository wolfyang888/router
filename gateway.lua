-- gateway.lua
local config = require("config")
local RouterEngine = require("core.router_engine")
local platform = require("platform")
local Error = require("utils.error")
local log = require("utils.logger")

local json = nil
local success, json_lib = pcall(require, "cjson")
if success then
    json = json_lib
else
    json = {
        encode = function(data)
            return tostring(data)
        end,
        decode = function(data)
            return data
        end
    }
end

local InterfaceFactory = {
    tcp = require("interfaces.tcp_interface"),
    rs485 = require("interfaces.rs485_interface"),
    ble = require("interfaces.ble_interface"),
    can = require("interfaces.can_interface"),
    plc = require("interfaces.plc_interface"),
    custom = require("interfaces.custom_interface"),
}

local AdapterFactory = {
    tcp = require("adapters.tcp_protocol_adapter"),
    rs485 = require("adapters.modbus_adapter"),
    ble = require("adapters.mqtt_adapter"),
    can = require("adapters.mqtt_adapter"),
    plc = require("adapters.plc_protocol_adapter"),
    custom = require("adapters.custom_protocol_adapter"),
}

local HybridGateway = {}
HybridGateway.__index = HybridGateway

function HybridGateway.new()
    local self = setmetatable({}, HybridGateway)
    self.config = config
    self.router_engine = RouterEngine.new()
    self.running = false
    self.message_queue = {}
    self.receive_threads = {}
    return self
end

function HybridGateway:initialize()
    log.info("=== Hybrid Gateway Initializing ===")

    for _, interface_cfg in ipairs(self.config.interfaces) do
        if interface_cfg.enabled then
            self:init_interface(interface_cfg)
        end
    end

    for _, rule_cfg in ipairs(self.config.routing_rules) do
        self.router_engine:add_routing_rule(rule_cfg)
    end

    self:start_receive_threads()

    log.info("=== Gateway Initialized ===")
end

function HybridGateway:start_receive_threads()
    for name, interface in pairs(self.router_engine.interfaces) do
        local adapter = self.router_engine.adapters[name]
        if adapter then
            local thread = coroutine.create(function()
                while self.running do
                    local message = adapter:receive_message(1.0)
                    if message then
                        table.insert(self.message_queue, {
                            interface = name,
                            message = message
                        })
                    end
                    coroutine.yield()
                end
            end)
            self.receive_threads[name] = thread
        end
    end
end

function HybridGateway:init_interface(interface_cfg)
    local name = interface_cfg.name
    local interface_type = interface_cfg.type

    log.info(string.format("Initializing interface: %s (%s)", name, interface_type))

    local interface_class = InterfaceFactory[interface_type]
    local adapter_class = AdapterFactory[interface_type]

    if not interface_class or not adapter_class then
        log.error(Error.get_message(Error.INTERFACE_TYPE_UNKNOWN), "type: %s", interface_type)
        return
    end

    local interface = interface_class.new(name, interface_cfg)
    local adapter_config = self:get_adapter_config(interface_type, interface_cfg)
    local adapter = adapter_class.new(interface, adapter_config)

    if interface:connect() then
        self.router_engine:register_interface(name, interface, adapter)
        log.info(string.format("Interface %s connected successfully", name))
    else
        log.error(Error.get_message(Error.INTERFACE_CONNECT_FAILED), "interface: %s", name)
    end
end

function HybridGateway:get_adapter_config(interface_type, interface_cfg)
    if interface_type == "ble" then
        return self.config.adapters.mqtt.broker, self.config.adapters.mqtt.client_id
    elseif interface_type == "can" then
        return "", ""
    elseif interface_type == "tcp" then
        return interface_cfg.host or "", interface_cfg.port or ""
    elseif interface_type == "plc" then
        return interface_cfg.host or "", interface_cfg.port or ""
    elseif interface_type == "custom" then
        return interface_cfg.protocol_config
    end
    return nil
end

function HybridGateway:handle_message(device_id, message)
    local src_subnet = message.src_subnet or "0.0.0.0/0"
    local dst_subnet = message.dst_subnet or "0.0.0.0/0"

    local result = self.router_engine:send_with_routing(
        message.data, device_id, src_subnet, dst_subnet, true
    )

    if result then
        log.debug(string.format(
            "Message routed successfully for device: %s", device_id))
    else
        log.error(Error.get_message(Error.NO_AVAILABLE_ROUTE), "device: %s", device_id)
    end

    return result
end

function HybridGateway:run()
    self.running = true
    log.info("Gateway running...")

    while self.running do
        for name, thread in pairs(self.receive_threads) do
            coroutine.resume(thread)
        end

        self:check_link_quality()
        self:process_message_queue()
        os.execute("sleep 0.1")
    end
end

function HybridGateway:check_link_quality()
    if not self.status_counter then
        self.status_counter = 0
    end

    self.status_counter = self.status_counter + 1

    if self.status_counter % 10 == 0 then
        log.info("=== Router Status ===")
        local status = self.router_engine:get_routing_status()
        for name, iface_status in pairs(status.interfaces) do
            local metrics = iface_status.metrics
            log.info(string.format(
                "%s: status=%s, latency=%.1fms, loss=%.2f%%, quality=%s",
                name,
                iface_status.status.status,
                metrics.latency_ms,
                metrics.packet_loss * 100,
                metrics.quality
            ))
        end
    end
end

function HybridGateway:process_message_queue()
    while #self.message_queue > 0 do
        local item = table.remove(self.message_queue, 1)
        local interface_name = item.interface
        local message = item.message

        log.debug(string.format("Received message from %s: %s", interface_name, tostring(message)))

        local device_id = message.device_id or "unknown"
        local response = self:handle_incoming_message(device_id, message, interface_name)

        if response then
            log.debug(string.format("Sending response to %s", interface_name))
            local adapter = self.router_engine.adapters[interface_name]
            if adapter then
                adapter:send_message(response)
            end
        end
    end
end

function HybridGateway:handle_incoming_message(device_id, message, interface_name)
    log.debug(string.format("Handling message from device %s via %s", device_id, interface_name))

    if message.type == "request" then
        return {
            type = "response",
            device_id = device_id,
            timestamp = os.time(),
            data = "ACK"
        }
    elseif message.type == "register" then
        return self:handle_register_message(device_id, message, interface_name)
    elseif message.type == "heartbeat" then
        return self:handle_heartbeat_message(device_id, message, interface_name)
    elseif message.type == "forward" then
        return self:handle_forward_message(device_id, message, interface_name)
    elseif message.type == "discover" then
        return self:handle_discover_message(device_id, message, interface_name)
    end

    return nil
end

function HybridGateway:handle_register_message(device_id, message, interface_name)
    local device_info = message.device_info
    if not device_info or not device_info.id then
        log.error(Error.get_message(Error.DEVICE_INFO_MISSING), "device: %s", device_id)
        return {
            type = "register_response",
            status = "error",
            message = "Missing device information"
        }
    end

    local success = self.router_engine:register_device(device_info.id, device_info.interfaces or {})
    if success then
        log.info("Device registered: " .. device_info.id)
        return {
            type = "register_response",
            status = "success",
            device_id = device_info.id
        }
    else
        log.error(Error.get_message(Error.DEVICE_REGISTER_FAILED), "device: %s", device_info.id)
        return {
            type = "register_response",
            status = "error",
            message = "Failed to register device"
        }
    end
end

function HybridGateway:handle_heartbeat_message(device_id, message, interface_name)
    log.debug(string.format("Heartbeat received from device: %s", device_id))
    return {
        type = "heartbeat_response",
        timestamp = os.time()
    }
end

function HybridGateway:handle_forward_message(device_id, message, interface_name)
    local source_device = message.source_device
    local target_device = message.target_device
    local forward_message = message.message

    if not source_device or not target_device or not forward_message then
        log.error(Error.get_message(Error.FORWARD_MESSAGE_INVALID), "device: %s", device_id)
        return {
            type = "forward_response",
            status = "error",
            message = "Invalid forward message format"
        }
    end

    local success, path = self.router_engine:forward_to_device(forward_message, source_device, target_device)

    if success then
        log.info("Message forwarded from " .. source_device .. " to " .. target_device)
        return {
            type = "forward_response",
            status = "success",
            path = path
        }
    else
        log.error(Error.get_message(Error.NO_PATH_FOUND), "%s -> %s", source_device, target_device)
        return {
            type = "forward_response",
            status = "error",
            message = "Failed to forward message"
        }
    end
end

function HybridGateway:handle_discover_message(device_id, message, interface_name)
    local devices = self.router_engine:get_registered_devices()
    
    -- 检查是否需要进行网络发现
    if message.discover_network then
        local target_interface = message.interface or interface_name
        local discovered_devices = self:discover_network(target_interface)
        devices = self.router_engine:get_registered_devices()
    end
    
    log.debug(string.format("Device discovery requested by: %s, found %d devices", device_id, #devices))
    return {
        type = "discover_response",
        devices = devices
    }
end

function HybridGateway:discover_network(interface_name)
    local discovered_devices = {}
    local seen_devices = {}  -- 用于去重
    local new_device_count = 0  -- 统计新发现的设备数量
    local interface = self.router_engine.interfaces[interface_name]
    
    if not interface then
        log.error(Error.get_message(Error.INTERFACE_NOT_FOUND), "interface: %s", interface_name)
        return discovered_devices
    end
    
    log.info(string.format("Starting network discovery on interface: %s", interface_name))
    
    -- 调用接口的扫描方法（需要在各接口实现）
    if interface.scan_devices then
        local devices = interface:scan_devices()
        for _, device in ipairs(devices) do
            if device.id then
                -- 检查设备是否已经注册过
                if not seen_devices[device.id] then
                    seen_devices[device.id] = true
                    
                    -- 检查设备是否已经在路由引擎中注册过
                    local already_registered = self.router_engine.devices and self.router_engine.devices[device.id]
                    
                    -- 注册发现的设备
                    local success = self.router_engine:register_device(device.id, device.interfaces or {})
                    if success then
                        table.insert(discovered_devices, device)
                        if not already_registered then
                            new_device_count = new_device_count + 1
                            log.info(string.format("Discovered and registered NEW device: %s", device.id))
                        else
                            log.debug(string.format("Device %s already registered, updating info", device.id))
                        end
                    end
                else
                    log.debug(string.format("Device %s already in current scan list, skipping", device.id))
                end
            end
        end
    else
        log.warn(string.format("Interface %s does not support device scanning", interface_name))
    end
    
    -- 构建拓扑
    self:build_topology_from_devices()
    
    log.info(string.format("Network discovery completed, found %d new devices, %d total devices in list", new_device_count, #discovered_devices))
    
    return discovered_devices
end

function HybridGateway:build_topology_from_devices()
    local devices = self.router_engine:get_registered_devices()
    local topology = { devices = {} }
    
    for _, device_info in ipairs(devices) do
        table.insert(topology.devices, device_info)
    end
    
    -- 注册拓扑
    self.router_engine.topology = topology
    log.info("Network topology built and registered")
end

function HybridGateway:stop()
    log.info("Stopping gateway...")
    self.running = false
end

local function main()
    local gateway = HybridGateway.new()
    gateway:initialize()
    gateway:run()
end

if arg[0]:find("gateway%.lua$") then
    main()
end

return HybridGateway
