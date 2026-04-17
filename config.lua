-- Gateway Configuration

-- Interfaces
interfaces = {
    "interface1" = {ip = "192.168.1.1", netmask = "255.255.255.0"},
    "interface2" = {ip = "192.168.2.1", netmask = "255.255.255.0"}
}

-- Routing Rules
routing = {
    default_route = {gateway = "192.168.1.254"},
    static_routes = {
        {destination = "10.0.0.0/8", gateway = "192.168.1.254"},
        {destination = "172.16.0.0/12", gateway = "192.168.1.254"}
    }
}

-- Adapters
adapters = {
    {name = "adapter1", type = "ethernet", max_speed = "1000mbps"},
    {name = "adapter2", type = "wireless", max_speed = "300mbps"}
}

-- Probing Settings
probing_settings = {
    max_retries = 3,
    timeout = 5,
    probe_interval = 30
}

-- Function to print configuration
function print_config()
    for key, value in pairs(interfaces) do
        print(key .. " : " .. value.ip .. " / " .. value.netmask)
    end
    for _, route in ipairs(routing.static_routes) do
        print("Route to: " .. route.destination .. " via " .. route.gateway)
    end
    for _, adapter in ipairs(adapters) do
        print(adapter.name .. " - " .. adapter.type .. " - " .. adapter.max_speed)
    end
end
