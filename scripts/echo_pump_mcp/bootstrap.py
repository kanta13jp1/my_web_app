"""Start the unmodified, pinned community addon in Blender's GUI event loop."""
import importlib.util
import os
import sys
from pathlib import Path

import bpy
import numpy

print('BLENDER_RUNTIME', bpy.app.version_string, sys.version, numpy.__version__, flush=True)

addon_path = Path(os.environ['BLENDER_ADDON_PATH']).resolve()
spec = importlib.util.spec_from_file_location('blender_mcp_addon', addon_path)
addon = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = addon
spec.loader.exec_module(addon)
addon.register()
# No premium generators, third-party models, or credentials are used.
bpy.context.scene.blendermcp_auto_start_server = False
server = addon.BlenderMCPServer(host='127.0.0.1', port=9876)
bpy.types.blendermcp_server = server
server.start()
print('BLENDER_LAB_READY', flush=True)
