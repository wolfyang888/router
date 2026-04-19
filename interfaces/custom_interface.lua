-- interfaces/custom_interface.lua
-- Custom 接口类型
-- 实现自定义协议的通信接口

local BaseInterface = require("interfaces.base_interface")

local CustomInterface = setmetatable({}, BaseInterface)
CustomInterface.__index = CustomInterface

function CustomInterface.new(name, config)
    local self = BaseInterface.new(name, config)
    setmetatable(self, CustomInterface)
    self.type = "custom"
    self.protocol = config.protocol or "custom"
    return self
end

return CustomInterface