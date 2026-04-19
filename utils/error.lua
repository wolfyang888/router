-- utils/error.lua

local Error = {
    -- 系统错误 (0-99)
    OK = 0,
    UNKNOWN = 1,
    INVALID_PARAM = 2,
    LIBUV_NOT_AVAILABLE = 3,
    DAEMON_NOT_ENABLED = 4,
    DAEMON_NOT_STARTED = 5,

    -- 接口错误 (100-199)
    INTERFACE_NOT_FOUND = 100,
    INTERFACE_NOT_CONNECTED = 101,
    INTERFACE_REGISTER_FAILED = 102,
    INTERFACE_CONNECT_FAILED = 103,
    INTERFACE_SEND_FAILED = 104,
    INTERFACE_RECEIVE_FAILED = 105,
    INTERFACE_INVALID_CONFIG = 106,
    INTERFACE_TYPE_UNKNOWN = 107,
    INTERFACE_PATH_INVALID = 108,

    -- 路由错误 (200-299)
    ROUTE_NOT_FOUND = 200,
    NO_AVAILABLE_ROUTE = 201,
    NO_PATH_FOUND = 202,
    INVALID_ROUTING_STRATEGY = 203,
    CUSTOM_STRATEGY_NOT_FUNCTION = 204,

    -- 设备错误 (300-399)
    DEVICE_NOT_FOUND = 300,
    DEVICE_REGISTER_FAILED = 301,
    DEVICE_UNREGISTERED = 302,
    DEVICE_INFO_MISSING = 303,

    -- 协议错误 (400-499)
    INVALID_MESSAGE_FORMAT = 400,
    NO_CONVERSION_AVAILABLE = 401,
    INVALID_PROTOCOL_FORMAT = 402,
    UNKNOWN_MESSAGE_TYPE = 403,
    FORWARD_MESSAGE_INVALID = 404,

    -- 网络错误 (500-599)
    SERVER_BIND_FAILED = 500,
    SERVER_START_FAILED = 501,
    SERVER_ACCEPT_ERROR = 502,
    CLIENT_NOT_CONNECTED = 503,
    CLIENT_DISCONNECTED = 504,
    CLIENT_SEND_FAILED = 505,
    CLIENT_READ_ERROR = 506,
    HEARTBEAT_TIMEOUT = 507,
}

local ErrorMessages = {
    [Error.OK] = "成功",
    [Error.UNKNOWN] = "未知错误",
    [Error.INVALID_PARAM] = "无效参数",
    [Error.LIBUV_NOT_AVAILABLE] = "Libuv库不可用",
    [Error.DAEMON_NOT_ENABLED] = "守护进程未启用",
    [Error.DAEMON_NOT_STARTED] = "守护进程未启动",

    [Error.INTERFACE_NOT_FOUND] = "接口未找到",
    [Error.INTERFACE_NOT_CONNECTED] = "接口未连接",
    [Error.INTERFACE_REGISTER_FAILED] = "接口注册失败",
    [Error.INTERFACE_CONNECT_FAILED] = "接口连接失败",
    [Error.INTERFACE_SEND_FAILED] = "接口发送失败",
    [Error.INTERFACE_RECEIVE_FAILED] = "接口接收失败",
    [Error.INTERFACE_INVALID_CONFIG] = "接口配置无效",
    [Error.INTERFACE_TYPE_UNKNOWN] = "未知的接口类型",
    [Error.INTERFACE_PATH_INVALID] = "无效的接口路径",

    [Error.ROUTE_NOT_FOUND] = "路由未找到",
    [Error.NO_AVAILABLE_ROUTE] = "无可用路由",
    [Error.NO_PATH_FOUND] = "无可用路径",
    [Error.INVALID_ROUTING_STRATEGY] = "无效的路由策略",
    [Error.CUSTOM_STRATEGY_NOT_FUNCTION] = "自定义策略必须是函数",

    [Error.DEVICE_NOT_FOUND] = "设备未找到",
    [Error.DEVICE_REGISTER_FAILED] = "设备注册失败",
    [Error.DEVICE_UNREGISTERED] = "设备已注销",
    [Error.DEVICE_INFO_MISSING] = "设备信息缺失",

    [Error.INVALID_MESSAGE_FORMAT] = "无效的消息格式",
    [Error.NO_CONVERSION_AVAILABLE] = "无可用的协议转换",
    [Error.INVALID_PROTOCOL_FORMAT] = "无效的协议格式",
    [Error.UNKNOWN_MESSAGE_TYPE] = "未知的消息类型",
    [Error.FORWARD_MESSAGE_INVALID] = "无效的转发消息",

    [Error.SERVER_BIND_FAILED] = "服务器绑定失败",
    [Error.SERVER_START_FAILED] = "服务器启动失败",
    [Error.SERVER_ACCEPT_ERROR] = "服务器接受连接错误",
    [Error.CLIENT_NOT_CONNECTED] = "客户端未连接",
    [Error.CLIENT_DISCONNECTED] = "客户端已断开",
    [Error.CLIENT_SEND_FAILED] = "客户端发送失败",
    [Error.CLIENT_READ_ERROR] = "客户端读取错误",
    [Error.HEARTBEAT_TIMEOUT] = "心跳超时",
}

function Error.get_message(code)
    return ErrorMessages[code] or string.format("未知错误码: %d", code)
end

function Error.new(code, details, ...)
    local err = {
        code = code,
        message = Error.get_message(code),
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    }
    if details then
        if select("#", ...) > 0 then
            details = string.format(details, ...)
        end
        err.details = details
        err.message = string.format("%s - %s", err.message, details)
    end
    return err
end

function Error.is_ok(code)
    return code == Error.OK
end

function Error.is_error(code)
    return code ~= Error.OK
end

return Error
