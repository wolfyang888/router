-- core/link_metrics.lua
local LinkMetrics = {}
LinkMetrics.__index = LinkMetrics

LinkMetrics.Quality = {
    EXCELLENT = 5,
    GOOD = 4,
    FAIR = 3,
    POOR = 2,
    DISCONNECTED = 1
}

function LinkMetrics.new()
    local self = setmetatable({}, LinkMetrics)
    self.latency_ms = 0
    self.packet_loss = 0
    self.throughput_bps = 0
    self.error_count = 0
    self.success_count = 0
    self.last_update = os.time()
    return self
end

function LinkMetrics:calculate_quality()
    local score = 100
    
    if self.latency_ms > 500 then
        score = score - (self.latency_ms - 500) / 10
    end
    
    score = score - (self.packet_loss * 50)
    
    local total = self.success_count + self.error_count
    if total > 0 then
        local error_rate = self.error_count / total
        score = score - (error_rate * 30)
    end
    
    score = math.max(0, math.min(100, score))
    
    if score >= 80 then
        return self.Quality.EXCELLENT
    elseif score >= 60 then
        return self.Quality.GOOD
    elseif score >= 40 then
        return self.Quality.FAIR
    elseif score >= 20 then
        return self.Quality.POOR
    else
        return self.Quality.DISCONNECTED
    end
end

function LinkMetrics:record_success(latency)
    self.success_count = self.success_count + 1
    self.latency_ms = latency
    self.packet_loss = math.max(0, self.packet_loss * 0.9)
    self.last_update = os.time()
end

function LinkMetrics:record_failure()
    self.error_count = self.error_count + 1
    self.packet_loss = math.min(1, self.packet_loss + 0.1)
    self.last_update = os.time()
end

function LinkMetrics:to_table()
    return {
        latency_ms = self.latency_ms,
        packet_loss = self.packet_loss,
        throughput_bps = self.throughput_bps,
        success_count = self.success_count,
        error_count = self.error_count,
        quality = self:calculate_quality()
    }
end

return LinkMetrics
