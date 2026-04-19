-- tests/utils/test_error.lua
local Error = require("utils.error")

print("================================================")
print("  Error Module Test Suite")
print("================================================")

-- 测试1: 错误码定义
print("\n[1] Testing error code definitions...")
assert(Error.OK == 0, "OK should be 0")
assert(Error.INVALID_PARAM == 2, "INVALID_PARAM should be 2")
assert(Error.INTERFACE_NOT_FOUND == 100, "INTERFACE_NOT_FOUND should be 100")
assert(Error.ROUTE_NOT_FOUND == 200, "ROUTE_NOT_FOUND should be 200")
assert(Error.DEVICE_NOT_FOUND == 300, "DEVICE_NOT_FOUND should be 300")
assert(Error.INVALID_MESSAGE_FORMAT == 400, "INVALID_MESSAGE_FORMAT should be 400")
assert(Error.SERVER_BIND_FAILED == 500, "SERVER_BIND_FAILED should be 500")
print("✓ Error codes defined correctly")

-- 测试2: 获取错误信息
print("\n[2] Testing get_message()...")
assert(Error.get_message(Error.OK) == "成功", "OK message should be '成功'")
assert(Error.get_message(Error.INVALID_PARAM) == "无效参数", "INVALID_PARAM message should be '无效参数'")
assert(Error.get_message(Error.INTERFACE_NOT_FOUND) == "接口未找到", "INTERFACE_NOT_FOUND message should be '接口未找到'")
assert(Error.get_message(9999) == "未知错误码: 9999", "Unknown code should return proper message")
print("✓ Error messages retrieved correctly")

-- 测试3: 成功/失败检查
print("\n[3] Testing is_ok() and is_error()...")
assert(Error.is_ok(Error.OK) == true, "OK should be ok")
assert(Error.is_ok(Error.UNKNOWN) == false, "UNKNOWN should not be ok")
assert(Error.is_error(Error.OK) == false, "OK should not be error")
assert(Error.is_error(Error.UNKNOWN) == true, "UNKNOWN should be error")
print("✓ Success/error checks work correctly")

-- 测试4: 创建错误对象
print("\n[4] Testing error object creation...")
local err1 = Error.new(Error.INVALID_PARAM)
assert(err1.code == Error.INVALID_PARAM, "Error code should match")
assert(err1.message == "无效参数", "Error message should match")
assert(err1.timestamp ~= nil, "Timestamp should exist")

local err2 = Error.new(Error.NO_PATH_FOUND, "无法找到从 %s 到 %s 的路由", "A", "B")
assert(err2.code == Error.NO_PATH_FOUND, "Error code should match")
assert(err2.details ~= nil, "Details should exist")
assert(string.find(err2.message, "A") ~= nil, "Message should contain formatted details")
print("✓ Error objects created correctly")

-- 测试5: 测试所有错误码都有对应的消息
print("\n[5] Testing all error codes have messages...")
local codes = {
    Error.OK, Error.UNKNOWN, Error.INVALID_PARAM, Error.LIBUV_NOT_AVAILABLE, Error.DAEMON_NOT_ENABLED,
    Error.DAEMON_NOT_STARTED, Error.INTERFACE_NOT_FOUND, Error.INTERFACE_NOT_CONNECTED,
    Error.INTERFACE_REGISTER_FAILED, Error.INTERFACE_CONNECT_FAILED, Error.INTERFACE_SEND_FAILED,
    Error.INTERFACE_RECEIVE_FAILED, Error.INTERFACE_INVALID_CONFIG, Error.INTERFACE_TYPE_UNKNOWN,
    Error.INTERFACE_PATH_INVALID, Error.ROUTE_NOT_FOUND, Error.NO_AVAILABLE_ROUTE, Error.NO_PATH_FOUND,
    Error.INVALID_ROUTING_STRATEGY, Error.CUSTOM_STRATEGY_NOT_FUNCTION, Error.DEVICE_NOT_FOUND,
    Error.DEVICE_REGISTER_FAILED, Error.DEVICE_UNREGISTERED, Error.DEVICE_INFO_MISSING,
    Error.INVALID_MESSAGE_FORMAT, Error.NO_CONVERSION_AVAILABLE, Error.INVALID_PROTOCOL_FORMAT,
    Error.UNKNOWN_MESSAGE_TYPE, Error.FORWARD_MESSAGE_INVALID, Error.SERVER_BIND_FAILED,
    Error.SERVER_START_FAILED, Error.SERVER_ACCEPT_ERROR, Error.CLIENT_NOT_CONNECTED,
    Error.CLIENT_DISCONNECTED, Error.CLIENT_SEND_FAILED, Error.CLIENT_READ_ERROR, Error.HEARTBEAT_TIMEOUT,
}
for _, code in ipairs(codes) do
    local msg = Error.get_message(code)
    assert(msg ~= nil, string.format("Error code %d has no message", code))
    assert(string.find(msg, "未知错误码") == nil,
        string.format("Error code %d should have proper message", code))
end
print("✓ All error codes have proper messages")

print("\n================================================")
print("  All Tests Passed! ✅")
print("================================================")
