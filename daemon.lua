-- daemon.lua
-- 守护进程，负责设备注册、组网、发现、心跳检测和报文转发

local config = require("config")
local RouterEngine = require("core.router_engine")
local platform = require("platform")
local Error = require("utils.error")
local log = require("utils.logger")

-- 加载Libuv库
local uv, is_windows = platform.load_uv()

-- 替换模拟实现中的日志输出
if not uv.new_tcp then
    log.warn(Error.get_message(Error.LIBUV_NOT_AVAILABLE), "使用模拟实现")
    uv = {
        new_tcp = function()
            return {
                bind = function() return true end,
                listen = function(max_connections, callback)
                    log.info("Mock UV server listening on port " .. config.daemon.port)
                    return true
                end,
                accept = function() return true end,
                read_start = function(callback)
                    log.info("Mock UV read_start called")
                end,
                write = function(data, callback)
                    log.info("Mock UV write called: " .. data)
                    if callback then callback() end
                    return true
                end,
                close = function() log.info("Mock UV close called") end
            }
        end,
        run = function()
            log.info("Mock UV run called")
            local start_time = os.time()
            while os.time() - start_time < 5 do
                if is_windows then
                    os.execute("ping -n 1 localhost > nul")
                else
                    os.execute("sleep 0.1")
                end
            end
            log.info("Mock UV run completed")
        end,
        sleep = function(ms)
            local seconds = ms / 1000
            if is_windows then
                os.execute("ping -n " .. math.ceil(seconds * 1000 / 300) .. " localhost > nul")
            else
                os.execute("sleep " .. seconds)
            end
        end
    }
else
    log.info("Libuv library loaded successfully")
end

local Daemon = {}

function Daemon:new()
    local instance = {
        server = nil,
        clients = {},
        router = RouterEngine:new(),
        heartbeat_timers = {},
        message_queue = {}
    }
    setmetatable(instance, { __index = self })
    return instance
end

function Daemon:start()
    if not config.daemon.enabled then
        log.warn(Error.get_message(Error.DAEMON_NOT_ENABLED))
        return false
    end

    local port = config.daemon.port
    self.server = uv.new_tcp()

    local success, err = self.server:bind("0.0.0.0", port)
    if not success then
        log.error(Error.get_message(Error.SERVER_BIND_FAILED), err)
        return false
    end

    success, err = self.server:listen(config.daemon.max_connections, function(client, err)
    if err then
            log.error(Error.get_message(Error.SERVER_ACCEPT_ERROR), err)
            return
        end
        self:handle_new_client(client)
    end)

    if not success then
        log.error(Error.get_message(Error.SERVER_START_FAILED), err)
        return false
    end

    log.info("Daemon server started on port " .. port)

    self:start_heartbeat_monitor()
    self:start_message_processor()

    return true
end

function Daemon:run()
    if not self.server then
        log.error(Error.get_message(Error.DAEMON_NOT_STARTED))
        return
    end

    log.info("Daemon server running...")
    uv.run()
end

function Daemon:handle_new_client(client)
    local client_id = self:generate_client_id()
    self.clients[client_id] = {
        socket = client,
        id = client_id,
        last_heartbeat = os.time(),
        status = "connected",
        device_info = nil,
        buffer = ""
    }

    log.info("New client connected: " .. client_id)

    local welcome_msg = {
        type = "welcome",
        message = "Welcome to the router daemon",
        client_id = client_id
    }
    self:send_to_client(client_id, welcome_msg)

    client:read_start(function(err, data)
        if err then
            log.warn(Error.get_message(Error.CLIENT_READ_ERROR), "client: %s, err: %s", client_id, err)
            self:disconnect_client(client_id)
            return
        end

        if data then
            self.clients[client_id].buffer = self.clients[client_id].buffer .. data
            self:process_client_data(client_id)
        else
            self:disconnect_client(client_id)
        end
    end)
end

function Daemon:process_client_data(client_id)
    local client_info = self.clients[client_id]
    if not client_info then
        return
    end

    local buffer = client_info.buffer
    local lines = {}
    local start = 1

    for i = 1, #buffer do
        if buffer:sub(i, i) == "\n" then
            local line = buffer:sub(start, i-1)
            table.insert(lines, line)
            start = i + 1
        end
    end

    if #lines > 0 then
        for _, line in ipairs(lines) do
            self:handle_client_message(client_id, line)
        end
        client_info.buffer = buffer:sub(start)
    end
end

function Daemon:handle_client_message(client_id, message)
    local success, msg = pcall(function() return loadstring("return " .. message)() end)
    if not success then
        log.error(Error.get_message(Error.INVALID_MESSAGE_FORMAT), "client: %s", client_id)
        return
    end

    self.clients[client_id].last_heartbeat = os.time()

    if msg.type == "register" then
        self:handle_device_register(client_id, msg)
    elseif msg.type == "heartbeat" then
        self:handle_heartbeat(client_id, msg)
    elseif msg.type == "forward" then
        self:handle_message_forward(client_id, msg)
    elseif msg.type == "discover" then
        self:handle_device_discover(client_id, msg)
    else
        log.warn(Error.get_message(Error.UNKNOWN_MESSAGE_TYPE), "type: %s", msg.type)
    end
end

function Daemon:handle_device_register(client_id, msg)
    local device_info = msg.device_info
    if not device_info or not device_info.id then
        log.error(Error.get_message(Error.DEVICE_INFO_MISSING), "client: %s", client_id)
        return
    end

    self.clients[client_id].device_info = device_info

    local success = self.router:register_device(device_info.id, device_info.interfaces or {})
    if success then
        log.info("Device registered: " .. device_info.id)
        self:send_to_client(client_id, {
            type = "register_response",
            status = "success",
            device_id = device_info.id
        })
    else
        log.error(Error.get_message(Error.DEVICE_REGISTER_FAILED), "device: %s", device_info.id)
        self:send_to_client(client_id, {
            type = "register_response",
            status = "error",
            message = "Failed to register device"
        })
    end
end

function Daemon:handle_heartbeat(client_id, msg)
    self.clients[client_id].last_heartbeat = os.time()

    self:send_to_client(client_id, {
        type = "heartbeat_response",
        timestamp = os.time()
    })
end

function Daemon:handle_message_forward(client_id, msg)
    local source_device = msg.source_device
    local target_device = msg.target_device
    local message = msg.message

    if not source_device or not target_device or not message then
        log.error(Error.get_message(Error.FORWARD_MESSAGE_INVALID), "client: %s", client_id)
        return
    end

    local success, path = self.router:forward_to_device(message, source_device, target_device)

    if success then
        log.info("Message forwarded from " .. source_device .. " to " .. target_device)
        self:send_to_client(client_id, {
            type = "forward_response",
            status = "success",
            path = path
        })
    else
        log.error(Error.get_message(Error.NO_PATH_FOUND), "%s -> %s", source_device, target_device)
        self:send_to_client(client_id, {
            type = "forward_response",
            status = "error",
            message = "Failed to forward message"
        })
    end
end

function Daemon:handle_device_discover(client_id, msg)
    local devices = self.router:get_registered_devices()

    self:send_to_client(client_id, {
        type = "discover_response",
        devices = devices
    })
end

function Daemon:start_heartbeat_monitor()
    local function heartbeat_monitor()
        while true do
            local current_time = os.time()
            for client_id, client_info in pairs(self.clients) do
                if current_time - client_info.last_heartbeat > config.daemon.heartbeat_timeout then
                    log.warn(Error.get_message(Error.HEARTBEAT_TIMEOUT), "client: %s", client_id)
                    self:disconnect_client(client_id)
                end
            end
            uv.sleep(5000)
        end
    end

    local co = coroutine.create(heartbeat_monitor)
    coroutine.resume(co)
end

function Daemon:start_message_processor()
    local function message_processor()
        while true do
            if #self.message_queue > 0 then
                local msg = table.remove(self.message_queue, 1)
                self:process_message(msg)
            end
            uv.sleep(10)
        end
    end

    local co = coroutine.create(message_processor)
    coroutine.resume(co)
end

function Daemon:process_message(msg)
    if msg.type == "forward" then
        self:handle_message_forward(msg.client_id, msg)
    end
end

function Daemon:send_to_client(client_id, message)
    local client_info = self.clients[client_id]
    if not client_info or client_info.status ~= "connected" then
        log.error(Error.get_message(Error.CLIENT_NOT_CONNECTED), "client: %s", client_id)
        return false
    end

    local json_message = self:serialize_message(message) .. "\n"
    local success, err = client_info.socket:write(json_message, function(err)
        if err then
            log.error(Error.get_message(Error.CLIENT_SEND_FAILED), "client: %s, err: %s", client_id, err)
        end
    end)

    if not success then
        log.error(Error.get_message(Error.CLIENT_SEND_FAILED), "client: %s, err: %s", client_id, err)
        return false
    end

    return true
end

function Daemon:disconnect_client(client_id)
    local client_info = self.clients[client_id]
    if client_info then
        if client_info.socket then
            client_info.socket:close()
        end

        if client_info.device_info then
            self.router:unregister_device(client_info.device_info.id)
        end

        self.clients[client_id] = nil

        log.info("Client disconnected: " .. client_id)
    end
end

function Daemon:generate_client_id()
    return "client_" .. os.time() .. "_" .. math.random(10000)
end

function Daemon:serialize_message(message)
    local function serialize(value)
        if type(value) == "table" then
            local parts = {}
            for k, v in pairs(value) do
                table.insert(parts, k .. "=" .. serialize(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        elseif type(value) == "string" then
            return '"' .. value .. '"'
        else
            return tostring(value)
        end
    end
    return serialize(message)
end

function main()
    local daemon = Daemon:new()
    if daemon:start() then
        daemon:run()
    end
end

if arg[1] == "run" then
    main()
end

return Daemon
