-- platform.lua
-- 跨平台兼容模块，负责检测操作系统和加载Libuv库

local M = {}

-- UTF-8 字符串处理函数
local function utf8_len(s)
    if type(s) ~= "string" then return 0 end
    local len = 0
    local i = 1
    while i <= #s do
        if s:byte(i) >= 0xC0 then
            len = len + 1
            i = i + 2
        else
            len = len + 1
            i = i + 1
        end
    end
    return len
end

-- 设置全局 UTF-8 支持
if not string.utf8len then
    string.utf8len = utf8_len
end

-- 检测当前操作系统
function M.detect_os()
    local is_windows = false
    local env_os = os.getenv("OS")
    if env_os and string.find(env_os, "Windows") then
        is_windows = true
    end
    return is_windows
end

-- 加载Libuv库
function M.load_uv()
    local is_windows = M.detect_os()
    
    -- Windows 中文支持：设置控制台为 UTF-8
    if is_windows then
        local success, result = pcall(function()
            os.execute("chcp 65001 > nul")
        end)
        if success then
            print("已设置控制台为 UTF-8 编码")
        end
    end
    
    -- 获取LUA_ROOT环境变量
    local lua_root = os.getenv("LUA_ROOT") or "E:/tools/common/ToolsV3/lua"
    
    -- 添加libuv库的搜索路径
    if is_windows then
        package.cpath = package.cpath .. ";" .. lua_root .. "/win-x64/lib/lua/5.4/?.dll"
    else
        -- Linux/macOS路径
        package.cpath = package.cpath .. ";/usr/lib/lua/5.4/?.so;./?.so"
    end
    
    local uv = nil
    -- 尝试加载luv模块（跨平台兼容）
    local success, uv_lib = pcall(require, "luv")
    if success then
        uv = uv_lib
        print("Libuv library loaded successfully as 'luv'")
    else
        -- 尝试加载uv模块
        success, uv_lib = pcall(require, "uv")
        if success then
            uv = uv_lib
            print("Libuv library loaded successfully as 'uv'")
        else
            -- 当uv库不可用时，使用模拟实现
            print("Libuv library not available, using mock implementation")
            uv = {
                new_tcp = function()
                    return {
                        bind = function() return true end,
                        listen = function(max_connections, callback) 
                            print("Mock UV server listening on port")
                            return true 
                        end,
                        accept = function() return true end,
                        read_start = function(callback) 
                            -- 模拟读取回调
                            print("Mock UV read_start called")
                        end,
                        write = function(data, callback) 
                            print("Mock UV write called")
                            if callback then callback() end
                            return true 
                        end,
                        close = function() print("Mock UV close called") end
                    }
                end,
                run = function() 
                    print("Mock UV run called")
                    -- 模拟运行一段时间后退出
                    local start_time = os.time()
                    while os.time() - start_time < 5 do
                        if is_windows then
                            os.execute("ping -n 1 localhost > nul")
                        else
                            os.execute("sleep 0.1")
                        end
                    end
                    print("Mock UV run completed")
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
        end
    end
    
    return uv, is_windows
end

return M