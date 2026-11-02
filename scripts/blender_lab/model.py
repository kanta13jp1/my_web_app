"""Original low-poly valve, executed through execute_blender_code, not blender -P."""
import bpy
import math
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Metallic'].default_value = metallic
    node.inputs['Roughness'].default_value = 0.42
    return mat

steel = material('Oxidized steel', (0.11, 0.20, 0.23), 0.7)
red = material('Safety vermilion', (0.75, 0.075, 0.025), 0.35)
brass = material('Brass marker', (0.82, 0.53, 0.16), 0.65)

def cylinder(name, radius, depth, location, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=depth,
                                       location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new('Machined edge', 'BEVEL')
    bevel.width = 0.025
    bevel.segments = 2
    return obj

cylinder('Pipe', .34, 2.6, (0, 0, .42), steel, (0, math.pi/2, 0))
for x in (-1.05, 1.05):
    cylinder('Flange', .49, .15, (x, 0, .42), steel, (0, math.pi/2, 0))
    for a in range(6):
        angle = a*math.tau/6
        cylinder('Bolt', .055, .19, (x, .405*math.cos(angle), .42+.405*math.sin(angle)), brass, (0, math.pi/2, 0))
cylinder('ValveBody', .49, .50, (0, 0, .58), steel)
cylinder('Stem', .11, .70, (0, 0, 1.12), brass)
bpy.ops.object.empty_add(location=(0, 0, 1.52))
wheel = bpy.context.object
wheel.name = 'Handwheel'
bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=8,
    major_radius=.61, minor_radius=.065, location=(0, 0, 1.52))
rim = bpy.context.object
rim.name = 'WheelRim'
rim.data.materials.append(red)
rim.parent = wheel
rim.matrix_parent_inverse = wheel.matrix_world.inverted()
for i in range(4):
    a = i*math.pi/2
    spoke = cylinder('Spoke', .035, .58, (.29*math.cos(a), .29*math.sin(a), 1.52), red,
        (math.pi/2, 0, a+math.pi/2))
    spoke.parent = wheel
    spoke.matrix_parent_inverse = wheel.matrix_world.inverted()
hub = cylinder('Hub', .14, .14, (0, 0, 1.52), brass)
hub.parent = wheel
hub.matrix_parent_inverse = wheel.matrix_world.inverted()
marker = cylinder('WheelPositionMarker', .09, .05, (.60, 0, 1.60), brass)
marker.parent = wheel
marker.matrix_parent_inverse = wheel.matrix_world.inverted()

scene = bpy.context.scene
scene.world.color = (.12, .12, .12)
bpy.ops.object.camera_add(location=(3.5, -4.4, 3.5))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, .9))-camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 3.9
scene.camera = camera
for loc, power, size in [((2, -3, 5), 900, 4), ((-3, -1, 3), 700, 3), ((0, 3, 4), 1100, 3)]:
    bpy.ops.object.light_add(type='AREA', location=loc)
    lamp = bpy.context.object
    lamp.data.energy = power
    lamp.data.shape = 'DISK'
    lamp.data.size = size
    lamp.rotation_euler = (Vector((0, 0, .7))-lamp.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.engine = 'BLENDER_EEVEE_NEXT' if bpy.app.version >= (4, 2, 0) else 'BLENDER_EEVEE'
scene.render.resolution_x = 960
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = True
bpy.ops.wm.save_as_mainfile(filepath=LAB_OUTPUT + '/valve.blend')
bpy.ops.export_scene.gltf(filepath=LAB_OUTPUT + '/valve.glb', export_format='GLB', use_selection=False)
scene.render.filepath = LAB_OUTPUT + '/valve.png'
bpy.ops.render.render(write_still=True)
print('VALVE_CREATED', bpy.app.version_string)
