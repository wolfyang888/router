-- utils/logger.lua
local logger = {}

local levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4
}

local function get_timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function get_location(level)
    local ok, info = pcall(debug.getinfo, level, "Sl")
    if ok and info then
        local filename = info.short_src:match("([^/\\]+)$") or info.short_src
        return string.format("[%s:%d]", filename, info.currentline)
    end
    return "[unknown]"
end

-- 缓存配置，避免重复加载
local cached_config = nil

local function load_config()
    if cached_config then
        return cached_config
    end

    local config_paths = {
        "config.lua",
        "../config.lua",
        "../../config.lua",
        "d:/code/github/router/config.lua"
    }

    for _, path in ipairs(config_paths) do
        local chunk, err = loadfile(path)
        if chunk then
            local ok, cfg = pcall(chunk)
            if ok and type(cfg) == "table" then
                cached_config = cfg
                return cached_config
            end
        end
    end

    return nil
end

local function build_message(message, details, ...)
    if details then
        if select("#", ...) > 0 then
            return string.format("%s - " .. details, message, ...)
        end
        return string.format("%s - %s", message, details)
    end
    return message
end

function logger.log(level, message, details, ...)
    local location = get_location(5)
    local timestamp = get_timestamp()
    local log_msg = string.format("[%s] [%s] %s %s", timestamp, level, location, build_message(message, details, ...))
    print(log_msg)

    local config = load_config()
    if config and config.log and config.log.enabled and config.log.file then
        local file, err = io.open(config.log.file, "a")
        if file then
            file:write(log_msg .. "\n")
            file:close()
        elseif err then
            print("[WARN] Failed to write log file: " .. err)
        end
    end
end

function logger.debug(message, details, ...)
    logger.log("DEBUG", message, details, ...)
end

function logger.info(message, details, ...)
    logger.log("INFO", message, details, ...)
end

function logger.warn(message, details, ...)
    logger.log("WARN", message, details, ...)
end

function logger.error(message, details, ...)
    logger.log("ERROR", message, details, ...)
end

return logger