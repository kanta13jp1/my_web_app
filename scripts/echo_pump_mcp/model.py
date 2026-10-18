"""Original Echo Pump prop, executed by the upstream MCP tool in Blender."""
import bpy
import math
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metal=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = .28
    return m

ceramic = material('Deep teal ceramic', (.025, .13, .14), .25)
silver = material('Brushed nickel', (.48, .62, .65), .85)
brass = material('Copper contact', (.65, .28, .07), .72)
mint = material('Inspection window', (.24, .8, .62), .35)

def cylinder(name, radius, depth, x, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=radius, depth=depth,
        location=(x, 0, 0), rotation=(0, math.pi/2, 0))
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat)
    b = o.modifiers.new('Rounded machined edges', 'BEVEL')
    b.width = .025
    b.segments = 3
    for f in o.data.polygons:
        f.use_smooth = True
    return o

cylinder('FuseBody', .30, 1.70, 0, ceramic)
for x in (-.92, .92):
    cylinder('ContactCap', .34, .32, x, silver)
    cylinder('ContactPin', .14, .22, x*1.25, brass)
    for d in (-.085, .085):
        cylinder('MachinedRing', .348, .025, x+d, silver)
for x in (-.56, .56):
    cylinder('IdentificationBand', .306, .075, x, brass)
# A visible inner link signals a usable replacement part without small text.
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -.283, .065))
window = bpy.context.object
window.name = 'InspectionWindow'
window.scale = (.82, .045, .15)
window.data.materials.append(mint)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
b = window.modifiers.new('Soft window edge', 'BEVEL'); b.width = .04; b.segments = 3
for x in (-.20, 0, .20):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, -.315, .07))
    link = bpy.context.object
    link.name = 'ConductiveLink'
    link.scale = (.035, .025, .19)
    link.rotation_euler[1] = .48
    link.data.materials.append(brass)

scene = bpy.context.scene
scene.world.color = (.09, .09, .09)
bpy.ops.object.camera_add(location=(2.3, -4.5, 2.8))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0))-camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'; camera.data.ortho_scale = 3.15; scene.camera = camera
for loc, power, size in [((1, -3, 4), 850, 4), ((-3, -1, 2), 600, 3), ((0, 3, 3), 950, 3)]:
    bpy.ops.object.light_add(type='AREA', location=loc)
    lamp = bpy.context.object
    lamp.data.energy = power; lamp.data.size = size
    lamp.rotation_euler = (-lamp.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.engine = 'BLENDER_EEVEE_NEXT' if bpy.app.version >= (4, 2, 0) else 'BLENDER_EEVEE'
scene.render.resolution_x = 768; scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'; scene.render.film_transparent = True
bpy.ops.wm.save_as_mainfile(filepath=LAB_OUTPUT+'/fuse.blend')
bpy.ops.export_scene.gltf(filepath=LAB_OUTPUT+'/fuse.glb', export_format='GLB', use_selection=False)
scene.render.filepath = LAB_OUTPUT+'/fuse.png'
bpy.ops.render.render(write_still=True)
print('ECHO_PUMP_FUSE_CREATED', bpy.app.version_string)
