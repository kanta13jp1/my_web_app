"""Original drainage pump, made through execute_blender_code; no external assets."""
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
    p.inputs['Roughness'].default_value = .35
    return m

teal = material('Painted iron', (.035, .18, .19), .5)
steel = material('Machined steel', (.34, .48, .49), .75)
dark = material('Rubber and vents', (.012, .03, .036), .1)
brass = material('Brass fasteners', (.65, .39, .10), .7)
lamp = material('Status lamp', (.9, .25, .04))

def cube(name, loc, scale, mat, bevel=.06):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    b = o.modifiers.new('Soft machined edges', 'BEVEL')
    b.width = bevel
    b.segments = 2
    return o

def cylinder(name, loc, radius, depth, mat, axis='X', vertices=32):
    rotation = (0, math.pi/2, 0) if axis == 'X' else (math.pi/2, 0, 0) if axis == 'Y' else (0, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat)
    b = o.modifiers.new('Rim bevel', 'BEVEL')
    b.width = .025
    b.segments = 2
    return o

cube('PumpBase', (0, 0, -.72), (3.1, 1.28, .2), steel)
for x in (-1.23, 1.23):
    for y in (-.47, .47):
        cylinder('MountingBolt', (x, y, -.59), .09, .08, brass, 'Z', 6)
cylinder('PumpHousing', (.56, 0, 0), .62, .56, teal)
cylinder('InspectionFace', (.88, 0, 0), .49, .08, steel)
cylinder('Inlet', (1.22, 0, 0), .23, .64, dark)
cylinder('InletFlange', (1.55, 0, 0), .36, .12, steel)
cylinder('InletMouth', (1.62, 0, 0), .22, .014, dark)
cylinder('DriveShaft', (-.1, 0, 0), .14, .5, brass)
cylinder('ElectricMotor', (-.72, 0, 0), .43, 1.0, teal)
for x in (-1.15, -1.02, -.89, -.76, -.63, -.5, -.37):
    cylinder('MotorCoolingFin', (x, 0, 0), .47, .045, steel)
cylinder('MotorBack', (-1.27, 0, 0), .36, .16, dark)
for x in (-.85, .55):
    cube('Foot', (x, 0, -.46), (.36, .66, .35), teal)
cylinder('Outlet', (.56, 0, .65), .2, .65, teal, 'Z')
cylinder('OutletFlange', (.56, 0, .99), .29, .1, steel, 'Z')
cylinder('OutletMouth', (.56, 0, 1.05), .18, .015, dark, 'Z')
cube('TerminalBox', (-.75, -.07, .54), (.54, .5, .26), dark)
status = cylinder('StatusIndicator', (-.68, -.33, .57), .095, .035, lamp, 'Y')
for a in range(8):
    angle = a * math.pi/4
    cylinder('HousingBolt', (.94, .53*math.sin(angle), .53*math.cos(angle)), .055, .07, brass, vertices=6)

scene = bpy.context.scene
scene.world.color = (.1, .1, .1)
bpy.ops.object.camera_add(location=(4.4, -6.5, 3.8))
camera = bpy.context.object
camera.rotation_euler = (Vector((.05, 0, .12))-camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 4.0
scene.camera = camera
for loc, power, size in [((1, -4, 5), 850, 4), ((-4, -1, 2), 600, 3), ((1, 3, 4), 950, 3)]:
    bpy.ops.object.light_add(type='AREA', location=loc)
    light = bpy.context.object
    light.data.energy = power
    light.data.size = size
    light.rotation_euler = (-light.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.engine = 'BLENDER_EEVEE_NEXT' if bpy.app.version >= (4, 2, 0) else 'BLENDER_EEVEE'
scene.render.resolution_x = 480
scene.render.resolution_y = 360
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = True
for state, color in [('fault', (.95, .24, .035)), ('idle', (.13, .23, .25)), ('live', (.12, .95, .58))]:
    lamp.diffuse_color = (*color, 1)
    shader = lamp.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Emission Color'].default_value = (*color, 1)
    shader.inputs['Emission Strength'].default_value = 3 if state == 'live' else .1
    scene.render.filepath = LAB_OUTPUT+'/pump_'+state+'.png'
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=LAB_OUTPUT+'/pump.blend')
bpy.ops.export_scene.gltf(filepath=LAB_OUTPUT+'/pump.glb', export_format='GLB', use_selection=False)
print('ECHO_PUMP_DRAINAGE_PUMP_CREATED', bpy.app.version_string)
