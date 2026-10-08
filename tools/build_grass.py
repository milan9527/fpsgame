"""Original curved grass geometry. Run with Blender --background --python."""
from pathlib import Path
import math
import random
import sys
import bpy

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "tools"))
from strip_grass_degenerates import strip
from compact_grass_vertices import compact
bpy.ops.wm.read_factory_settings(use_empty=True)
def species(name, count, heights, leans, widths, broad=False):
    rng = random.Random(6137 + count)
    vertices, faces, colors = [], [], []
    for blade in range(count):
        angle = rng.random() * math.tau
        height, lean = rng.uniform(*heights), rng.uniform(*leans)
        radius = rng.uniform(0, 0.065)
        width, dry = rng.uniform(*widths), rng.random()
        offset = len(vertices)
        steps = 12 if broad else 4
        twist = rng.uniform(-1.1, 1.1) if broad else 0.0
        asymmetry = rng.uniform(-0.22, 0.22) if broad else 0.0
        for step in range(steps + 1):
            t = step / steps
            # A narrow petiole supports a cupped lamina, rather than a diamond
            # reaching all the way to the soil. Preserve the planting footprint.
            lamina = max(0.0, (t - 0.25) / 0.75)
            profile = ((0.025 if t < 0.25 else math.sin(math.pi*lamina)**1.25)
                       if broad else (1-t))
            if broad:
                profile *= 1.0 + 0.12 * math.sin(lamina * math.pi * 8)
            heading = angle + twist * t * t
            for side in [-1, 0, 1]:
                spread = width * profile * side * (1 + asymmetry * side)
                ridge = width * 0.45 * profile if side == 0 else 0
                curl = (width * profile * (0.40 * side + 0.42 * side * side)
                        * math.sin(t * math.pi * 1.5) if broad else 0)
                vertices.append((math.cos(angle)*(radius+lean*t*t)-math.sin(heading)*spread,
                                 math.sin(angle)*(radius+lean*t*t)+math.cos(heading)*spread,
                                 height*(t-0.3*t*t*t)+ridge+curl))
                colors.append((0.030+t*(0.045+dry*0.045), 0.044+t*(0.075+dry*0.030),
                               0.014+t*(0.020+dry*0.025), 1))
        for step in range(steps):
            for side in range(2):
                n = offset+step*3+side
                faces.append((n,n+1,n+4,n+3))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces); mesh.update()
    attribute = mesh.color_attributes.new(name='Grass color', type='FLOAT_COLOR', domain='POINT')
    for item, color in zip(attribute.data, colors): item.color = color
    for polygon in mesh.polygons: polygon.use_smooth = True
    obj = bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    mat = bpy.data.materials.new(name+' fiber'); mat.use_nodes = True
    shader = mat.node_tree.nodes['Principled BSDF']; shader.inputs['Roughness'].default_value = 1
    color = mat.node_tree.nodes.new('ShaderNodeVertexColor'); color.layer_name = 'Grass color'
    mat.node_tree.links.new(color.outputs['Color'],shader.inputs['Base Color']); mesh.materials.append(mat)
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(root/f'client/assets/realism/{name}.glb'),export_format='GLB',use_selection=True,export_apply=True)
    print(f"GRASS_DEGENERATES {strip(root/f'client/assets/realism/{name}.glb')}")
    print(f"GRASS_COMPACT {compact(root/f'client/assets/realism/{name}.glb')}")
    print(f'GRASS_SPECIES_PASS name={name} blades={count} triangles={len(faces)*2}')

species('grass', 18, (0.07,0.18), (0.06,0.18), (0.008,0.014))
species('grass_fine', 13, (0.24,0.58), (0.03,0.16), (0.004,0.008))
species('grass_broadleaf', 11, (0.09,0.24), (0.06,0.17), (0.007,0.016), True)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/grass.blend'),compress=True)
print('GRASS_ASSET_PASS species=3')
