"""Deterministic branched broadleaf tree with folded geometry leaves (metres)."""
import math
import random
from pathlib import Path
import bpy
import bmesh
import numpy as np
from mathutils import Vector

root = Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
rng = random.Random(237091)
verts, faces, slots = [], [], []
def face(points, slot):
    faces.append(tuple(range(len(verts), len(verts) + len(points))))
    verts.extend(points)
    slots.append(slot)
def branch(a, b, r0, r1, slot=0):
    axis = (b-a).normalized()
    u = axis.cross(Vector((0,1,0))).normalized()
    v = axis.cross(u)
    n = 20 if r0 > .02 else 6
    for i in range(n):
        p = u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)
        q = u*math.cos((i+1)*math.tau/n)+v*math.sin((i+1)*math.tau/n)
        face([a+p*r0,a+q*r0,b+q*r1,b+p*r1],slot)
def leaf(at, angle):
    d = Vector((math.cos(angle),math.sin(angle),rng.uniform(-.9,1))).normalized()
    u = d.cross(Vector((0,0,1))).normalized()
    n = u.cross(d)
    roll = rng.uniform(-1.4,1.4)
    u = u*math.cos(roll)+n*math.sin(roll)
    n = u.cross(d)
    length = rng.uniform(.095,.155)
    width = length*rng.uniform(.29,.39)
    slot = rng.choices([2,3,4,5],[3,5,4,1])[0]
    # Rounded shoulders, cupped margins and a drooping tip break the old
    # four-triangle diamond silhouette without transparent foliage cards.
    rows = []
    for t in [0, .22, .48, .74, 1]:
        mid = at+d*length*t+n*length*(.12*math.sin(math.pi*t)-.18*t*t)
        w = width*math.sin(math.pi*t)**.85 if 0 < t < 1 else 0
        rows.append([mid-u*w-n*w*.28, mid, mid+u*w-n*w*.36])
    for a,b in zip(rows, rows[1:]):
        for j in range(2):
            points = [a[j], b[j], b[j+1], a[j+1]]
            unique = []
            for p in points:
                if not any((p-q).length < 1e-8 for q in unique):
                    unique.append(p)
            face(unique, slot)
# Gently bowed bole with irregular horizontal bark scars.
trunk = [Vector((.07*math.sin(z*.9),.025*z,z)) for z in np.linspace(0,7.1,96)]
for i,(a,b) in enumerate(zip(trunk,trunk[1:])):
    # Continuous taper and root flare replace disconnected polygonal sleeves.
    radius = .14*(1-a.z/8)+.016*math.exp(-a.z*4)
    end_radius = .14*(1-b.z/8)+.016*math.exp(-b.z*4)
    branch(a,b,radius,end_radius)
# Unequal upright scaffold branches carry a three-dimensional succession of
# lateral shoots. Phyllotaxis wraps around each branch axis; it does not put
# every second twig into the same horizontal fan.
for k in range(19):
    z=2.25+k*.225+rng.uniform(-.22,.22)
    angle=k*2.399+rng.uniform(-.5,.5)
    spread=1.9*math.sin((z-1.3)/6.7*math.pi)*rng.uniform(.72,1.18)
    a=Vector((.07*math.sin(z*.9),.025*z,z))
    outward=Vector((math.cos(angle),math.sin(angle),0))
    sideways=Vector((-math.sin(angle),math.cos(angle),0))
    lift=rng.uniform(1.05,1.85)
    b=a+outward*spread*.40+Vector((0,0,lift*.72))
    c=a+outward*spread+sideways*rng.uniform(-.3,.3)+Vector((0,0,lift))
    d=c+outward*.25+Vector((0,0,rng.uniform(-.45,.1)))
    branch(a,b,.049,.026);branch(b,c,.026,.010);branch(c,d,.010,.003,1)
    axis=(c-b).normalized()
    u=axis.cross(Vector((0,0,1))).normalized()
    v=axis.cross(u)
    for fork in range(10):
        start=b.lerp(c,.03+fork*.095)
        phase=fork*2.399+rng.uniform(-.45,.45)
        lateral=u*math.cos(phase)+v*math.sin(phase)
        reach=rng.uniform(.55,1.05)
        elbow=start+axis*.22+lateral*reach*.68+Vector((0,0,.16))
        end=elbow+lateral*reach*.32+outward*.12+Vector((0,0,rng.uniform(-.40,-.12)))
        branch(start,elbow,.009,.004,1);branch(elbow,end,.004,.001,1)
        twig_axis=(end-start).normalized()
        tu=twig_axis.cross(Vector((0,0,1))).normalized()
        tv=twig_axis.cross(tu)
        for shoot in range(10):
            t=.10+shoot*.088
            base=start.lerp(elbow,t/.65) if t<.65 else elbow.lerp(end,(t-.65)/.35)
            roll=shoot*2.399+rng.uniform(-.4,.4)
            shoot_dir=(tu*math.cos(roll)+tv*math.sin(roll)+twig_axis*.4).normalized()
            tip=base+shoot_dir*rng.uniform(.25,.48)+Vector((0,0,-.12))
            branch(base,tip,.0018,.0004,1)
            az=math.atan2(shoot_dir.y,shoot_dir.x)
            for j in range(8):
                leaf(base.lerp(tip,.10+j*.125),az+(-1 if j%2 else 1)*1.1)
mesh=bpy.data.meshes.new('Branched birch with folded leaves')
mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new('VergeBirch',mesh);bpy.context.collection.objects.link(obj)
for name,color in [('weathered_bark',(.39,.37,.30)),('bark_scars',(.09,.075,.05)),('leaf_shadow',(.055,.085,.026)),('leaf_olive',(.10,.16,.035)),('leaf_sage',(.125,.185,.048)),('leaf_new',(.17,.225,.068))]:
    mat=bpy.data.materials.new(name);mat.diffuse_color=(*color,1);mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=(*color,1);bsdf.inputs['Roughness'].default_value=.88
    mat.use_backface_culling=False;mesh.materials.append(mat)
for p,s in zip(mesh.polygons,slots):p.material_index=s;p.use_smooth=s==0
# Faces previously owned separate vertices: smooth shading had no effect.
bm=bmesh.new();bm.from_mesh(mesh)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.00001)
bm.to_mesh(mesh);bm.free();mesh.update()
uv=mesh.uv_layers.new(name='Bark cylindrical metres')
for poly in mesh.polygons:
    if poly.material_index != 0: continue
    coords=[]
    for li in poly.loop_indices:
        co=mesh.vertices[mesh.loops[li].vertex_index].co
        coords.append((math.atan2(co.y-.025*co.z,co.x-.07*math.sin(co.z*.9))/math.tau,co.z/3.0))
    seam=max(u for u,v in coords)-min(u for u,v in coords)>.5
    for li,(u,v) in zip(poly.loop_indices,coords):
        uv.data[li].uv=(u+1 if seam and u<0 else u,v)
# Embedded albedo: subdued papery bark, irregular lenticels and peeling
# patches. No external image dependency or runtime material override.
tex_rng=np.random.default_rng(346091)
w,h=512,1024
yy,xx=np.mgrid[0:h,0:w]
field=np.zeros((h,w),dtype=np.float32)
for scale,weight in [(16,.035),(48,.025),(150,.016)]:
    field+=weight*np.sin(xx/scale+np.sin(yy/(scale*1.7)))*np.cos(yy/(scale*.8))
field+=tex_rng.normal(0,.012,(h,w))
rgb=np.stack([.48+field,.455+field,.395+field],axis=-1)
for _ in range(460):
    x=int(tex_rng.integers(w));y=int(tex_rng.integers(h))
    length=int(tex_rng.integers(3,48));thick=int(tex_rng.integers(1,4))
    for dy in range(thick):
        indices=(x+np.arange(length))%w
        rgb[(y+dy)%h,indices]*=tex_rng.uniform(.28,.65)
pixels=np.ones((h,w,4),dtype=np.float32);pixels[:,:,:3]=np.clip(rgb,0,1)
image=bpy.data.images.new('Birch papery bark 346',width=w,height=h)
image.pixels.foreach_set(pixels.ravel());image.pack()
mat=mesh.materials[0];nodes=mat.node_tree.nodes
texture=nodes.new('ShaderNodeTexImage');texture.image=image
mat.node_tree.links.new(texture.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/verge_birch.blend'))
bpy.ops.export_scene.gltf(filepath=str(root/'client/assets/realism/verge_birch.glb'),export_format='GLB')
print('BIRCH',len(verts),'vertices',len(faces),'faces')
