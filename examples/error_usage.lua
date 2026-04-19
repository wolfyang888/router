-- examples/error_usage.lua
-- Error模块使用示例

local Error = require("utils.error")
local log = require("utils.logger")

print("================================================")
print("  Error Module Usage Examples")
print("================================================")

-- 示例1: 基本错误码使用
print("\n[Example 1] Basic error code usage")
local function check_interface(name)
    if not name then
        log.error("接口名称为空: " .. Error.get_message(Error.INVALID_PARAM))
        return false
    end
    if name == "" then
        log.error("接口名称不能为空: " .. Error.get_message(Error.INVALID_PARAM))
        return false
    end
    return true
end

check_interface(nil)
check_interface("")

-- 示例2: 使用格式化参数
print("\n[Example 2] Using formatted arguments")
local function connect_tcp(host, port)
    local success = false -- 模拟连接失败
    if not success then
        log.error(string.format("无法连接到 %s:%d - %s", host, port, Error.get_message(Error.INTERFACE_CONNECT_FAILED)))
    end
end

connect_tcp("192.168.1.100", 8888)

-- 示例3: 使用警告日志
print("\n[Example 3] Using warning logs")
local function send_data(device_id, data)
    if data == nil then
        log.warn(string.format("设备 %s 发送数据为空 - %s", device_id, Error.get_message(Error.INTERFACE_SEND_FAILED)))
    end
end

send_data("plc_001", nil)

-- 示例4: 创建错误对象
print("\n[Example 4] Creating error objects")
local function parse_data(raw_data)
    if not raw_data then
        return Error.new(Error.INVALID_PARAM, "原始数据为空")
    end

    -- 模拟解析失败
    local parse_success = false
    if not parse_success then
        return Error.new(Error.INVALID_MESSAGE_FORMAT,
            "无法解析数据: %s", raw_data or "nil")
    end
end

local result = parse_data(nil)
if Error.is_error(result.code) then
    print(string.format("  Error Code: %d", result.code))
    print(string.format("  Error Message: %s", result.message))
    print(string.format("  Timestamp: %s", result.timestamp))
end

-- 示例5: 检查操作结果
print("\n[Example 5] Checking operation results")
local function do_something()
    -- 模拟成功/失败
    return Error.OK
end

local status = do_something()
if Error.is_ok(status) then
    print("  操作成功")
else
    log.error("操作失败: " .. Error.get_message(status))
end

print("\n================================================")
print("  Examples Complete!")
print("================================================")