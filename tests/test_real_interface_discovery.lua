-- 测试真实接口的设备发现功能
-- 不使用 mock 接口，直接使用真实的 PLC 和 TCP 接口实现

local HybridGateway = require("gateway")
local config = require("config")
local log = require("utils.logger")

-- 配置日志级别
-- log.set_level("info")

log.info("=== 测试真实接口的设备发现功能 ===")

-- 创建网关实例
local gateway = HybridGateway.new()

-- 测试 1: 初始化网关
log.info("\n=== 测试 1: 初始化网关 ===")
gateway:initialize()
log.info("网关初始化成功")

-- 测试 2: TCP 接口设备发现
log.info("\n=== 测试 2: TCP 接口设备发现 ===")
local tcp_discover_msg = {
    type = "discover",
    device_id = "test_client",
    discover_network = true,
    interface = "tcp_subnet1"
}

local tcp_response = gateway:handle_discover_message("test_client", tcp_discover_msg, "tcp_subnet1")
log.info("TCP 接口设备发现响应:", #tcp_response.devices, "个设备")
for i, device in ipairs(tcp_response.devices) do
    log.info("  设备 " .. i .. ":", device.id, "-" , device.name)
end

-- 测试 3: PLC 接口设备发现
log.info("\n=== 测试 3: PLC 接口设备发现 ===")
local plc_discover_msg = {
    type = "discover",
    device_id = "test_client",
    discover_network = true,
    interface = "plc_device"  -- 使用正确的 PLC 接口名称
}

local plc_response = gateway:handle_discover_message("test_client", plc_discover_msg, "plc_device")
log.info("PLC 接口设备发现响应:", #plc_response.devices, "个设备")
for i, device in ipairs(plc_response.devices) do
    log.info("  设备 " .. i .. ":", device.id, "-" , device.name)
end

-- 测试 4: 重复设备去重测试
log.info("\n=== 测试 4: 重复设备去重测试 ===")
-- 再次调用 TCP 接口发现
local tcp_response2 = gateway:handle_discover_message("test_client", tcp_discover_msg, "tcp_subnet1")
log.info("TCP 接口再次发现响应:", #tcp_response2.devices, "个设备")
-- 应该只发现 0 个新设备，因为设备已经存在

-- 测试 5: 检查拓扑构建
log.info("\n=== 测试 5: 检查拓扑构建 ===")
if gateway.router_engine.topology then
    log.info("拓扑构建成功，设备数量:", #gateway.router_engine.topology.devices)
    for i, device in ipairs(gateway.router_engine.topology.devices) do
        log.info("  设备 " .. i .. ":", device.device_id)
    end
else
    log.warn("拓扑构建失败")
end

-- 测试 6: 停止网关
log.info("\n=== 测试 6: 停止网关 ===")
gateway:stop()
log.info("网关停止成功")

log.info("\n=== 测试完成 ===")