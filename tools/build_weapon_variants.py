"""Original SG-8 and SR-5 models; executed by build_assets.py with shared helpers.

All variants use the same receiver/grip origin and export named optic/muzzle
anchors. Detachable magazines fit the existing magazine reload gesture.
"""
def tube(name, loc, radius, length, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=length,
                                      location=loc, rotation=(math.pi / 2, 0, 0))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new('Edge bevel', 'BEVEL')
    bevel.width = 0.003
    bevel.segments = 2
    obj.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    return obj


def optic_ring(name, y, z, radius):
    # Open rings preserve a real view through the optic, without opaque lenses.
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=8,
        location=(0, y, z), rotation=(math.pi / 2, 0, 0),
        major_radius=radius, minor_radius=0.007)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(steel)


def scope_body():
    vertices = []
    for y, radius in [(-0.14, 0.036), (0.16, 0.036), (-0.14, 0.028), (0.16, 0.028)]:
        for i in range(24):
            angle = i * math.tau / 24
            vertices.append((math.sin(angle) * radius, y, 0.145 + math.cos(angle) * radius))
    faces = []
    for a, b in [(0, 24), (72, 48), (48, 0), (24, 72)]:
        for i in range(24):
            j = (i + 1) % 24
            faces.append((a + i, a + j, b + j, b + i))
    mesh = bpy.data.meshes.new('Open scope tube')
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(steel)
    obj = bpy.data.objects.new('Scope housing', mesh)
    bpy.context.collection.objects.link(obj)


for kind in ['shotgun', 'marksman']:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    stock_mat = material(kind + ' composite', (0.35, 0.23, 0.13) if kind == 'shotgun' else (0.24, 0.31, 0.20))
    box('Upper receiver', (0, 0.015, 0), (0.105, 0.36, 0.115), steel)
    box('Lower receiver', (0, -0.015, -0.065), (0.085, 0.23, 0.07), stock_mat)
    box('Pistol grip', (0, -0.115, -0.15), (0.07, 0.075, 0.17), stock_mat).rotation_euler.x = 0.2
    box('Butt stock', (0, -0.30, -0.025), (0.085, 0.29, 0.14), stock_mat)
    box('Butt plate', (0, -0.455, -0.025), (0.10, 0.035, 0.18), steel)
    box('Identification plate', (0.055, -0.02, 0.02), (0.005, 0.08, 0.024), brass, 0.001)
    if kind == 'shotgun':
        tube('Heavy barrel', (0, 0.39, 0.025), 0.032, 0.46, steel)
        tube('Barrel shroud', (0, 0.27, 0.025), 0.046, 0.20, steel)
        box('Hand guard', (0, 0.225, -0.045), (0.115, 0.24, 0.095), stock_mat)
        for i in range(7):
            box('Guard rib %02d' % i, (0, 0.13 + i * 0.032, -0.045), (0.123, 0.012, 0.105), steel, 0.002)
        box('Magazine', (0, 0.01, -0.17), (0.095, 0.13, 0.19), steel)
        box('Optic base', (0, -0.015, 0.072), (0.05, 0.08, 0.028), steel)
        optic_ring('Ghost ring', -0.015, 0.105, 0.027)
        box('Front sight', (0, 0.57, 0.080), (0.007, 0.016, 0.05), brass, 0.001)
        anchor('SightAnchor', (0, -0.015, 0.105))
        anchor('MuzzleAnchor', (0, 0.625, 0.025))
    else:
        tube('Long barrel', (0, 0.48, 0.015), 0.020, 0.70, steel)
        box('Hand guard', (0, 0.24, -0.015), (0.095, 0.30, 0.10), stock_mat)
        box('Magazine', (0, 0.01, -0.125), (0.07, 0.10, 0.11), steel)
        box('Muzzle brake', (0, 0.835, 0.015), (0.055, 0.085, 0.055), steel)
        for y in [-0.085, 0.08]:
            box('Scope mount', (0, y, 0.085), (0.04, 0.025, 0.07), steel)
        scope_body()
        for i, y in enumerate([-0.14, 0.16]):
            optic_ring('Scope ring %02d' % i, y, 0.145, 0.038)
        box('Scope spine', (0, 0.01, 0.105), (0.02, 0.30, 0.017), steel)
        box('Elevation turret', (0, 0.015, 0.186), (0.03, 0.035, 0.022), steel)
        box('Bolt handle', (0.08, -0.08, 0.01), (0.07, 0.026, 0.026), steel)
        for sign in [-1, 1]:
            box('Folded bipod', (sign * 0.052, 0.34, -0.06), (0.018, 0.21, 0.025), steel)
        anchor('SightAnchor', (0, -0.14, 0.145))
        anchor('MuzzleAnchor', (0, 0.88, 0.015))
    merge_weapon()
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (kind + '.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT / (kind + '.glb')), export_format='GLB', use_selection=True)
    print('WEAPON_BUILT', kind)
