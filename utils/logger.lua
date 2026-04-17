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

function logger.log(level, message)
    local timestamp = get_timestamp()
    local log_msg = string.format("[%s] [%s] %s", timestamp, level, message)
    print(log_msg)
    
    local config = loadfile("config.lua")()
    if config and config.log and config.log.file then
        local file = io.open(config.log.file, "a")
        if file then
            file:write(log_msg .. "\n")
            file:close()
        end
    end
end

function logger.debug(message)
    logger.log("DEBUG", message)
end

function logger.info(message)
    logger.log("INFO", message)
end

function logger.warn(message)
    logger.log("WARN", message)
end

function logger.error(message)
    logger.log("ERROR", message)
end

return logger
