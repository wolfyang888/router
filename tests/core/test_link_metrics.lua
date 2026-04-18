-- tests/core/test_link_metrics.lua
local LinkMetrics = require("core.link_metrics")

print("================================================")
print("  Link Metrics Test Suite")
print("================================================\n")

-- 测试 1: 创建 LinkMetrics 实例
print("[1] Testing LinkMetrics creation...")
local metrics = LinkMetrics.new()
assert(metrics ~= nil, "Failed to create LinkMetrics")
assert(metrics.latency_ms == 0, "Initial latency should be 0")
assert(metrics.packet_loss == 0, "Initial packet_loss should be 0")
print("✓ LinkMetrics instance created successfully\n")

-- 测试 2: 记录成功
print("[2] Testing record_success...")
metrics:record_success(10)
assert(metrics.latency_ms == 10, "Latency should be 10")
assert(metrics.success_count == 1, "Success count should be 1")
print("✓ record_success works correctly\n")

-- 测试 3: 记录失败
print("[3] Testing record_failure...")
metrics:record_failure()
assert(metrics.error_count == 1, "Error count should be 1")
assert(metrics.packet_loss > 0, "Packet loss should increase")
print("✓ record_failure works correctly\n")

-- 测试 4: 质量计算
print("[4] Testing quality calculation...")
local quality = metrics:calculate_quality()
assert(quality >= LinkMetrics.Quality.DISCONNECTED, "Quality should be valid")
print(string.format("✓ Quality calculated: %d\n", quality))

-- 测试 5: 模拟完美链路
print("[5] Testing excellent link quality...")
local excellent_metrics = LinkMetrics.new()
for i = 1, 10 do
    excellent_metrics:record_success(5)
end
local excellent_quality = excellent_metrics:calculate_quality()
assert(excellent_quality == LinkMetrics.Quality.EXCELLENT, 
    "Should be EXCELLENT quality")
print("✓ Excellent quality detected\n")

-- 测试 6: 模拟较差链路
print("[6] Testing poor link quality...")
local poor_metrics = LinkMetrics.new()
for i = 1, 5 do
    poor_metrics:record_failure()
end
local poor_quality = poor_metrics:calculate_quality()
assert(poor_quality <= LinkMetrics.Quality.POOR, "Should be POOR quality")
print("✓ Poor quality detected\n")

-- 测试 7: to_table 方法
print("[7] Testing to_table method...")
local metrics_table = metrics:to_table()
assert(metrics_table.latency_ms ~= nil, "latency_ms should exist")
assert(metrics_table.packet_loss ~= nil, "packet_loss should exist")
assert(metrics_table.quality ~= nil, "quality should exist")
print("✓ to_table returns complete metrics\n")

print("================================================")
print("  All tests passed! ✅")
print("================================================")
