"""Original curved grass geometry. Run with Blender --background --python."""
from pathlib import Path
import math
import random
import bpy

root = Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
rng = random.Random(6137)
vertices, faces, colors = [], [], []
for blade in range(9):
    angle = rng.random() * math.tau
    height = rng.uniform(0.16, 0.38)
    lean = rng.uniform(0.07, 0.19)
    base_x, base_y = rng.uniform(-0.10, 0.10), rng.uniform(-0.10, 0.10)
    width = rng.uniform(0.010, 0.019)
    offset = len(vertices)
    for step in range(5):
        t = step / 4
        center_x = base_x + math.cos(angle) * lean * t*t
        center_y = base_y + math.sin(angle) * lean * t*t
        for side in [-1, 1]:
            spread = width * (1-t) * side
            vertices.append((center_x - math.sin(angle)*spread, center_y + math.cos(angle)*spread, height*t))
            colors.append((0.045 + t*0.14, 0.055 + t*0.15, 0.020 + t*0.055, 1))
    for step in range(4):
        n = offset + step*2
        faces.append((n,n+1,n+3,n+2))
mesh = bpy.data.meshes.new('Curved grass blades');mesh.from_pydata(vertices, [], faces);mesh.update()
attribute = mesh.color_attributes.new(name='Grass color', type='FLOAT_COLOR', domain='POINT')
for item, color in zip(attribute.data, colors):item.color = color
for polygon in mesh.polygons:polygon.use_smooth = True
obj = bpy.data.objects.new('Grass tuft',mesh);bpy.context.collection.objects.link(obj)
mat = bpy.data.materials.new('Grass fiber');mat.use_nodes = True
shader = mat.node_tree.nodes['Principled BSDF'];shader.inputs['Roughness'].default_value = 1
color = mat.node_tree.nodes.new('ShaderNodeVertexColor');color.layer_name = 'Grass color'
mat.node_tree.links.new(color.outputs['Color'],shader.inputs['Base Color']);obj.data.materials.append(mat)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/grass.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(root/'client/assets/realism/grass.glb'),export_format='GLB',export_apply=True)
print('GRASS_ASSET_PASS blades=9 triangles=72')
