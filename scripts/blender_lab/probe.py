"""Real MCP initialize/list/call against the pinned upstream stdio server."""
import asyncio
import hashlib
import json
import os
import struct
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

OUT = Path('web/labs/blender-valve').resolve()
OUT.mkdir(parents=True, exist_ok=True)
evidence = {'started_utc': datetime.now(timezone.utc).isoformat(),
            'execution': 'Codex-orchestrated GitHub Actions; MCP Python SDK client, not native Desktop tool discovery',
            'upstream_sha': os.environ['BLENDER_UPSTREAM_SHA'], 'calls': []}
evidence['installed_distribution'] = {'name': 'mcp-for-blender', 'version': '2.1.9',
    'wheel_sha256': 'a5cbc6cf316fa7433566eb505a0c26ca22e28c10083bd1b09a23d9e357821ccc'}

async def run():
    params = StdioServerParameters(command=sys.executable, args=['-m', 'blender_mcp.server'],
        env={**os.environ, 'DISABLE_TELEMETRY': 'true', 'BLENDER_HOST': '127.0.0.1',
             'BLENDER_MCP_SAFE_MODE': '1'})
    async with stdio_client(params) as (reader, writer):
        async with ClientSession(reader, writer) as session:
            initialized = await session.initialize()
            evidence['protocol'] = initialized.protocolVersion
            tools = await session.list_tools()
            evidence['tools'] = [t.name for t in tools.tools]
            async def call(name, args):
                start = time.monotonic()
                result = await session.call_tool(name, args)
                text = '\n'.join(c.text for c in result.content if hasattr(c, 'text'))
                evidence['calls'].append({'tool': name, 'seconds': round(time.monotonic()-start, 3),
                                           'is_error': result.isError, 'result': text})
                if result.isError or text.startswith(('Error', 'Traceback')):
                    raise RuntimeError(text)
                return text
            await call('get_addon_status', {})
            await call('get_scene_info', {})
            model = Path('scripts/blender_lab/model.py').read_text()
            await call('execute_blender_code', {'code': 'LAB_OUTPUT = '+repr(str(OUT))+'\n'+model,
                'user_prompt': 'Create an original low-poly pump valve for the my_web_app game development lab.'})
            inspection = await call('execute_blender_code', {'code': '''import bpy, json
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
print(json.dumps({'blender': bpy.app.version_string, 'meshes': len(meshes), 'vertices': sum(len(o.data.vertices) for o in meshes), 'triangles': sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes), 'handwheel': bpy.data.objects.get('Handwheel') is not None}))
'''})
            evidence['inspection'] = inspection
            await call('get_scene_info', {'query': 'Wheel'})
    hashes = {}
    for name in ('valve.blend', 'valve.glb', 'valve.png'):
        data = (OUT/name).read_bytes()
        assert data, name
        hashes[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    raw = (OUT/'valve.glb').read_bytes()
    magic, version, length = struct.unpack_from('<4sII', raw)
    assert magic == b'glTF' and version == 2 and length == len(raw)
    json_length, chunk_type = struct.unpack_from('<II', raw, 12)
    assert chunk_type == 0x4E4F534A
    gltf = json.loads(raw[20:20+json_length])
    assert any(n.get('name') == 'Handwheel' for n in gltf['nodes'])
    evidence['files'] = hashes
    evidence['gltf'] = {'nodes': len(gltf['nodes']), 'meshes': len(gltf['meshes']), 'handwheel': True}
    evidence['passed'] = True

try:
    asyncio.run(run())
finally:
    Path('blender-evidence.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2))
