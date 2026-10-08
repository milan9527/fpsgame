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
    # The optical bore is independent of the stepped external controls. Keep
    # the proven eye cone while giving the diopter, zoom and objective collars
    # real silhouettes (no opaque discs or rings projecting into the sight).
    bore = [(-.155,.041),(-.12,.043),(-.07,.049),
            (.025,.061),(.065,.069),(.085,.069)]
    profile = [(-.155,.041),(-.152,.045),(-.148,.046),
               (-.132,.046),(-.129,.043),(-.119,.044),
               (-.116,.050),(-.112,.052),(-.082,.055),
               (-.078,.053),(-.075,.049),(-.070,.049),
               (.025,.061),(.059,.068),(.061,.072),
               (.078,.072),(.082,.071),(.085,.069)]
    anodized = material('Scope / anodized housing', (.021,.026,.025), .72)
    anodized.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = .46
    control = material('Scope / matte control rings', (.015,.019,.017), .25)
    control.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = .68
    interior = material('Scope / light absorbing bore', (.009,.011,.010), 0)
    def bore_radius(y):
        for (a, ra), (b, rb) in zip(bore, bore[1:]):
            if a <= y <= b:
                return ra + (rb-ra)*(y-a)/(b-a) - .0025
        raise ValueError(y)
    vertices, faces = [], []
    segments = 128
    for inner in [False, True]:
        for y, radius in profile:
            for i in range(segments):
                angle=i*math.tau/segments
                r = bore_radius(y) if inner else radius
                if not inner and (-.112 <= y <= -.082 or -.148 <= y <= -.132):
                    r += .0009*(.5+.5*math.cos(angle*32))
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
    for mat in [anodized, control, interior]:
        mesh.materials.append(mat)
    for polygon in mesh.polygons:
        polygon.use_smooth=True
        if polygon.index < (rings-1)*segments*2:
            ring = polygon.index // (segments*2)
            mid_y = (profile[ring][0]+profile[ring+1][0])*.5
            polygon.material_index = (2 if polygon.index % 2 else
                (1 if mid_y < -.075 or .061 < mid_y < .082 else 0))
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
    if os.environ.get('ASSET_ONLY') in ('shotgun', 'marksman') and os.environ['ASSET_ONLY'] != kind:
        continue
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    stock_mat = material(kind + ' composite', (0.024, 0.030, 0.027) if kind == 'shotgun' else (0.027, 0.034, 0.029))
    if kind == 'shotgun':
        # Broad planar walls and a sloping rear shoulder, with machined edge
        # breaks instead of the former inflated, smoothly shaded capsule.
        receiver = side_profile('Shotgun machined receiver', [
            (-.163,-.025),(-.163,.009),(-.126,.041),
            (-.095,.048),(.116,.048),(.174,.027),
            (.190,-.021),(.145,-.044),(-.110,-.047)], .074, receiver_alloy)
        for side in [-1, 1]:
            recess(receiver, (side*.037,-.062,.008), (.009,.079,.026))
            box('Action side inset', (side*.033,-.062,.008),
                (.002,.068,.017), steel,.001)
        box('Receiver crown strip', (0,.047,.048),
            (.023,.193,.003), receiver_edge,.001)
    else:
        receiver = contoured_stock('Machined rounded action', [
            (-.165,.039,-.025,.008),(-.140,.057,-.040,.031),
            (-.102,.070,-.049,.048),(.110,.070,-.049,.048),
            (.155,.063,-.041,.040),(.195,.052,-.030,.023)], steel)
    recess(receiver, (.036,.046,.012), (.016,.103,.033))
    box('Recessed bolt', (.030,.046,.012), (.003,.09,.025), bolt_metal,.001)
    side_profile('Lower receiver',
        [(-.12,-.047),(.12,-.047),(.087,-.092),(-.08,-.092),(-.12,-.075)],
        .064, stock_mat)
    if kind == 'shotgun':
        # Loft along the grip's length, with a palm swell and rounded heel.
        grip = contoured_stock('Palm swell grip', [
            (-.080,.043,-.030,.026),(-.060,.061,-.035,.032),
            (-.018,.067,-.036,.037),(.035,.059,-.030,.033),
            (.075,.046,-.025,.026)], stock_mat)
        grip.rotation_euler.x = math.pi / 2 + .2
        grip.location = (0,-.115,-.15)
    else:
        grip = contoured_stock('Precision palm grip', [
            (-.083,.042,-.024,.025),(-.064,.059,-.032,.032),
            (-.018,.068,-.036,.038),(.034,.062,-.032,.035),
            (.078,.047,-.025,.027)], stock_mat)
        grip.rotation_euler.x = math.pi / 2 + .2
        grip.location = (0,-.115,-.15)
    # A narrow wrist broadens into a dropped shoulder pad, rather than a box
    # protruding from the receiver. Separate rubber and composite surfaces.
    stock_stations = [
        (-.150,.047,-.038,.016),(-.195,.042,-.041,.019),
        (-.245,.049,-.049,.025),(-.290,.060,-.062,.029),
        (-.360,.074,-.085,.028),(-.420,.077,-.123,.018),
        (-.445,.072,-.115,.007)]
    if kind == 'shotgun':
        # Slim neck and dropped heel: the near-camera comb previously filled
        # the lower right corner as a wide wedge. Keep the grip interface.
        stock_stations = [
            (-.150,.047,-.038,.016),(-.181,.042,-.039,.014),
            (-.215,.035,-.042,.008),(-.250,.038,-.053,.005),
            (-.290,.045,-.067,.007),(-.335,.051,-.086,.008),
            (-.385,.057,-.111,.002),(-.425,.061,-.124,-.005),
            (-.445,.060,-.118,-.009)]
    stock = contoured_stock('Butt stock', stock_stations,
                            polymer if kind == 'shotgun' else stock_mat)
    shoulder_pad(-.445, -.063 if kind == 'shotgun' else -.059,
                 width=.066 if kind == 'shotgun' else .080)
    if kind == 'shotgun':
        # A separate low cheek saddle makes the stock/action transition legible
        # in ADS without raising the existing sight line or hand contacts.
        contoured_stock('Shotgun cheek saddle', [
            (-.249,.029,.003,.006),(-.269,.035,.004,.012),
            (-.299,.041,.005,.015),(-.345,.045,.006,.015),
            (-.374,.046,.001,.010),(-.397,.044,-.001,.002)],
            comb_rubber)
        for side in [-1,1]:
            recess(stock, (side*.026,-.347,-.044), (.008,.078,.023))
        cylinder('Stock receiver collar', (0,-.169,-.010),
                 .026,.012,receiver_edge,'Y')
    if kind == 'marksman':
        contoured_stock('Stock cheek rest', [
            (-.235,.048,.006,.024),(-.262,.072,.006,.043),
            (-.350,.080,.006,.045),(-.373,.075,.006,.043),
            (-.398,.056,.006,.021)], polymer)
        recess(stock, (0,-.333,-.033), (.10,.072,.020))
    for side in [-1,1]:
        cylinder('Stock sling socket', (side*(.029 if kind == 'shotgun' else .036),-.414,-.073),
                 .008,.004,steel,'X')
    box('Serial inset', (-.038,-.035,-.012), (.002,.040,.010), bolt_metal,.001)
    for side in [-1,1]:
        for y in [-0.085,0.12]:
            cylinder('Receiver pin',(side*.037,y,-.027),.004,.003,bolt_metal,'X')
    for y in [-.085,-.055,-.025,.005,.035]:
        box('Receiver rail lug',(0,y,.053),(.035,.012,.010),steel,.001)
    box('Trigger guard bottom',(0,-0.054,-0.123),(0.024,0.075,0.012),steel,0.003)
    box('Trigger guard front',(0,-0.016,-0.099),(0.024,0.012,0.06),steel,0.003)
    if kind == 'shotgun':
        tube('Heavy barrel', (0, 0.39, 0.025), 0.032, 0.46, steel)
        tube('Barrel shroud', (0, 0.27, 0.025), 0.046, 0.20, steel)
        # Oval palm bed follows the support hand; shallow moulded bands replace
        # oversized circular hoops while retaining the existing contact envelope.
        contoured_stock('Palm fitted fore-end', [
            (.105,.077,-.079,-.008),(.123,.099,-.093,.002),
            (.170,.110,-.100,.007),(.250,.108,-.099,.007),
            (.317,.093,-.088,.002),(.345,.071,-.070,-.008)], stock_mat)
        for i in range(6):
            y = .145 + i*.031
            width = .110 if y < .28 else .100
            contoured_stock('Shallow fore-end traction band %02d' % i, [
                (y-.003,width,-.099,.006),
                (y,width+.002,-.101,.007),
                (y+.003,width,-.099,.006)], polymer)
        box('Magazine', (0, 0.01, -0.17), (0.095, 0.13, 0.19), steel)
        box('Optic foot', (0, -0.015, 0.062), (0.036, 0.05, 0.012), steel,.002)
        box('Ghost ring pedestal', (0, -0.015, 0.075), (0.018, 0.018, 0.02), steel,.002)
        optic_ring('Ghost ring', -0.015, 0.105, 0.027, .003)
        box('Front sight', (0, 0.57, 0.080), (0.007, 0.016, 0.05), brass, 0.001)
        anchor('SightAnchor', (0, -0.015, 0.105))
        anchor('MuzzleAnchor', (0, 0.625, 0.025))
    else:
        tube('Long barrel', (0, 0.48, 0.015), 0.020, 0.70, steel)
        # An oval, tapered shell with a continuous bore and milled openings.
        # Preserve the lower support-hand envelope; the barrel is visible
        # through the slots instead of painted rectangles on a solid tube.
        handguard = contoured_stock('Vented precision fore-end', [
            (.090,.073,-.053,.025),(.115,.098,-.065,.034),
            (.185,.100,-.065,.034),(.305,.091,-.060,.032),
            (.365,.080,-.054,.030),(.390,.068,-.046,.025)], stock_mat)
        recess(handguard, (0,.245,.006), (.058,.33,.050))
        for i in range(5):
            recess(handguard, (0,.142+i*.047,.002), (.120,.029,.022))
        for y in [0.39,0.61,0.80]:tube('Barrel shoulder',(0,y,0.015),0.023,0.018,steel)
        box('Magazine', (0, 0.01, -0.125), (0.07, 0.10, 0.11), steel)
        box('Muzzle brake', (0, 0.835, 0.015), (0.055, 0.085, 0.055), steel)
        for y in [-0.085, 0.045]:
            box('Scope mount foot', (0, y, 0.064), (0.037, 0.027, 0.014), steel,.002)
            box('Scope mount stem', (0, y, 0.079), (0.017, 0.018, 0.024), steel,.001)
        scope_body()
        for i, (y, radius) in enumerate([(-0.14, 0.042), (0.073, 0.069)]):
            optic_ring('Scope ring %02d' % i, y, 0.145, radius, 0.001)
        cylinder('Elevation turret neck',(0,0.015,0.2085),0.012,0.015,steel,'Z')
        cylinder('Windage turret neck',(0.062,0.015,0.145),0.010,0.014,steel,'X')
        cylinder('Elevation turret',(0,0.015,0.224),0.019,0.026,steel,'Z')
        cylinder('Windage turret',(0.076,0.015,0.145),0.016,0.025,steel,'X')
        for i in range(16):
            angle=i*math.tau/16
            box('Turret knurl',(math.cos(angle)*0.019,0.015+math.sin(angle)*0.019,0.227),(0.003,0.003,0.016),polymer,0.0005)
        # Inset caps, a sealing shoulder and small calibration dashes break up
        # the plain knob without changing the established optical alignment.
        cylinder('Elevation seal',(0,.015,.212),.020,.003,polymer,'Z')
        cylinder('Elevation inset cap',(0,.015,.238),.015,.002,bolt_metal,'Z')
        cylinder('Windage inset cap',(.089,.015,.145),.012,.002,bolt_metal,'X')
        for i in range(12):
            angle = i*math.tau/12
            tick = box('Elevation calibration %02d' % i,
                (.014*math.cos(angle),.015+.014*math.sin(angle),.2392),
                (.003 if i%3==0 else .0018,.00065,.00035),brass,0)
            tick.rotation_euler.z = angle
        cylinder('Bolt handle shaft',(0.08,-0.08,0.01),0.009,0.07,steel,'X')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=0.018,location=(0.115,-0.08,0.01))
        knob=bpy.context.object;knob.name='Bolt knob';knob.data.materials.append(polymer)
        for polygon in knob.data.polygons:polygon.use_smooth=True
        for sign in [-1, 1]:
            box('Folded bipod', (sign * 0.052, 0.34, -0.06), (0.018, 0.21, 0.025), steel)
        anchor('SightAnchor', (0, -0.14, 0.145))
        anchor('MuzzleAnchor', (0, 0.88, 0.015))
    decorate_magazine()
    if kind == 'shotgun':
        # Variant geometry is created after the shared finish bake. Give its
        # polymer/rubber textures the same metric scale as the carbine.
        for obj in bpy.context.scene.objects:
            if obj.type != 'MESH':
                continue
            uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='FinishUV')
            for polygon in obj.data.polygons:
                axis = max(range(3), key=lambda i: abs(polygon.normal[i]))
                axes = [i for i in range(3) if i != axis]
                for index in polygon.loop_indices:
                    co = obj.matrix_world @ obj.data.vertices[obj.data.loops[index].vertex_index].co
                    uv.data[index].uv = (co[axes[0]] / .16, co[axes[1]] / .16)
    merge_weapon()
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (kind + '.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT / (kind + '.glb')), export_format='GLB', use_selection=True)
    print('WEAPON_BUILT', kind)
