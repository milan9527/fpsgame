"""Original SG-8 and SR-5 models; executed by build_assets.py with shared helpers.

All variants use the same receiver/grip origin and export named optic/muzzle
anchors. Detachable magazines fit the existing magazine reload gesture.
"""
def tube(name, loc, radius, length, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=length,
                                      location=loc, rotation=(math.pi / 2, 0, 0))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new('Edge bevel', 'BEVEL')
    bevel.width = 0.003
    bevel.segments = 2
    obj.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    return obj


def optic_ring(name, y, z, radius, thickness=0.007):
    # Open rings preserve a real view through the optic, without opaque lenses.
    bpy.ops.mesh.primitive_torus_add(major_segments=64, minor_segments=8,
        location=(0, y, z), rotation=(math.pi / 2, 0, 0),
        major_radius=radius, minor_radius=thickness)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(steel)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True


def scope_body():
    # Continuous outer bell and open bore: the optic center remains unobstructed.
    profile = [(-0.155,0.041),(-0.12,0.041),(-0.09,0.039),(0.025,0.039),(0.05,0.044),(0.085,0.044)]
    vertices, faces = [], []
    segments = 64
    for inner in [False, True]:
        for y, radius in profile:
            for i in range(segments):
                angle=i*math.tau/segments
                # A straight, wide bore avoids the tunnel-like pinhole created
                # by the old long, constricted objective housing.
                r=0.036 if inner else radius
                vertices.append((math.sin(angle)*r,y,0.145+math.cos(angle)*r))
    rings=len(profile); inside=rings*segments
    for ring in range(rings-1):
        for i in range(segments):
            j=(i+1)%segments;a=ring*segments;b=(ring+1)*segments
            faces.append((a+i,a+j,b+j,b+i))
            faces.append((inside+a+i,inside+b+i,inside+b+j,inside+a+j))
    for ring in [0,rings-1]:
        a=ring*segments
        for i in range(segments):
            j=(i+1)%segments
            faces.append((a+i,inside+a+i,inside+a+j,a+j) if ring==0 else (a+i,a+j,inside+a+j,inside+a+i))
    mesh=bpy.data.meshes.new('Open profiled scope');mesh.from_pydata(vertices,[],faces)
    mesh.materials.append(steel)
    for polygon in mesh.polygons:polygon.use_smooth=True
    obj=bpy.data.objects.new('Scope housing',mesh);bpy.context.collection.objects.link(obj)


def decorate_magazine():
    magazine=bpy.data.objects.get('Magazine')
    pieces=[magazine]
    for side in [-1,1]:
        for y in [-0.025,0.025]:
            pieces.append(box('Magazine rib',(side*magazine.dimensions.x*0.5,y,magazine.location.z),
                              (0.006,0.012,magazine.dimensions.z*0.76),polymer,0.002))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in pieces:
        obj.select_set(True);bpy.context.view_layer.objects.active=obj
        for modifier in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.context.view_layer.objects.active=magazine;bpy.ops.object.join();magazine.name='Magazine'


for kind in ['shotgun', 'marksman']:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    stock_mat = material(kind + ' composite', (0.065, 0.041, 0.023) if kind == 'shotgun' else (0.038, 0.052, 0.026))
    box('Upper receiver', (0, 0.015, 0), (0.105, 0.36, 0.115), steel)
    box('Lower receiver', (0, -0.015, -0.065), (0.085, 0.23, 0.07), stock_mat)
    box('Pistol grip', (0, -0.115, -0.15), (0.07, 0.075, 0.17), stock_mat).rotation_euler.x = 0.2
    box('Butt stock', (0, -0.30, -0.025), (0.085, 0.29, 0.14), stock_mat)
    box('Butt plate', (0, -0.455, -0.025), (0.10, 0.035, 0.18), steel)
    box('Identification plate', (0.055, -0.02, 0.02), (0.005, 0.08, 0.024), brass, 0.001)
    for side in [-1,1]:
        box('Receiver side plate',(side*0.054,0.01,0.012),(0.006,0.21,0.048),polymer,0.003)
        for y in [-0.105,0.065]:cylinder('Receiver screw',(side*0.059,y,-0.012),0.006,0.005,steel,'X')
    box('Trigger guard bottom',(0,-0.054,-0.123),(0.024,0.075,0.012),steel,0.003)
    box('Trigger guard front',(0,-0.016,-0.099),(0.024,0.012,0.06),steel,0.003)
    if kind == 'shotgun':
        tube('Heavy barrel', (0, 0.39, 0.025), 0.032, 0.46, steel)
        tube('Barrel shroud', (0, 0.27, 0.025), 0.046, 0.20, steel)
        tube('Rounded fore-end', (0, 0.225, -0.045), 0.055, 0.24, stock_mat)
        for i in range(7):
            tube('Fore-end grip rib %02d' % i, (0, 0.13 + i * 0.032, -0.045), 0.059, 0.010, polymer)
        box('Magazine', (0, 0.01, -0.17), (0.095, 0.13, 0.19), steel)
        box('Optic base', (0, -0.015, 0.072), (0.05, 0.08, 0.028), steel)
        optic_ring('Ghost ring', -0.015, 0.105, 0.027)
        box('Front sight', (0, 0.57, 0.080), (0.007, 0.016, 0.05), brass, 0.001)
        anchor('SightAnchor', (0, -0.015, 0.105))
        anchor('MuzzleAnchor', (0, 0.625, 0.025))
    else:
        tube('Long barrel', (0, 0.48, 0.015), 0.020, 0.70, steel)
        tube('Rounded handguard', (0, 0.24, -0.015), 0.050, 0.30, stock_mat)
        for side in [-1,1]:
            for i in range(6):
                box('Vent inset',(side*0.048,0.125+i*0.046,-0.004),(0.005,0.029,0.024),polymer,0.004)
        for y in [0.39,0.61,0.80]:tube('Barrel shoulder',(0,y,0.015),0.023,0.018,steel)
        box('Magazine', (0, 0.01, -0.125), (0.07, 0.10, 0.11), steel)
        box('Muzzle brake', (0, 0.835, 0.015), (0.055, 0.085, 0.055), steel)
        for y in [-0.085, 0.08]:
            box('Scope mount', (0, y, 0.08), (0.04, 0.025, 0.04), steel)
        scope_body()
        for i, (y, radius) in enumerate([(-0.14, 0.041), (0.073, 0.044)]):
            optic_ring('Scope ring %02d' % i, y, 0.145, radius, 0.002)
        box('Scope spine', (0, -0.03, 0.096), (0.02, 0.20, 0.009), steel)
        cylinder('Elevation turret',(0,0.015,0.2),0.019,0.026,steel,'Z')
        cylinder('Windage turret',(0.052,0.015,0.145),0.016,0.025,steel,'X')
        for i in range(16):
            angle=i*math.tau/16
            box('Turret knurl',(math.cos(angle)*0.019,0.015+math.sin(angle)*0.019,0.203),(0.003,0.003,0.016),polymer,0.0005)
        cylinder('Bolt handle shaft',(0.08,-0.08,0.01),0.009,0.07,steel,'X')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=0.018,location=(0.115,-0.08,0.01))
        knob=bpy.context.object;knob.name='Bolt knob';knob.data.materials.append(polymer)
        for polygon in knob.data.polygons:polygon.use_smooth=True
        for sign in [-1, 1]:
            box('Folded bipod', (sign * 0.052, 0.34, -0.06), (0.018, 0.21, 0.025), steel)
        anchor('SightAnchor', (0, -0.14, 0.145))
        anchor('MuzzleAnchor', (0, 0.88, 0.015))
    decorate_magazine()
    merge_weapon()
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (kind + '.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT / (kind + '.glb')), export_format='GLB', use_selection=True)
    print('WEAPON_BUILT', kind)
