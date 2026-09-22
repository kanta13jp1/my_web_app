export function blobSource(blob) {
    return {
        size: blob.size,
        async read(offset, length) {
            return new Uint8Array(await blob.slice(offset, offset + length).arrayBuffer());
        },
    };
}
