-- gateway.lua
#!/usr/bin/env lua

local json = nil
local success, json_lib = pcall(require, "cjson")
if success then
    json = json_lib
else
    -- 当cjson库不可用时，使用简单的序列化方式
    json = {
        encode = function(data)
            return tostring(data)
        end,
        decode = function(data)
            return data
        end
    }
end
local config = require("config")
local logger = require("utils.logger")
local RouterEngine = require("core.router_engine")

-- Interfaces
local TCPInterface = require("interfaces.tcp_interface")
local RS485Interface = require("interfaces.rs485_interface")
local BLEInterface = require("interfaces.ble_interface")
local CANInterface = require("interfaces.can_interface")
local CustomInterface = require("interfaces.custom_interface")

-- Adapters
local MQTTAdapter = require("adapters.mqtt_adapter")
local TCPProtocolAdapter = require("adapters.tcp_protocol_adapter")
local ModbusAdapter = require("adapters.modbus_adapter")
local CustomProtocolAdapter = require("adapters.custom_protocol_adapter")

local HybridGateway = {}
HybridGateway.__index = HybridGateway

function HybridGateway.new(config_file)
    local self = setmetatable({}, HybridGateway)
    self.config = require(config_file:match("([^/]+)%.lua$"))
    self.router_engine = RouterEngine.new()
    self.running = false
    self.message_queue = {}
    self.receive_threads = {}
    return self
end

function HybridGateway:initialize()
    logger.info("=== Hybrid Gateway Initializing ===")
    
    for _, interface_cfg in ipairs(self.config.interfaces) do
        if interface_cfg.enabled then
            self:init_interface(interface_cfg)
        end
    end
    
    for _, rule_cfg in ipairs(self.config.routing_rules) do
        self.router_engine:add_routing_rule(rule_cfg)
    end
    
    -- 启动接收线程
    self:start_receive_threads()
    
    logger.info("=== Gateway Initialized ===")
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
    
    logger.info(string.format("Initializing interface: %s (%s)", name, interface_type))
    
    local interface, adapter
    
    if interface_type == "tcp" then
        interface = TCPInterface.new(name, interface_cfg)
        adapter = TCPProtocolAdapter.new(interface)
    elseif interface_type == "rs485" then
        interface = RS485Interface.new(name, interface_cfg)
        adapter = ModbusAdapter.new(interface)
    elseif interface_type == "ble" then
        interface = BLEInterface.new(name, interface_cfg)
        adapter = MQTTAdapter.new(interface,
            self.config.adapters.mqtt.broker,
            self.config.adapters.mqtt.client_id)
    elseif interface_type == "can" then
        interface = CANInterface.new(name, interface_cfg)
        adapter = MQTTAdapter.new(interface, "", "")
    elseif interface_type == "custom" then
        interface = CustomInterface.new(name, interface_cfg)
        adapter = CustomProtocolAdapter.new(interface, interface_cfg.protocol_config)
    else
        logger.error("Unknown interface type: " .. interface_type)
        return
    end
    
    if interface:connect() then
        self.router_engine:register_interface(name, interface, adapter)
        logger.info(string.format("Interface %s connected successfully", name))
    else
        logger.error(string.format("Failed to connect interface: %s", name))
    end
end

function HybridGateway:handle_message(device_id, message)
    local src_subnet = message.src_subnet or "0.0.0.0/0"
    local dst_subnet = message.dst_subnet or "0.0.0.0/0"
    
    local result = self.router_engine:send_with_routing(
        message.data, device_id, src_subnet, dst_subnet, true
    )
    
    if result then
        logger.debug(string.format(
            "Message routed successfully for device: %s", device_id))
    else
        logger.warn(string.format(
            "Failed to route message for device: %s", device_id))
    end
    
    return result
end

function HybridGateway:run()
    self.running = true
    logger.info("Gateway running...")
    
    while self.running do
        -- 调度接收线程
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
        logger.info("=== Router Status ===")
        local status = self.router_engine:get_routing_status()
        for name, iface_status in pairs(status.interfaces) do
            local metrics = iface_status.metrics
            logger.info(string.format(
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
        
        logger.debug(string.format("Received message from %s: %s", interface_name, tostring(message)))
        
        -- 处理接收到的消息，根据需要进行路由
        local device_id = message.device_id or "unknown"
        local response = self:handle_incoming_message(device_id, message, interface_name)
        
        if response then
            logger.debug(string.format("Sending response to %s", interface_name))
            local adapter = self.router_engine.adapters[interface_name]
            if adapter then
                adapter:send_message(response)
            end
        end
    end
end

function HybridGateway:handle_incoming_message(device_id, message, interface_name)
    -- 处理接收到的消息
    -- 这里可以根据消息类型和内容进行不同的处理
    logger.debug(string.format("Handling message from device %s via %s", device_id, interface_name))
    
    -- 示例：如果是请求消息，返回响应
    if message.type == "request" then
        return {
            type = "response",
            device_id = device_id,
            timestamp = os.time(),
            data = "ACK"
        }
    end
    
    return nil
end

function HybridGateway:stop()
    logger.info("Stopping gateway...")
    self.running = false
end

local function main()
    local gateway = HybridGateway.new("config")
    gateway:initialize()
    gateway:run()
end

if arg[0]:find("gateway%.lua$") then
    main()
end

return HybridGateway
