-- 测试设备发现功能
local log = require("utils.logger")
local HybridGateway = require("gateway")
local config = require("config")

-- 模拟接口的 scan_devices 方法
local function mock_interface(name)
    return {
        name = name,
        get_status = function()
            return { status = "connected" }
        end,
        scan_devices = function()
            log.info(string.format("Scanning devices on interface: %s", name))
            -- 根据接口类型返回不同的设备
            if name == "tcp_subnet1" then
                -- TCP 接口发现的设备
                return {
                    {
                        id = "device_001",
                        name = "Temperature Sensor",
                        type = "sensor",
                        interfaces = {"tcp"}
                    },
                    {
                        id = "device_002",
                        name = "Light Controller",
                        type = "actuator",
                        interfaces = {"rs485"}
                    }
                }
            elseif name:find("plc") then
                -- PLC 接口发现的设备
                return {
                    {
                        id = "plc_device_001",
                        name = "Motor Controller",
                        type = "plc",
                        interfaces = {"plc"}
                    },
                    {
                        id = "plc_device_002",
                        name = "HMI Panel",
                        type = "hmi",
                        interfaces = {"plc"}
                    }
                }
            elseif name == "mixed_interface" then
                -- 混合接口：返回包含重复 ID 的设备列表
                return {
                    {
                        id = "device_001",  -- 重复 ID
                        name = "Temperature Sensor via Mixed",
                        type = "sensor",
                        interfaces = {"tcp", "plc"}
                    },
                    {
                        id = "plc_device_001",  -- 重复 ID
                        name = "Motor Controller via Mixed",
                        type = "plc",
                        interfaces = {"plc"}
                    },
                    {
                        id = "mixed_device_001",  -- 新的唯一 ID
                        name = "Mixed Device",
                        type = "mixed",
                        interfaces = {"tcp", "plc"}
                    }
                }
            else
                -- RS485 接口发现的设备（与 TCP 相同 ID）
                return {
                    {
                        id = "device_001",  -- 重复 ID
                        name = "RS485 Temperature Sensor",
                        type = "sensor",
                        interfaces = {"rs485"}
                    },
                    {
                        id = "device_002",  -- 重复 ID
                        name = "RS485 Light Controller",
                        type = "actuator",
                        interfaces = {"rs485"}
                    }
                }
            end
        end
    }
end

-- 模拟适配器
local function mock_adapter()
    return {
        receive_message = function()
            return nil
        end,
        send_message = function()
            return true
        end
    }
end

-- 测试函数
local function test_device_discovery()
    log.info("=== 开始测试设备发现功能 ===")
    
    -- 创建网关实例
    local gateway = HybridGateway:new()
    
    -- 初始化网关（不使用配置文件）
    gateway.running = false
    gateway.message_queue = {}
    gateway.interfaces = {}
    gateway.receive_threads = {}
    gateway.router_engine = require("core.router_engine"):new()
    
    log.info("网关初始化完成，开始测试设备发现")
    
    -- 注册模拟接口
    local tcp_interface = mock_interface("tcp_subnet1")
    local rs485_interface = mock_interface("rs485_subnet1")
    local plc_interface = mock_interface("plc_main")
    
    gateway.router_engine:register_interface("tcp_subnet1", tcp_interface, mock_adapter())
    gateway.router_engine:register_interface("rs485_subnet1", rs485_interface, mock_adapter())
    gateway.router_engine:register_interface("plc_main", plc_interface, mock_adapter())
    
    log.info("网关初始化完成，开始测试设备发现")
    
    -- 测试1: 基本发现（不进行网络发现）
    log.info("\n=== 测试1: 基本发现 ===")
    local basic_discover_msg = {
        type = "discover",
        device_id = "test_client"
    }
    
    local basic_response = gateway:handle_discover_message("test_client", basic_discover_msg, "tcp_subnet1")
    log.info("基本发现响应:", #basic_response.devices, "个设备")
    
    -- 测试2: TCP 接口网络发现
    log.info("\n=== 测试2: TCP 接口网络发现 ===")
    local tcp_discover_msg = {
        type = "discover",
        device_id = "test_client",
        discover_network = true,
        interface = "tcp_subnet1"
    }
    
    local tcp_response = gateway:handle_discover_message("test_client", tcp_discover_msg, "tcp_subnet1")
    log.info("TCP 网络发现响应:", #tcp_response.devices, "个设备")
    
    -- 测试3: RS485 接口网络发现
    log.info("\n=== 测试3: RS485 接口网络发现 ===")
    local rs485_discover_msg = {
        type = "discover",
        device_id = "test_client",
        discover_network = true,
        interface = "rs485_subnet1"
    }
    
    local rs485_response = gateway:handle_discover_message("test_client", rs485_discover_msg, "rs485_subnet1")
    log.info("RS485 网络发现响应:", #rs485_response.devices, "个设备")
    
    -- 测试4: 未指定接口的网络发现
    log.info("\n=== 测试4: 未指定接口的网络发现 ===")
    local auto_discover_msg = {
        type = "discover",
        device_id = "test_client",
        discover_network = true
    }
    
    local auto_response = gateway:handle_discover_message("test_client", auto_discover_msg, "tcp_subnet1")
    log.info("自动网络发现响应:", #auto_response.devices, "个设备")
    
    -- 测试5: 不存在的接口
    log.info("\n=== 测试5: 不存在的接口 ===")
    local invalid_discover_msg = {
        type = "discover",
        device_id = "test_client",
        discover_network = true,
        interface = "invalid_interface"
    }
    
    local invalid_response = gateway:handle_discover_message("test_client", invalid_discover_msg, "tcp_subnet1")
    log.info("无效接口发现响应:", #invalid_response.devices, "个设备")
    
    -- 测试6: PLC 接口网络发现
    log.info("\n=== 测试6: PLC 接口网络发现 ===")
    local plc_discover_msg = {
        type = "discover",
        device_id = "test_client",
        discover_network = true,
        interface = "plc_main"
    }
    
    local plc_response = gateway:handle_discover_message("test_client", plc_discover_msg, "plc_main")
    log.info("PLC 网络发现响应:", #plc_response.devices, "个设备")
    
    -- 测试7: 混合接口网络发现（重复 ID 测试）
    log.info("\n=== 测试7: 混合接口网络发现（重复 ID 去重测试）===")
    -- 先注册混合接口
    local mixed_interface = mock_interface("mixed_interface")
    gateway.router_engine:register_interface("mixed_interface", mixed_interface, mock_adapter())
    
    local mixed_discover_msg = {
        type = "discover",
        device_id = "test_client",
        discover_network = true,
        interface = "mixed_interface"
    }
    
    local mixed_response = gateway:handle_discover_message("test_client", mixed_discover_msg, "mixed_interface")
    log.info("混合接口网络发现响应:", #mixed_response.devices, "个设备")
    log.info("预期结果: 应只发现 1 个新设备 (mixed_device_001)，device_001 和 plc_device_001 已存在应被过滤")
    
    -- 测试8: 检查拓扑构建
    log.info("\n=== 测试8: 检查拓扑构建 ===")
    if gateway.router_engine.topology then
        log.info("拓扑构建成功，设备数量:", #gateway.router_engine.topology.devices)
        for _, device in ipairs(gateway.router_engine.topology.devices) do
            log.info("  设备:", device.device_id, "接口:", table.concat(device.interfaces, ","))
        end
    else
        log.warn("拓扑构建失败")
    end
    
    -- 停止网关
    gateway:stop()
    log.info("\n=== 设备发现测试完成 ===")
end

-- 运行测试
if arg[0]:find("test_device_discovery%.lua$") then
    test_device_discovery()
end

return {
    test_device_discovery = test_device_discovery
}