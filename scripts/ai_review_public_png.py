"""Pinned public PNG intake. This module never executes or imports PR code."""
from __future__ import annotations

import hashlib
import json
import struct
import zlib
from pathlib import Path

RECEIPT = Path(__file__).resolve().parents[1] / 'config/ai-review-public-assets.json'
MAX_BYTES = 3_000_000
MAX_DECODED = 8_388_608
ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/'


def require(value, message):
    if not value:
        raise ValueError(message)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True)


def png_info(data):
    require(8 < len(data) <= MAX_BYTES and data[:8] == b'\x89PNG\r\n\x1a\n', 'Invalid PNG signature/size')
    pos, compressed, header, ended, idat_closed = 8, bytearray(), None, False, False
    while pos < len(data):
        require(pos + 12 <= len(data), 'Truncated PNG chunk')
        size = struct.unpack('>I', data[pos:pos+4])[0]
        kind = data[pos+4:pos+8]
        require(size <= MAX_BYTES and pos + size + 12 <= len(data), 'PNG chunk exceeds bounds')
        body = data[pos+8:pos+8+size]
        crc = struct.unpack('>I', data[pos+8+size:pos+12+size])[0]
        require(zlib.crc32(kind+body) & 0xffffffff == crc, 'PNG CRC mismatch')
        require(kind in {b'IHDR', b'caBX', b'IDAT', b'IEND'}, 'Unsupported PNG chunk')
        if kind == b'IHDR':
            require(pos == 8 and header is None and size == 13, 'Invalid PNG header order')
            header = struct.unpack('>IIBBBBB', body)
            width, height, depth, color, compression, filtering, interlace = header
            require(width > 0 and height > 0 and (depth, color, compression, filtering, interlace) == (8, 6, 0, 0, 0), 'Only noninterlaced RGBA8 PNG is supported')
            require((width * 4 + 1) * height <= MAX_DECODED, 'PNG decoded size exceeds limit')
        else:
            require(header is not None, 'PNG header missing')
            if kind == b'IDAT':
                require(not idat_closed and not ended, 'Nonconsecutive PNG image data')
                compressed.extend(body)
            elif kind == b'IEND':
                require(size == 0 and compressed and not ended, 'Invalid PNG end')
                ended = True
                require(pos + 12 == len(data), 'Trailing PNG data')
            else:
                # The pinned original contains C2PA provenance; it is not executed.
                require(not compressed and size <= 32768, 'Unsupported PNG provenance placement/size')
        if compressed and kind != b'IDAT':
            idat_closed = True
        pos += size + 12
    require(ended and header is not None, 'Incomplete PNG')
    expected = (header[0] * 4 + 1) * header[1]
    decoder = zlib.decompressobj()
    decoded = decoder.decompress(bytes(compressed), expected + 1)
    require(len(decoded) == expected and decoder.eof and not decoder.unconsumed_tail and not decoder.unused_data, 'Invalid or oversized PNG image stream')
    require(all(decoded[i] <= 4 for i in range(0, expected, header[0]*4+1)), 'Invalid PNG row filter')
    return {'width': header[0], 'height': header[1], 'bit_depth': 8, 'color_type': 6}


def load_receipt():
    receipt = json.loads(RECEIPT.read_text(encoding='utf-8'))
    require(receipt.get('schema_version') == 1 and receipt.get('provider') == 'google-gemini' and receipt.get('endpoint') == ENDPOINT and receipt.get('method') == 'generateContent', 'Unsupported public asset consent')
    require(len(receipt.get('assets', [])) == 1, 'Exactly one approved PNG is supported')
    return receipt


def verify_bytes(data, asset):
    require(len(data) == asset['bytes'] and len(data) <= MAX_BYTES, 'Approved PNG size mismatch')
    require(hashlib.sha256(data).hexdigest() == asset['sha256'], 'Approved PNG hash mismatch')
    require(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest() == asset['head_blob'], 'Approved PNG Git blob mismatch')
    info = png_info(data)
    require(all(info[k] == asset[k] for k in info), 'Approved PNG dimensions/format mismatch')


def prepare_assets(state, paths, git, directory):
    if not any(Path(path).suffix.lower() == '.png' for path in paths):
        return []
    receipt = load_receipt()
    require(state['repository'] == receipt['repository'] and state['pr'] == receipt['pull_request'], 'PNG consent repository/PR mismatch')
    require(sorted(paths) == sorted(receipt['related_paths']), 'PNG consent does not cover this code scope')
    assets = []
    for original in receipt['assets']:
        asset = dict(original)
        path = asset['path']
        require(path in paths and not path.startswith('/') and '..' not in Path(path).parts, 'Invalid approved PNG path')
        entry = git('ls-tree', '-z', state['head'], '--', path).decode().rstrip('\0')
        require(entry == '100644 blob '+asset['head_blob']+'\t'+path, 'PNG is not the approved regular Git blob')
        require(not git('ls-tree', '-z', state['base'], '--', path), 'PNG replacement/deletion is not approved')
        require(int(git('cat-file', '-s', asset['head_blob']).decode()) == asset['bytes'] <= MAX_BYTES, 'PNG blob size mismatch')
        data = git('cat-file', 'blob', asset['head_blob'])
        verify_bytes(data, asset)
        asset['receipt_sha256'] = hashlib.sha256(canonical(receipt).encode()).hexdigest()
        assets.append(asset)
        target = directory/'assets'
        target.mkdir(exist_ok=True)
        (target/(asset['sha256']+'.png')).write_bytes(data)
    require({a['path'] for a in assets} == {p for p in paths if Path(p).suffix.lower() == '.png'}, 'Unapproved PNG')
    return assets


def input_digest(source, assets):
    value = source if not assets else source+'\nTrusted public image bindings:\n'+canonical(assets)
    return hashlib.sha256(value.encode()).hexdigest()


def read_assets(state, directory):
    assets = state.get('assets', [])
    if not assets:
        return []
    receipt = load_receipt()
    require(state['repository'] == receipt['repository'] and state['pr'] == receipt['pull_request'] and sorted(state['files']) == sorted(receipt['related_paths']), 'Image consent scope changed')
    expected = [dict(a, receipt_sha256=hashlib.sha256(canonical(receipt).encode()).hexdigest()) for a in receipt['assets']]
    require(assets == expected, 'Image receipt binding changed')
    result = []
    for asset in assets:
        data = (directory/'assets'/(asset['sha256']+'.png')).read_bytes()
        verify_bytes(data, asset)
        result.append(data)
    return result
