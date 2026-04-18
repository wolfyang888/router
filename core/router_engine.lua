-- core/router_engine.lua
local logger = require("utils.logger")
local LinkMetrics = require("core.link_metrics")

local RouterEngine = {}
RouterEngine.__index = RouterEngine

function RouterEngine.new()
    local self = setmetatable({}, RouterEngine)
    self.rules = {}
    self.interfaces = {}
    self.adapters = {}
    self.metrics = {}
    self.active_routes = {}
    self.probe_threads = {}
    self.routing_strategies = {
        default = function(self, device_id, src_subnet, dst_subnet)
            return self:select_best_interface(device_id, src_subnet, dst_subnet)
        end,
        
        quality_based = function(self, device_id, src_subnet, dst_subnet)
            local matching_rules = {}
            
            for _, rule in ipairs(self.rules) do
                if rule.enabled and 
                   rule.device_id == device_id and
                   self:subnet_match(src_subnet, rule.source_subnet) and
                   self:subnet_match(dst_subnet, rule.target_subnet) then
                    table.insert(matching_rules, rule)
                end
            end
            
            if #matching_rules == 0 then
                return nil
            end
            
            local best_interface = nil
            local best_quality = 0
            
            for _, rule in ipairs(matching_rules) do
                for _, interface_name in ipairs(rule.interfaces) do
                    local interface = self.interfaces[interface_name]
                    if interface then
                        local status = interface:get_status()
                        if status.status == "connected" then
                            local metrics = self.metrics[interface_name]
                            local quality = metrics:calculate_quality()
                            
                            if quality > best_quality then
                                best_quality = quality
                                best_interface = interface_name
                            end
                        end
                    end
                end
            end
            
            if best_interface then
                self.active_routes[device_id] = best_interface
            end
            
            return best_interface
        end,
        
        load_balanced = function(self, device_id, src_subnet, dst_subnet)
            local matching_rules = {}
            
            for _, rule in ipairs(self.rules) do
                if rule.enabled and 
                   rule.device_id == device_id and
                   self:subnet_match(src_subnet, rule.source_subnet) and
                   self:subnet_match(dst_subnet, rule.target_subnet) then
                    table.insert(matching_rules, rule)
                end
            end
            
            if #matching_rules == 0 then
                return nil
            end
            
            local available_interfaces = {}
            
            for _, rule in ipairs(matching_rules) do
                for _, interface_name in ipairs(rule.interfaces) do
                    local interface = self.interfaces[interface_name]
                    if interface then
                        local status = interface:get_status()
                        if status.status == "connected" then
                            table.insert(available_interfaces, interface_name)
                        end
                    end
                end
            end
            
            if #available_interfaces == 0 then
                return nil
            end
            
            local selected_interface = available_interfaces[math.random(1, #available_interfaces)]
            self.active_routes[device_id] = selected_interface
            return selected_interface
        end
    }
    self.current_strategy = "default"
    return self
end

function RouterEngine:register_interface(name, interface, adapter)
    self.interfaces[name] = interface
    self.adapters[name] = adapter
    self.metrics[name] = LinkMetrics.new()
    logger.info(string.format("Interface registered: %s", name))
end

function RouterEngine:probe_route(interface_name, test_message)
    local interface = self.interfaces[interface_name]
    local adapter = self.adapters[interface_name]
    local metrics = self.metrics[interface_name]
    
    if not interface or not adapter then
        return false, "Interface not found"
    end
    
    local status = interface:get_status()
    if status.status ~= "connected" then
        return false, "Interface not connected"
    end
    
    local start_time = os.time()
    local result = adapter:send_message(test_message)
    local end_time = os.time()
    
    local latency = (end_time - start_time) * 1000 -- 转换为毫秒
    
    if result then
        metrics:record_success(latency)
        logger.debug(string.format("Route probe successful: %s (latency: %.1fms)", interface_name, latency))
        return true, latency
    else
        metrics:record_failure()
        logger.debug(string.format("Route probe failed: %s", interface_name))
        return false, 0
    end
end

function RouterEngine:probe_all_routes(test_message)
    local results = {}
    
    for interface_name, interface in pairs(self.interfaces) do
        local success, latency = self:probe_route(interface_name, test_message)
        results[interface_name] = { success = success, latency = latency }
    end
    
    return results
end

function RouterEngine:add_routing_rule(rule)
    table.insert(self.rules, rule)
    table.sort(self.rules, function(a, b)
        return a.priority > b.priority
    end)
    logger.info(string.format("Routing rule added: %s (priority: %d)", 
        rule.name, rule.priority))
end

function RouterEngine:select_best_interface(device_id, src_subnet, dst_subnet)
    local matching_rules = {}
    
    for _, rule in ipairs(self.rules) do
        if rule.enabled and 
           rule.device_id == device_id and
           self:subnet_match(src_subnet, rule.source_subnet) and
           self:subnet_match(dst_subnet, rule.target_subnet) then
            table.insert(matching_rules, rule)
        end
    end
    
    if #matching_rules == 0 then
        return nil
    end
    
    local selected_interface = nil
    
    for _, rule in ipairs(matching_rules) do
        for _, interface_name in ipairs(rule.interfaces) do
            local interface = self.interfaces[interface_name]
            
            if not interface then
                goto continue
            end
            
            local status = interface:get_status()
            if status.status ~= "connected" then
                goto continue
            end
            
            local metrics = self.metrics[interface_name]
            local quality = metrics:calculate_quality()
            
            if quality >= LinkMetrics.Quality.FAIR then
                selected_interface = interface_name
                break
            end
            
            ::continue::
        end
        
        if selected_interface then
            break
        end
    end
    
    if selected_interface then
        self.active_routes[device_id] = selected_interface
    end
    
    return selected_interface
end

function RouterEngine:subnet_match(ip, subnet)
    if subnet == "0.0.0.0/0" then
        return true
    end
    
    local ip_parts = {}
    for part in string.gmatch(ip, "(%d+)") do
        table.insert(ip_parts, tonumber(part))
    end
    
    local subnet_parts = {}
    local subnet_ip, prefix = subnet:match("([^/]+)/(%d+)")
    if not subnet_ip or not prefix then
        return string.find(ip, subnet) ~= nil
    end
    
    for part in string.gmatch(subnet_ip, "(%d+)") do
        table.insert(subnet_parts, tonumber(part))
    end
    
    local prefix = tonumber(prefix)
    for i = 1, math.floor(prefix / 8) do
        if ip_parts[i] ~= subnet_parts[i] then
            return false
        end
    end
    
    local remaining_bits = prefix % 8
    if remaining_bits > 0 then
        local mask = 256 - (2 ^ (8 - remaining_bits))
        if (ip_parts[math.floor(prefix / 8) + 1] or 0) & mask ~= (subnet_parts[math.floor(prefix / 8) + 1] or 0) & mask then
            return false
        end
    end
    
    return true
end

function RouterEngine:set_routing_strategy(strategy_name)
    if self.routing_strategies[strategy_name] then
        self.current_strategy = strategy_name
        logger.info(string.format("Routing strategy set to: %s", strategy_name))
        return true
    else
        logger.error(string.format("Unknown routing strategy: %s", strategy_name))
        return false
    end
end

function RouterEngine:get_routing_strategy()
    return self.current_strategy
end

function RouterEngine:add_custom_strategy(name, strategy_func)
    if type(strategy_func) == "function" then
        self.routing_strategies[name] = strategy_func
        logger.info(string.format("Custom routing strategy added: %s", name))
        return true
    else
        logger.error("Custom strategy must be a function")
        return false
    end
end

function RouterEngine:send_with_routing(message, device_id, 
                                       src_subnet, dst_subnet, 
                                       retry_on_fail)
    retry_on_fail = retry_on_fail ~= false
    
    local strategy = self.routing_strategies[self.current_strategy]
    local interface_name = strategy(self, device_id, src_subnet, dst_subnet)
    
    if not interface_name then
        logger.warn(string.format("No available route for device: %s", device_id))
        return false
    end
    
    local adapter = self.adapters[interface_name]
    local interface = self.interfaces[interface_name]
    local metrics = self.metrics[interface_name]
    
    local result = adapter:send_message(message)
    
    if result then
        metrics:record_success(0)
        logger.debug(string.format(
            "Message sent via %s to device %s", interface_name, device_id))
        return true
    else
        metrics:record_failure()
        
        if retry_on_fail then
            return self:failover_send(message, device_id, src_subnet, dst_subnet)
        end
        
        return false
    end
end

function RouterEngine:failover_send(message, device_id, src_subnet, dst_subnet)
    local current_interface = self.active_routes[device_id]
    
    for interface_name, interface in pairs(self.interfaces) do
        if interface_name ~= current_interface then
            local status = interface:get_status()
            
            if status.status == "connected" then
                local adapter = self.adapters[interface_name]
                local result = adapter:send_message(message)
                
                if result then
                    self.active_routes[device_id] = interface_name
                    logger.info(string.format(
                        "Failover: device %s switched to %s",
                        device_id, interface_name))
                    return true
                end
            end
        end
    end
    
    return false
end

function RouterEngine:get_routing_status()
    local status = {
        interfaces = {},
        active_routes = self.active_routes,
        rules = {}
    }
    
    for name, interface in pairs(self.interfaces) do
        local metrics = self.metrics[name]
        status.interfaces[name] = {
            status = interface:get_status(),
            metrics = metrics:to_table()
        }
    end
    
    for _, rule in ipairs(self.rules) do
        table.insert(status.rules, {
            name = rule.name,
            priority = rule.priority,
            enabled = rule.enabled,
            interfaces = rule.interfaces
        })
    end
    
    return status
end



-- ============================================
-- 多设备支持扩展
-- ============================================

-- 设备地址解析
function RouterEngine:parse_device_address(addr_str)
    -- 格式: "device_id:protocol:port[:channel]"
    local parts = {}
    for part in string.gmatch(addr_str, "[^:]+") do
        table.insert(parts, part)
    end
    
    return {
        device_id = parts[1],
        protocol = parts[2],
        port = parts[3],
        channel = parts[4],
        full_addr = addr_str
    }
end

-- 注册多设备拓扑
function RouterEngine:register_device_topology(topology_config)
    self.topology = topology_config
    self.devices = {}
    self.device_interfaces = {}
    
    for _, device in ipairs(topology_config.devices or {}) do
        self.devices[device.device_id] = device
        self.device_interfaces[device.device_id] = {}
        
        for _, iface in ipairs(device.interfaces or {}) do
            local addr = device.device_id .. ":" .. iface.type .. ":" .. iface.port
            self.device_interfaces[device.device_id][iface.type] = {
                address = addr,
                config = iface,
                priority = iface.priority or 50
            }
        end
    end
end

-- 检查两设备是否直接连通
function RouterEngine:is_directly_connected(device_a, device_b)
    local dev_a = self.devices[device_a]
    local dev_b = self.devices[device_b]
    
    if not dev_a or not dev_b then
        return false
    end
    
    -- 检查是否共享协议
    for proto_a, _ in pairs(self.device_interfaces[device_a]) do
        for proto_b, _ in pairs(self.device_interfaces[device_b]) do
            if proto_a == proto_b then
                return true
            end
        end
    end
    
    return false
end

-- 发现设备间的路由路径 (BFS)
function RouterEngine:discover_device_path(src_device, dst_device, visited, depth)
    depth = depth or 0
    visited = visited or {}
    
    if depth > 10 then
        return nil
    end
    
    -- 直接连接
    if self:is_directly_connected(src_device, dst_device) then
        return {{from=src_device, to=dst_device}}
    end
    
    visited[src_device] = true
    local best_path = nil
    
    -- 遍历所有中继设备
    for relay_id, relay_device in pairs(self.devices) do
        if not visited[relay_id] and relay_device.is_relay then
            if self:is_directly_connected(src_device, relay_id) then
                local sub_path = self:discover_device_path(
                    relay_id, dst_device, visited, depth + 1
                )
                
                if sub_path then
                    local path = {{from=src_device, to=relay_id}}
                    for _, hop in ipairs(sub_path) do
                        table.insert(path, hop)
                    end
                    
                    if not best_path or #path < #best_path then
                        best_path = path
                    end
                end
            end
        end
    end
    
    visited[src_device] = false
    return best_path
end

-- 为路径选择具体的接口和协议
function RouterEngine:materialize_path(path)
    local materialized = {}
    
    for _, hop in ipairs(path) do
        local from_dev = self.devices[hop.from]
        local to_dev = self.devices[hop.to]
        
        -- 选择共享的协议
        local selected_protocol = nil
        
        for proto_from, _ in pairs(self.device_interfaces[hop.from]) do
            if self.device_interfaces[hop.to][proto_from] then
                selected_protocol = proto_from
                break
            end
        end
        
        if selected_protocol then
            table.insert(materialized, {
                from = hop.from,
                to = hop.to,
                src_addr = hop.from .. ":" .. selected_protocol .. ":" ..
                    self.device_interfaces[hop.from][selected_protocol].config.port,
                dst_addr = hop.to .. ":" .. selected_protocol .. ":" ..
                    self.device_interfaces[hop.to][selected_protocol].config.port,
                protocol = selected_protocol
            })
        end
    end
    
    return materialized
end

-- 转发消息到指定设备
function RouterEngine:forward_to_device(message, src_device, dst_device)
    if not self.topology then
        return false
    end
    
    -- 发现路径
    local path = self:discover_device_path(src_device, dst_device)
    if not path then
        logger.warn(string.format("No path found from %s to %s", src_device, dst_device))
        return false
    end
    
    -- 具体化路径
    local materialized = self:materialize_path(path)
    if #materialized == 0 then
        logger.warn("No valid interface path found")
        return false
    end
    
    -- 记录路由路径
    message.device_path = path
    message.interface_path = materialized
    
    -- 发送给第一跳
    if #materialized > 0 then
        local first_hop = materialized[1]
        logger.info(string.format(
            "Forwarding message: %s -> %s via %s",
            first_hop.src_addr, first_hop.dst_addr, first_hop.protocol
        ))
        return true
    end
    
    return false
end


-- ============================================
-- 多设备支持扩展
-- ============================================

-- 设备地址解析
function RouterEngine:parse_device_address(addr_str)
    -- 格式: "device_id:protocol:port[:channel]"
    local parts = {}
    for part in string.gmatch(addr_str, "[^:]+") do
        table.insert(parts, part)
    end
    
    return {
        device_id = parts[1],
        protocol = parts[2],
        port = parts[3],
        channel = parts[4],
        full_addr = addr_str
    }
end

-- 注册多设备拓扑
function RouterEngine:register_device_topology(topology_config)
    self.topology = topology_config
    self.devices = {}
    self.device_interfaces = {}
    
    for _, device in ipairs(topology_config.devices or {}) do
        self.devices[device.device_id] = device
        self.device_interfaces[device.device_id] = {}
        
        for _, iface in ipairs(device.interfaces or {}) do
            local addr = device.device_id .. ":" .. iface.type .. ":" .. iface.port
            self.device_interfaces[device.device_id][iface.type] = {
                address = addr,
                config = iface,
                priority = iface.priority or 50
            }
        end
    end
end

-- 检查两设备是否直接连通
function RouterEngine:is_directly_connected(device_a, device_b)
    local dev_a = self.devices[device_a]
    local dev_b = self.devices[device_b]
    
    if not dev_a or not dev_b then
        return false
    end
    
    -- 检查是否共享协议
    for proto_a, _ in pairs(self.device_interfaces[device_a]) do
        for proto_b, _ in pairs(self.device_interfaces[device_b]) do
            if proto_a == proto_b then
                return true
            end
        end
    end
    
    return false
end

-- 发现设备间的路由路径 (BFS)
function RouterEngine:discover_device_path(src_device, dst_device, visited, depth)
    depth = depth or 0
    visited = visited or {}
    
    if depth > 10 then
        return nil
    end
    
    -- 直接连接
    if self:is_directly_connected(src_device, dst_device) then
        return {{from=src_device, to=dst_device}}
    end
    
    visited[src_device] = true
    local best_path = nil
    
    -- 遍历所有中继设备
    for relay_id, relay_device in pairs(self.devices) do
        if not visited[relay_id] and relay_device.is_relay then
            if self:is_directly_connected(src_device, relay_id) then
                local sub_path = self:discover_device_path(
                    relay_id, dst_device, visited, depth + 1
                )
                
                if sub_path then
                    local path = {{from=src_device, to=relay_id}}
                    for _, hop in ipairs(sub_path) do
                        table.insert(path, hop)
                    end
                    
                    if not best_path or #path < #best_path then
                        best_path = path
                    end
                end
            end
        end
    end
    
    visited[src_device] = false
    return best_path
end

-- 为路径选择具体的接口和协议
function RouterEngine:materialize_path(path)
    local materialized = {}
    
    for _, hop in ipairs(path) do
        local from_dev = self.devices[hop.from]
        local to_dev = self.devices[hop.to]
        
        -- 选择共享的协议
        local selected_protocol = nil
        
        for proto_from, _ in pairs(self.device_interfaces[hop.from]) do
            if self.device_interfaces[hop.to][proto_from] then
                selected_protocol = proto_from
                break
            end
        end
        
        if selected_protocol then
            table.insert(materialized, {
                from = hop.from,
                to = hop.to,
                src_addr = hop.from .. ":" .. selected_protocol .. ":" ..
                    self.device_interfaces[hop.from][selected_protocol].config.port,
                dst_addr = hop.to .. ":" .. selected_protocol .. ":" ..
                    self.device_interfaces[hop.to][selected_protocol].config.port,
                protocol = selected_protocol
            })
        end
    end
    
    return materialized
end

-- 转发消息到指定设备
function RouterEngine:forward_to_device(message, src_device, dst_device)
    if not self.topology then
        return false
    end
    
    -- 发现路径
    local path = self:discover_device_path(src_device, dst_device)
    if not path then
        logger.warn(string.format("No path found from %s to %s", src_device, dst_device))
        return false
    end
    
    -- 具体化路径
    local materialized = self:materialize_path(path)
    if #materialized == 0 then
        logger.warn("No valid interface path found")
        return false
    end
    
    -- 记录路由路径
    message.device_path = path
    message.interface_path = materialized
    
    -- 发送给第一跳
    if #materialized > 0 then
        local first_hop = materialized[1]
        logger.info(string.format(
            "Forwarding message: %s -> %s via %s",
            first_hop.src_addr, first_hop.dst_addr, first_hop.protocol
        ))
        return true
    end
    
    return false
end

-- 注册设备
function RouterEngine:register_device(device_id, interfaces)
    if not self.devices then
        self.devices = {}
    end
    if not self.device_interfaces then
        self.device_interfaces = {}
    end
    
    self.devices[device_id] = {
        device_id = device_id,
        is_relay = true,  -- 默认所有设备都可以作为中继
        interfaces = interfaces
    }
    
    self.device_interfaces[device_id] = {}
    
    for _, iface in ipairs(interfaces or {}) do
        local addr = device_id .. ":" .. iface.type .. ":" .. (iface.port or "")
        self.device_interfaces[device_id][iface.type] = {
            address = addr,
            config = iface,
            priority = iface.priority or 50
        }
    end
    
    logger.info("Device registered: " .. device_id)
    return true
end

-- 注销设备
function RouterEngine:unregister_device(device_id)
    if self.devices[device_id] then
        self.devices[device_id] = nil
        self.device_interfaces[device_id] = nil
        logger.info("Device unregistered: " .. device_id)
        return true
    end
    return false
end

-- 获取已注册的设备列表
function RouterEngine:get_registered_devices()
    local devices = {}
    for device_id, device_info in pairs(self.devices or {}) do
        table.insert(devices, {
            device_id = device_id,
            interfaces = device_info.interfaces or {},
            is_relay = device_info.is_relay
        })
    end
    return devices
end

return RouterEngine