"""Pinned public PNG intake. This module never executes or imports PR code."""
from __future__ import annotations

import hashlib
import json
import re
import struct
import zlib
from pathlib import Path, PurePosixPath

RECEIPT = Path(__file__).resolve().parents[1] / 'config/ai-review-public-assets.json'
RECEIPT_5893 = RECEIPT.with_name('ai-review-public-assets-5893.json')
RECEIPT_6244 = RECEIPT.with_name('ai-review-public-assets-6244.json')
RECEIPT_6273 = RECEIPT.with_name('ai-review-public-assets-6273.json')
VISUAL_BASELINE_PREFIX = 'test/e2e/visual_regression.spec.ts-snapshots/'
BLOB_RE = re.compile(r'^[0-9a-f]{40}$')
MAX_BYTES = 3_000_000
MAX_DECODED = 8_388_608
ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/'


def require(value, message):
    if not value:
        raise ValueError(message)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True)


def decoded_size(width, height, color_type):
    return (width * (3 if color_type == 2 else 4) + 1) * height


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
            require(width > 0 and height > 0 and depth == 8 and color in (2, 6) and (compression, filtering, interlace) == (0, 0, 0), 'Only noninterlaced RGB8 or RGBA8 PNG is supported')
            require(decoded_size(width, height, color) <= MAX_DECODED, 'PNG decoded size exceeds limit')
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
    stride = header[0] * (3 if header[3] == 2 else 4) + 1
    expected = stride * header[1]
    decoder = zlib.decompressobj()
    decoded = decoder.decompress(bytes(compressed), expected + 1)
    require(len(decoded) == expected and decoder.eof and not decoder.unconsumed_tail and not decoder.unused_data, 'Invalid or oversized PNG image stream')
    require(all(decoded[i] <= 4 for i in range(0, expected, stride)), 'Invalid PNG row filter')
    return {'width': header[0], 'height': header[1], 'bit_depth': 8, 'color_type': header[3]}


def load_receipt(pr):
    if pr == 5893:
        path = RECEIPT_5893
    elif pr == 6244:
        path = RECEIPT_6244
    elif pr == 6273:
        path = RECEIPT_6273
    else:
        path = RECEIPT
    receipt = json.loads(path.read_text(encoding='utf-8'))
    require(receipt.get('schema_version') == 1 and receipt.get('provider') == 'google-gemini' and receipt.get('endpoint') == ENDPOINT and receipt.get('method') == 'generateContent', 'Unsupported public asset consent')
    assets = receipt.get('assets', [])
    expected_count = 2 if pr in (6244, 6273) else 1
    require(isinstance(assets, list) and len(assets) == expected_count and all(isinstance(a, dict) for a in assets), 'Unsupported approved PNG count')
    return receipt


def verify_bytes(data, asset):
    require(type(asset.get('bytes')) is int and len(data) == asset['bytes'] and len(data) <= MAX_BYTES, 'Approved PNG size mismatch')
    require(hashlib.sha256(data).hexdigest() == asset['sha256'], 'Approved PNG hash mismatch')
    require(hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest() == asset['head_blob'], 'Approved PNG Git blob mismatch')
    info = png_info(data)
    require(all(info[k] == asset[k] for k in info), 'Approved PNG dimensions/format mismatch')
    return info


def is_visual_baseline_png(path):
    if not path.startswith(VISUAL_BASELINE_PREFIX):
        return False
    posix = PurePosixPath(path)
    return posix.suffix.lower() == '.png' and len(posix.relative_to(VISUAL_BASELINE_PREFIX.rstrip('/')).parts) == 1


def prepare_assets(state, paths, git, directory):
    if not any(PurePosixPath(path).suffix.lower() == '.png' for path in paths):
        return []
    receipt = load_receipt(state['pr'])
    require(state['repository'] == receipt['repository'] and state['pr'] == receipt['pull_request'], 'PNG consent repository/PR mismatch')
    require(sorted(paths) == sorted(receipt['related_paths']), 'PNG consent does not cover this code scope')
    receipt_digest = hashlib.sha256(canonical(receipt).encode()).hexdigest()
    assets = []
    seen_paths = set()
    total_bytes = 0
    total_decoded = 0
    for original in receipt['assets']:
        asset = dict(original)
        path = asset.get('path')
        require(
            isinstance(path, str)
            and '\\' not in path
            and path in paths
            and path not in seen_paths
            and not path.startswith('/')
            and '..' not in PurePosixPath(path).parts,
            'Invalid approved PNG path',
        )
        seen_paths.add(path)
        require(isinstance(asset.get('head_blob'), str) and BLOB_RE.fullmatch(asset['head_blob']), 'Invalid approved PNG blob')
        entry = git('ls-tree', '-z', state['head'], '--', path).decode().rstrip('\0')
        require(entry == '100644 blob '+asset['head_blob']+'\t'+path, 'PNG is not the approved regular Git blob')
        base_entry = git('ls-tree', '-z', state['base'], '--', path).decode().rstrip('\0')
        if 'base_blob' in asset:
            require(is_visual_baseline_png(path), 'PNG replacement is restricted to reviewed visual baselines')
            require(
                isinstance(asset['base_blob'], str)
                and BLOB_RE.fullmatch(asset['base_blob'])
                and asset['base_blob'] != asset['head_blob'],
                'Invalid approved PNG base blob',
            )
            require(
                base_entry == '100644 blob '+asset['base_blob']+'\t'+path,
                'Base PNG blob does not match approved replacement',
            )
        else:
            require(not base_entry, 'PNG replacement/deletion is not approved')
        blob_size = int(git('cat-file', '-s', asset['head_blob']).decode())
        require(type(asset.get('bytes')) is int and blob_size == asset['bytes'] <= MAX_BYTES, 'PNG blob size mismatch')
        total_bytes += blob_size
        require(total_bytes <= MAX_BYTES, 'Approved PNG total size exceeds limit')
        data = git('cat-file', 'blob', asset['head_blob'])
        info = verify_bytes(data, asset)
        total_decoded += decoded_size(info['width'], info['height'], info['color_type'])
        require(total_decoded <= MAX_DECODED, 'Approved PNG total decoded size exceeds limit')
        asset['receipt_sha256'] = receipt_digest
        assets.append(asset)
        target = directory/'assets'
        target.mkdir(exist_ok=True)
        (target/(asset['sha256']+'.png')).write_bytes(data)
    require({a['path'] for a in assets} == {p for p in paths if PurePosixPath(p).suffix.lower() == '.png'}, 'Unapproved PNG')
    return assets


def input_digest(source, assets):
    value = source if not assets else source+'\nTrusted public image bindings:\n'+canonical(assets)
    return hashlib.sha256(value.encode()).hexdigest()


def read_assets(state, directory):
    assets = state.get('assets', [])
    if not assets:
        return []
    receipt = load_receipt(state['pr'])
    require(state['repository'] == receipt['repository'] and state['pr'] == receipt['pull_request'] and sorted(state['files']) == sorted(receipt['related_paths']), 'Image consent scope changed')
    receipt_digest = hashlib.sha256(canonical(receipt).encode()).hexdigest()
    expected = [dict(a, receipt_sha256=receipt_digest) for a in receipt['assets']]
    require(assets == expected, 'Image receipt binding changed')
    result = []
    total_bytes = 0
    total_decoded = 0
    for asset in assets:
        data = (directory/'assets'/(asset['sha256']+'.png')).read_bytes()
        info = verify_bytes(data, asset)
        total_bytes += len(data)
        require(total_bytes <= MAX_BYTES, 'Approved PNG total size exceeds limit')
        total_decoded += decoded_size(info['width'], info['height'], info['color_type'])
        require(total_decoded <= MAX_DECODED, 'Approved PNG total decoded size exceeds limit')
        result.append(data)
    return result
