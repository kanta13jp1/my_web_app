// WebGPUデバイス初期化（Node: `webgpu`パッケージ(Dawn) / ブラウザ: navigator.gpu のどちらのGPUオブジェクトでも動く）
export async function requestDevice(gpu) {
    const adapter = await gpu.requestAdapter({ powerPreference: "high-performance" });
    if (!adapter)
        throw new Error("WebGPU adapter not available");
    const L = adapter.limits;
    const device = await adapter.requestDevice({
        requiredLimits: {
            maxBufferSize: L.maxBufferSize,
            maxStorageBufferBindingSize: L.maxStorageBufferBindingSize,
            maxComputeWorkgroupStorageSize: L.maxComputeWorkgroupStorageSize,
            maxComputeInvocationsPerWorkgroup: Math.min(256, L.maxComputeInvocationsPerWorkgroup),
            maxStorageBuffersPerShaderStage: Math.min(8, L.maxStorageBuffersPerShaderStage),
            maxComputeWorkgroupsPerDimension: L.maxComputeWorkgroupsPerDimension,
        },
    });
    device.lost.then((info) => console.error(`WebGPU device lost: ${info.message}`));
    const i = adapter.info;
    return { device, adapterInfo: [i.vendor, i.architecture, i.device, i.description].filter(Boolean).join(" / ") };
}
