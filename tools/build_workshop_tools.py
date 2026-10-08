"""Original bevelled workshop hand tools; coordinates in Godot metres."""
from pathlib import Path
import math
import bpy
from mathutils import Vector, Matrix
ROOT = Path(__file__).resolve().parent.parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
def v(p): return Vector((p[0], -p[2], p[1]))
def mat(name, color, metal, rough):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    s=m.node_tree.nodes['Principled BSDF']; s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal; s.inputs['Roughness'].default_value=rough
    return m
steel=mat('Satin forged steel',(.32,.35,.34),.85,.34)
rubber=mat('Charcoal moulded rubber',(.038,.047,.042),0,.83)
inset=mat('Worn ochre grip',(.19,.15,.075),0,.76)
vise_paint=mat('Cast iron muted blue enamel',(.065,.105,.115),.45,.62)
def finish(o,name,m,bevel=.002):
    o.name=name; o.data.materials.append(m)
    if bevel:
        b=o.modifiers.new('Machined edge radius','BEVEL'); b.width=bevel; b.segments=3
        o.modifiers.new('Face weighted normals','WEIGHTED_NORMAL')
    return o
def box(name,p,size,m,bevel=.002):
    bpy.ops.mesh.primitive_cube_add(size=1,location=v(p)); o=bpy.context.object
    o.dimensions=(size[0],size[2],size[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,m,bevel)
def rod(name,a,b,r,m):
    a,b=v(a),v(b); bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=r,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object; o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return finish(o,name,m,.001)
def profile(name,x,y,z,points,depth):
    verts=[v((x+px,y+py,z+d)) for d in [-depth/2,depth/2] for px,py in points]
    n=len(points); faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o)
    return finish(o,name,steel,.0015)
for i in range(7):
    existing=set(bpy.data.objects)
    x=[-1.02,-.79,-.51,-.10,.12,.37,.92][i]
    # Hardware hooks visibly hold each tool away from the backing.
    rod('Pegboard hook',(x,1.90,0),(x,1.90,.052),.004,steel)
    if i<3:
        scale=.82+i*.14; top=2.02
        points=[(-.012,-.26),(-.017,-.055),(-.044,-.024),(-.047,.012),(-.031,.041),(-.022,.047),(-.022,.002),(.017,-.007),(.031,.035),(.041,.03),(.05,.002),(.042,-.028),(.017,-.058),(.012,-.26)]
        profile('Open jaw spanner',x,top,.045,[(a*scale,b*scale) for a,b in points],.012)
        bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=v((x,top-.278*scale,.045)),major_radius=.023*scale,minor_radius=.006*scale,rotation=(math.pi/2,0,0))
        finish(bpy.context.object,'Ring end',steel,0)
    elif i<6:
        rod('Screwdriver shaft',(x,1.77,.045),(x,2.06+(i%2)*.025,.045),.005,steel)
        box('Flat driver tip',(x,2.063+(i%2)*.025,.045),(.014,.025,.003),steel,.0005)
        # Rounded moulding with a waist and six shallow raised grip strips.
        rod('Grip core',(x,1.61,.045),(x,1.77,.045),.021,rubber)
        for j in range(6):
            angle=j*math.tau/6
            rod('Grip rib',(x+.018*math.cos(angle),1.63,.045+.018*math.sin(angle)),(x+.018*math.cos(angle),1.74,.045+.018*math.sin(angle)),.004,inset)
    else:
        rod('Hammer shank',(x,1.65,.045),(x,2.0,.045),.012,steel)
        rod('Hammer grip',(x,1.59,.045),(x,1.78,.045),.022,rubber)
        box('Forged hammer head',(x,2.01,.045),(.135,.055,.046),steel,.009)
        rod('Hammer striking face',(x-.072,2.01,.045),(x-.09,2.01,.045),.03,steel)
        profile('Hammer peen',x+.065,2.01,.045,[(0,-.024),(.06,-.009),(.06,.009),(0,.024)],.03)
    # Tool groups hang at different peg rows and settle slightly off vertical.
    # Move hooks with their tools so the hardware remains attached to the board.
    rise=[.045,-.06,.025,-.085,.055,-.035,-.015][i]
    angle=math.radians([-5,3,-2,6,-4,2,-7][i])
    pivot=v((x,1.90,0))
    transform=(Matrix.Translation(v((0,rise,0))) @ Matrix.Translation(pivot)
               @ Matrix.Rotation(angle,4,'Y') @ Matrix.Translation(-pivot))
    for tool in set(bpy.data.objects)-existing:
        tool.matrix_world=transform @ tool.matrix_world
# A small swivel bench vise, bolted through the front corner of the timber.
# Its jaws run along X and close along Z; the screw projects beyond the bench.
vx=-.92
rod('Vise swivel base',(vx,.973,.40),(vx,1.008,.40),.13,vise_paint)
box('Vise fixed casting',(vx,1.095,.37),(.19,.18,.23),vise_paint,.025)
box('Vise rear anvil',(vx,1.115,.235),(.16,.045,.11),steel,.006)
box('Fixed jaw casting',(vx,1.20,.405),(.245,.11,.065),vise_paint,.012)
box('Fixed serrated jaw',(vx,1.227,.444),(.225,.049,.014),steel,.002)
box('Sliding rectangular guide',(vx,1.069,.50),(.09,.075,.38),steel,.004)
box('Moving jaw casting',(vx,1.173,.59),(.245,.16,.075),vise_paint,.014)
box('Moving serrated jaw',(vx,1.227,.546),(.225,.049,.014),steel,.002)
rod('Vise screw',(vx,1.083,.60),(vx,1.083,.745),.019,steel)
rod('Screw handle hub',(vx,1.083,.73),(vx,1.083,.77),.036,vise_paint)
rod('Sliding tommy bar',(vx-.105,1.005,.755),(vx+.105,1.161,.755),.009,steel)
for x,y in [(vx-.105,1.005),(vx+.105,1.161)]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.015,location=v((x,y,.755)))
    finish(bpy.context.object,'Handle end stop',steel,0)
for dx,dz in [(-.095,-.065),(.095,-.065),(-.095,.065),(.095,.065)]:
    rod('Base mounting bolt',(vx+dx,1.002,.40+dz),(vx+dx,1.016,.40+dz),.012,steel)
for dx in [-.085,.085]:
    rod('Fixed jaw screw',(vx+dx,1.227,.449),(vx+dx,1.227,.454),.005,rubber)
    rod('Moving jaw screw',(vx+dx,1.227,.536),(vx+dx,1.227,.541),.005,rubber)
# A shallow parts tray and repair consumables keep the working centre clear.
# All props sit above the existing 0.97 m tabletop and inside its footprint.
tray=mat('Dull galvanized parts tray',(.23,.25,.24),.65,.55)
oil_body=mat('Opaque aged oil bottle',(.24,.19,.075),0,.72)
paper=mat('Faded bottle label',(.49,.46,.35),0,.93)
tx,tz=.81,.20
box('Parts tray floor',(tx,.979,tz),(.37,.014,.23),tray,.009)
for dx in [-.18,.18]:
    box('Tray folded short rim',(tx+dx,.999,tz),(.014,.044,.23),tray,.005)
for dz in [-.108,.108]:
    box('Tray folded long rim',(tx,.999,tz+dz),(.35,.044,.014),tray,.005)
for dx,dz in [(-.10,-.035),(.02,.042),(.095,-.024)]:
    rod('Loose service bolt',(tx+dx-.024,.996,tz+dz),(tx+dx+.022,.996,tz+dz+.014),.005,steel)
    rod('Loose bolt head',(tx+dx+.022,.996,tz+dz+.014),(tx+dx+.03,.996,tz+dz+.016),.009,steel)
box('Oil bottle body',(1.14,1.055,.065),(.082,.16,.06),oil_body,.014)
box('Oil bottle label',(1.14,1.05,.096),(.059,.07,.001),paper,.001)
rod('Oil bottle neck',(1.14,1.13,.065),(1.14,1.156,.065),.016,oil_body)
rod('Oil bottle cap',(1.14,1.151,.065),(1.14,1.177,.065),.02,rubber)
# A folded canvas service cloth, with irregular soft folds rather than a cube.
canvas=mat('Dusty olive service canvas',(.16,.18,.115),0,.96)
verts=[]; faces=[]
for j in range(17):
    for i in range(25):
        u=i/24; w=j/16
        x=-.30+u*.48+.012*math.sin(w*7+u*2)
        z=.22+w*.30+.008*math.sin(u*11+w)
        # Tapered diagonal creases avoid the previous regular corrugation.
        height=.980
        for centre,amplitude,width,slope in [
            (.21,.017,.075,.18),(.54,.009,.12,-.22),(.79,.021,.06,.12)
        ]:
            ridge=math.exp(-((u-centre-slope*(w-.5))/width)**2)
            height+=amplitude*ridge*(.25+.75*math.sin(math.pi*w)**2)
        height+=.004*math.sin(u*17+w*9)**2
        verts.append(v((x,height,z)))
for j in range(16):
    for i in range(24):
        a=j*25+i; faces.append((a,a+1,a+26,a+25))
mesh=bpy.data.meshes.new('Woven cloth folds')
mesh.from_pydata(verts,[],faces); mesh.update()
cloth=bpy.data.objects.new('Service cloth',mesh); bpy.context.collection.objects.link(cloth)
finish(cloth,'Service cloth',canvas,0)
for polygon in mesh.polygons: polygon.use_smooth=True
solid=cloth.modifiers.new('Cloth thickness','SOLIDIFY'); solid.thickness=.002
# Storage stays within the existing bench footprint, above its lower rails.
shelf=mat('Worn grey steel shelf',(.14,.17,.16),.35,.79)
box('Lower bench shelf',(0,.27,.24),(2.38,.035,.55),shelf,.006)
for z in [-.027,.507]:
    box('Shelf folded lip',(0,.294,z),(2.38,.05,.012),shelf,.002)
# An open sheet-metal tool tote: visible hollow interior, folded rim and handle.
cx,cz=.60,.23
box('Tote base',(cx,.306,cz),(.57,.025,.32),vise_paint,.006)
for x in [cx-.279,cx+.279]:
    box('Tote end',(x,.403,cz),(.012,.19,.32),vise_paint,.006)
    rod('Tote handle support',(x,.49,cz),(x,.62,cz),.012,steel)
for z in [cz-.154,cz+.154]:
    box('Tote side',(cx,.383,z),(.55,.15,.012),vise_paint,.005)
    rod('Tote rolled rim',(cx-.28,.46,z),(cx+.28,.46,z),.008,steel)
rod('Tote carry handle',(cx-.28,.62,cz),(cx+.28,.62,cz),.014,rubber)
# Coiled spare hose has a visible centre hole and an untidy free tail.
curve=bpy.data.curves.new('Spare hose sweep','CURVE'); curve.dimensions='3D'
curve.bevel_depth=.016; curve.bevel_resolution=3; curve.resolution_u=2
spline=curve.splines.new('POLY'); points=[]
for i in range(193):
    t=i/192*math.tau*3
    radius=.19+.008*math.sin(t*.45)
    points.append(v((-.65+radius*math.cos(t),.32+.034*i/192,.23+radius*math.sin(t))))
points.extend([v((-.38,.35,.26)),v((-.30,.33,.35)),v((-.36,.31,.43))])
spline.points.add(len(points)-1)
for point,co in zip(spline.points,points): point.co=(*co,1)
obj=bpy.data.objects.new('Coiled spare air hose',curve); bpy.context.collection.objects.link(obj)
obj.data.materials.append(rubber)
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active=obj; obj.select_set(True)
bpy.ops.object.convert(target='MESH')
# Surface-mounted electrical supply and an actual luminaire above the board.
# Wall is behind local z=0; keep this assembly within the bench wall bay.
enamel=mat('Aged ivory electrical enamel',(.39,.40,.34),.18,.68)
conduit=mat('Oxidized conduit zinc',(.23,.26,.25),.65,.60)
diffuser=mat('Warm frosted task diffuser',(.72,.68,.54),0,.45)
bsdf=diffuser.node_tree.nodes['Principled BSDF']
bsdf.inputs['Emission Color'].default_value=(1,.85,.59,1)
bsdf.inputs['Emission Strength'].default_value=.65
rod('Horizontal supply conduit',(-1.58,2.78,-.075),(1.5,2.78,-.075),.018,conduit)
rod('Switch drop conduit',(-1.48,1.36,-.075),(-1.48,2.78,-.075),.018,conduit)
for x in [-1.25,-.65,.65,1.25]:
    box('Conduit saddle',(x,2.78,-.078),(.055,.065,.047),enamel,.004)
box('Supply junction box',(-1.48,2.78,-.057),(.13,.13,.07),enamel,.012)
box('Switch enclosure',(-1.48,1.30,-.04),(.13,.18,.10),enamel,.012)
box('Switch rocker',(-1.48,1.31,.016),(.05,.075,.016),rubber,.004)
for x in [-.60,.60]:
    box('Task light wall bracket',(x,2.60,.005),(.05,.20,.055),conduit,.004)
    box('Task light support arm',(x,2.65,.13),(.045,.04,.26),conduit,.004)
box('Task light folded housing',(0,2.66,.26),(1.57,.115,.20),enamel,.018)
box('Task light diffuser',(0,2.613,.27),(1.43,.04,.16),diffuser,.014)
for x in [-.75,.75]:
    box('Luminaire end cap',(x,2.653,.26),(.055,.12,.205),rubber,.008)
for x in [-.51,.51]:
    box('Diffuser retaining clip',(x,2.616,.359),(.024,.035,.012),conduit,.002)
# Board centre supplies horizontal origin, tool heights are measured from floor.
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/workshop_tools.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'client/assets/realism/workshop_tools.glb'),export_format='GLB',export_apply=True)
