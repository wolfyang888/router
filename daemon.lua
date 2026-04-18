-- daemon.lua
-- 守护进程，负责设备注册、组网、发现、心跳检测和报文转发

local config = require("config")
local RouterEngine = require("core.router_engine")
local logger = require("utils.logger")
local platform = require("platform")

-- 加载Libuv库
local uv, is_windows = platform.load_uv()

-- 替换模拟实现中的日志输出
if not uv.new_tcp then
    -- 当uv库不可用时，使用模拟实现
    logger.warn("Libuv library not available, using mock implementation")
    uv = {
        new_tcp = function()
            return {
                bind = function() return true end,
                listen = function(max_connections, callback) 
                    logger.info("Mock UV server listening on port " .. config.daemon.port)
                    return true 
                end,
                accept = function() return true end,
                read_start = function(callback) 
                    -- 模拟读取回调
                    logger.info("Mock UV read_start called")
                end,
                write = function(data, callback) 
                    logger.info("Mock UV write called: " .. data)
                    if callback then callback() end
                    return true 
                end,
                close = function() logger.info("Mock UV close called") end
            }
        end,
        run = function() 
            logger.info("Mock UV run called")
            -- 模拟运行一段时间后退出
            local start_time = os.time()
            while os.time() - start_time < 5 do
                if is_windows then
                    os.execute("ping -n 1 localhost > nul")
                else
                    os.execute("sleep 0.1")
                end
            end
            logger.info("Mock UV run completed")
        end,
        sleep = function(ms) 
            -- 模拟睡眠
            local seconds = ms / 1000
            if is_windows then
                os.execute("ping -n " .. math.ceil(seconds * 1000 / 300) .. " localhost > nul")
            else
                os.execute("sleep " .. seconds)
            end
        end
    }
else
    -- 成功加载Libuv库
    logger.info("Libuv library loaded successfully")
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
        logger.warn("Daemon is disabled in config")
        return false
    end

    local port = config.daemon.port
    self.server = uv.new_tcp()
    
    local success, err = self.server:bind("0.0.0.0", port)
    if not success then
        logger.error("Failed to bind daemon server: " .. err)
        return false
    end

    success, err = self.server:listen(config.daemon.max_connections, function(client, err)
    if err then
            logger.error("Error accepting connection: " .. err)
            return
        end
        self:handle_new_client(client)
    end)
    
    if not success then
        logger.error("Failed to start daemon server: " .. err)
        return false
    end

    logger.info("Daemon server started on port " .. port)
    
    -- 启动心跳检测
    self:start_heartbeat_monitor()
    
    -- 启动消息处理线程
    self:start_message_processor()
    
    return true
end

function Daemon:run()
    if not self.server then
        logger.error("Daemon server not started")
        return
    end

    logger.info("Daemon server running...")
    
    -- 运行UV事件循环
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
    
    logger.info("New client connected: " .. client_id)
    
    -- 发送欢迎消息
    local welcome_msg = {
        type = "welcome",
        message = "Welcome to the router daemon",
        client_id = client_id
    }
    self:send_to_client(client_id, welcome_msg)
    
    -- 开始读取客户端数据
    client:read_start(function(err, data)
        if err then
            logger.warn("Error reading from client: " .. err)
            self:disconnect_client(client_id)
            return
        end
        
        if data then
            self.clients[client_id].buffer = self.clients[client_id].buffer .. data
            -- 处理接收到的数据
            self:process_client_data(client_id)
        else
            -- 客户端断开连接
            self:disconnect_client(client_id)
        end
    end)
end

function Daemon:process_client_data(client_id)
    local client_info = self.clients[client_id]
    if not client_info then
        return
    end
    
    -- 处理缓冲区中的数据，按行分割
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
        -- 处理所有完整的行
        for _, line in ipairs(lines) do
            self:handle_client_message(client_id, line)
        end
        
        -- 更新缓冲区，保留未处理的部分
        client_info.buffer = buffer:sub(start)
    end
end

function Daemon:handle_client_message(client_id, message)
    -- 解析JSON消息
    local success, msg = pcall(function() return loadstring("return " .. message)() end)
    if not success then
        logger.error("Invalid message format from client " .. client_id)
        return
    end

    -- 更新心跳时间
    self.clients[client_id].last_heartbeat = os.time()

    -- 处理不同类型的消息
    if msg.type == "register" then
        self:handle_device_register(client_id, msg)
    elseif msg.type == "heartbeat" then
        self:handle_heartbeat(client_id, msg)
    elseif msg.type == "forward" then
        self:handle_message_forward(client_id, msg)
    elseif msg.type == "discover" then
        self:handle_device_discover(client_id, msg)
    else
        logger.warn("Unknown message type: " .. msg.type)
    end
end

function Daemon:handle_device_register(client_id, msg)
    local device_info = msg.device_info
    if not device_info or not device_info.id then
        logger.error("Invalid device registration: missing device info")
        return
    end

    self.clients[client_id].device_info = device_info
    
    -- 注册设备到路由引擎
    local success = self.router:register_device(device_info.id, device_info.interfaces or {})
    if success then
        logger.info("Device registered: " .. device_info.id)
        
        -- 发送注册成功响应
        self:send_to_client(client_id, {
            type = "register_response",
            status = "success",
            device_id = device_info.id
        })
    else
        logger.error("Failed to register device: " .. device_info.id)
        self:send_to_client(client_id, {
            type = "register_response",
            status = "error",
            message = "Failed to register device"
        })
    end
end

function Daemon:handle_heartbeat(client_id, msg)
    self.clients[client_id].last_heartbeat = os.time()
    
    -- 发送心跳响应
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
        logger.error("Invalid forward message: missing required fields")
        return
    end

    -- 转发消息
    local success, path = self.router:forward_to_device(message, source_device, target_device)
    
    if success then
        logger.info("Message forwarded from " .. source_device .. " to " .. target_device)
        self:send_to_client(client_id, {
            type = "forward_response",
            status = "success",
            path = path
        })
    else
        logger.error("Failed to forward message from " .. source_device .. " to " .. target_device)
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
    -- 启动心跳监控线程
    local function heartbeat_monitor()
        while true do
            local current_time = os.time()
            for client_id, client_info in pairs(self.clients) do
                if current_time - client_info.last_heartbeat > config.daemon.heartbeat_timeout then
                    logger.warn("Client heartbeat timeout: " .. client_id)
                    self:disconnect_client(client_id)
                end
            end
            uv.sleep(5000)  -- UV sleep uses milliseconds
        end
    end
    
    -- 在新线程中运行心跳监控
    local co = coroutine.create(heartbeat_monitor)
    coroutine.resume(co)
end

function Daemon:start_message_processor()
    -- 启动消息处理线程
    local function message_processor()
        while true do
            if #self.message_queue > 0 then
                local msg = table.remove(self.message_queue, 1)
                self:process_message(msg)
            end
            uv.sleep(10)  -- UV sleep uses milliseconds
        end
    end
    
    -- 在新线程中运行消息处理器
    local co = coroutine.create(message_processor)
    coroutine.resume(co)
end

function Daemon:process_message(msg)
    -- 处理队列中的消息
    if msg.type == "forward" then
        self:handle_message_forward(msg.client_id, msg)
    end
end

function Daemon:send_to_client(client_id, message)
    local client_info = self.clients[client_id]
    if not client_info or client_info.status ~= "connected" then
        logger.error("Client not connected: " .. client_id)
        return false
    end

    local json_message = self:serialize_message(message) .. "\n"
    local success, err = client_info.socket:write(json_message, function(err)
        if err then
            logger.error("Failed to send message to client: " .. err)
        end
    end)
    
    if not success then
        logger.error("Failed to send message to client: " .. err)
        return false
    end
    
    return true
end

function Daemon:disconnect_client(client_id)
    local client_info = self.clients[client_id]
    if client_info then
        -- 关闭连接
        if client_info.socket then
            client_info.socket:close()
        end
        
        -- 从路由引擎中移除设备
        if client_info.device_info then
            self.router:unregister_device(client_info.device_info.id)
        end
        
        -- 从客户端列表中移除
        self.clients[client_id] = nil
        
        logger.info("Client disconnected: " .. client_id)
    end
end

function Daemon:generate_client_id()
    return "client_" .. os.time() .. "_" .. math.random(10000)
end

function Daemon:serialize_message(message)
    -- 简单的消息序列化
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

-- 主函数
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