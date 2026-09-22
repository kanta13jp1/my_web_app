// GPUBuffer管理の小さなヘルパ
export const STORAGE = 0x0080 | 0x0008 | 0x0004; // STORAGE | COPY_DST | COPY_SRC
export const UNIFORM = 0x0040 | 0x0008; // UNIFORM | COPY_DST
export const MAP_READ = 0x0001 | 0x0008; // MAP_READ | COPY_DST
export class BufferPool {
    totalBytes = 0;
    buffers = [];
    device;
    constructor(device) {
        this.device = device;
    }
    storage(sizeBytes, label) {
        const size = Math.max(16, Math.ceil(sizeBytes / 16) * 16);
        const b = this.device.createBuffer({ size, usage: STORAGE, label });
        this.totalBytes += size;
        this.buffers.push(b);
        return b;
    }
    upload(data, label) {
        const b = this.storage(data.byteLength, label);
        writeBuffer(this.device, b, 0, data);
        return b;
    }
    destroy() {
        for (const b of this.buffers)
            b.destroy();
        this.buffers = [];
        this.totalBytes = 0;
    }
}
/** writeBufferは4byte境界・サイズが必要なので揃える */
export function writeBuffer(device, buf, offset, data) {
    const bytes = new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
    if (bytes.byteLength % 4 === 0) {
        device.queue.writeBuffer(buf, offset, bytes);
    }
    else {
        const padded = new Uint8Array(Math.ceil(bytes.byteLength / 4) * 4);
        padded.set(bytes);
        device.queue.writeBuffer(buf, offset, padded);
    }
}
export async function readBuffer(device, src, offset, size) {
    const rb = device.createBuffer({ size, usage: MAP_READ });
    const enc = device.createCommandEncoder();
    enc.copyBufferToBuffer(src, offset, rb, 0, size);
    device.queue.submit([enc.finish()]);
    await rb.mapAsync(1 /* GPUMapMode.READ */);
    const out = new Float32Array(rb.getMappedRange().slice(0));
    rb.unmap();
    rb.destroy();
    return out;
}
