# Stage31 independent screenshot review

Reviewed the actual image `artifacts/realism31-preview/capture/grass-close.png`.
This is visual evidence only; no new gameplay or performance pass is implied.

The grass now forms distinguishable colonies, with exposed ground and some
green/dry color variation. This is a useful improvement over uniform isolated
tufts. The screenshot still falls substantially short of the requested realism.

Next round should address the first-person weapon and arms, which dominate the
view even after improving the ground:

- The rear receiver is an oversized smooth rectangular mass with little
  readable separation between coated metal, polymer and rubber. Refine its
  silhouette, panel boundaries and small bevels before adding random scratches.
- The optic looks like a thick empty rectangular frame. Inspect its profile
  and lens treatment in hip-fire and ADS; maintain sight alignment and clear
  visibility of the target.
- The sleeve reads as an almost flat dark camouflage tube. Add restrained
  elbow/wrist folds, cuff construction and fabric roughness; preserve hand
  placement on the weapon. Inspect both glove contacts and the trigger hand.
- Compare identical hip-fire and ADS cameras before and after; re-run the
  existing aim/alignment test if weapon meshes or sockets change. Review
  reload poses for intersections as well as checking numerical transforms.

Environment issues to retain in subsequent work:

- Grass still shares a recognizable radial fan silhouette. Additional mesh
  silhouettes and blade bend variation will help more than more color noise.
- The asphalt boundary is a perfectly clean polygon. Add a narrow irregular
  gravel/dirt transition while keeping the playable collision surface intact.
- Background trees look like thin cutouts with repetitive profiles, particularly
  along the ridge against the sky. Rounded mountains remain overly smooth.
- Buildings retain large flat walls and repeating vents/windows. Material
  weathering alone will not solve their repetitive architecture.

Do not interpret the improved grass screenshot as overall visual acceptance.
Characters, weapon/arms, architecture and background vegetation need further
substantial work and corresponding actual gameplay views.

## Packaged player-height view

Also independently opened `artifacts/realism31-preview/capture/gameplay.png`.
The standard forward camera confirms the grass distribution change is visible
during play, rather than only in the downward inspection camera. It also
confirms the weapon priority: the rear receiver face and stock tube dominate
the lower-right view as simple solid primitives; the sleeve has almost no
readable construction or folds. Preserve the muzzle-to-sight relationship
while refining these visible forms. Use `tests/aim_alignment.gd` for the
existing alignment regression and `tests/optic_visual_capture.gd` as a starting
point for the ADS screenshot, not a nonexistent aim_alignment_check.gd.

In this forward frame the nearest warehouse roof is an especially straight,
thick dark strip and the three identical vents make repetition conspicuous.
For the later architecture pass, compare roof-edge thickness, vent framing,
door recesses and believable construction joints at this same camera before
adding more wall stains. The hill/tree horizon still reads as pale smooth
mounds with repeated flat tree silhouettes. These are remaining defects,
not evidence of completion.

## Stage32 baseline hip-fire and ADS review

Independently opened the worker's new actual Forward+ frames
`artifacts/realism32-before/weapon-0-hip.png` and
`artifacts/realism32-before/weapon-0-ads.png`. The reusable capture script is
`tests/weapon_review_capture.gd`; it requests three weapons and five poses per
weapon (hip, ADS, and quarter/half/three-quarter reload). At this review time
only the first two frames were inspected, so neither completion of all fifteen
frames nor reload quality is established.

The ADS view specifically exposes the optic's rounded rectangular lower housing
as a large smooth blob, with two equally simple cylinders at the sides. The
rear receiver forms another broad featureless trapezoid below it. Prioritize
recognizable optic mounting/clamps, thinner credible housing construction and
receiver surface breaks. Keep the red-dot center and the viewing aperture clear;
surface detail must not obscure the aim point. The hip view additionally
exposes parallel glove fingers with little knuckle construction and a straight
camouflage sleeve without a readable cuff or elbow folds.

These images establish the baseline for the worker's active weapon pass.
Compare the same camera and pose after changes; the visible red dot alone is
not evidence that projectile alignment passes.

## Stage32 baseline reload review

Also opened weapon-0 reload-quarter and reload-three-quarter from the same
baseline directory. Both expose a flat circular buffer-tube end, nearly
straight camouflage sleeves, and an abrupt gray wrist section. Those silhouettes
remain conspicuously procedural even with the camouflage texture.

The two poses look almost identical despite different reload countdowns.
This is partly expected from `first_person.gd`: root tilt uses
`sin(progress * PI)` and magazine displacement uses its square, so 25% and
75% have the same root tilt and magazine position. The arms animation is sought
separately. Thus this comparison does not establish a stuck animation, but it
does show why symmetric motion alone cannot communicate magazine removal,
replacement and return to grip convincingly. Inspect hand contact at the
midpoint and the transitions before claiming natural reload motion; implement
distinct extraction, insertion and return phases if those contacts fail.

The capture sets reload time directly with simulation paused; its HUD ammo
values and image-save success do not verify ammunition transfer or live
animation timing. Keep the functional reload regression separate.

## Stage32 cross-weapon baseline findings

All fifteen baseline PNGs are now present. Independently opened
`weapon-1-ads.png`, `weapon-2-ads.png` and `weapon-1-reload-half.png`
in addition to the frames above.

- The shotgun ADS silhouette has a broad, almost featureless rectangular
  receiver immediately below the iron sight. Its rear cap needs believable
  construction and proportions; adding camouflage or surface noise will not
  resolve that silhouette.
- The marksman ADS scope has a thick smooth eyepiece surrounding a much
  smaller clear aperture. Inspect the eyepiece, inner tube and mounting
  proportions together; retain an unobstructed center. The baseline shows
  a center dot but does not establish magnification or ballistic alignment.
- At shotgun reload midpoint, the support hand hangs below and away from
  the weapon, with no visible shell or magazine held. A single synthetic
  frame cannot prove the entire reload is wrong, but this key pose does not
  communicate ammunition insertion. Review a live reload sequence before
  accepting this animation, including the hand's approach, contact and return.
- The same midpoint view exposes a large smooth wrist section and straight
  sleeve ends. Cuff geometry and hand-to-sleeve transitions need scrutiny
  alongside the active material changes.

The current worker has reported passing aim alignment, weapon visual rules,
viewmodel rules and obstruction rules. Those results cover functional and
structural regressions; none settles these visible geometry and hand-contact
issues. Compare matching post-change frames before judging improvement.

## Stage32 first post-change comparison

Opened `artifacts/realism32-after/weapon-0-ads.png` and
`artifacts/realism32-after/weapon-1-reload-half.png` while the worker was
still producing the remaining frames.

The carbine now shows a slimmer angular optic frame, readable rail slots and
crosswise hardware above the receiver. The aperture remains visibly clear.
These are useful silhouette improvements over the earlier rounded optic base;
they do not resolve the broader scene's repeated buildings and sparse trees.
The lower optic mounting block still reads as a smooth rectangular block, and
the close receiver remains largely featureless.

The shotgun midpoint now shows sleeve folds and a distinct pale cuff, making
the cloth silhouette less cylindrical. However, the support hand remains
separated from the ammunition insertion area, and the blocky rear receiver
is still prominent. The pale cuff has a strong flat light band in this view;
review its material and thickness before accepting the transition as realistic.
This pair therefore supports a partial geometry/material improvement, not
acceptance of weapon animation or overall visual quality.

Next acceptance evidence should include all three matching ADS views plus a
live reload sequence with visible ammunition handling. Do not let a successful
carbine-only preview stand in for the shotgun and marksman comparisons.

## Stage32 remaining ADS review

Independently opened `artifacts/realism32-after/weapon-1-ads.png`,
`artifacts/realism32-after/weapon-2-ads.png` and the matching marksman
before image. Both after images are actual 1152x720 gameplay captures.

- Shotgun: the orange front sight remains visible through its rear ring.
  However, a large smooth rectangular receiver fills the lower central view.
  Its bevel alone does not provide believable mechanical construction.
  Prioritize receiver proportions, rear surface transitions and material
  separation at this exact ADS camera; small hidden side details will not
  resolve the dominant silhouette.
- Marksman: before and after retain the same visually dominant thick circular
  eyepiece, wide dark inner wall, small clear aperture and rounded mounting
  block. This comparison does not establish a meaningful improvement to this
  weapon. Rework eye relief and eyepiece geometry together, retain an
  unobstructed aiming point, and verify the resulting sight at both hip and
  ADS positions. Do not enlarge the aperture without checking the optic axis,
  camera transition and clipping.
- Environment in both frames remains visibly repetitive: matching warehouse
  vents/doors, hard straight pavement boundaries and thin repeated tree
  silhouettes. Weapon-only progress cannot close the environment requirement.

The exported stage32 capture directory currently contains carbine hip/ADS
images. That is useful packaged-render evidence for the carbine only; it does
not verify the other two weapon models or a live reload sequence. Continue
with these visible unresolved shapes rather than treating all-three weapon
functional passes as all-three weapon visual acceptance.

## Exported stage32 hip screenshot: environment priorities

Independently opened `artifacts/realism32-preview/capture/weapon-0-hip.png`
at its native 1152x720 size. This confirms that the exported package renders
the updated sleeve and angular carbine optic in the actual scene. The visible
buffer tube still ends in a prominent smooth cylinder. The nearby support
fingers form a nearly identical row rather than a convincing wrapped grip.

The wider hip view also identifies concrete environmental work beyond guns:

- The central warehouse has three identical vents at identical heights, an
  almost uninterrupted flat roof edge, and a wall material without strong
  ground-contact weathering. Add plausible construction variation and
  grounded dirt/detail at this visible facade, keeping entrances clear.
- Parking asphalt ends in a straight, sharp boundary against grass and soil.
  Add an irregular worn shoulder and sparse edge vegetation without obscuring
  movement or changing collision just to achieve the visual effect.
- Middle-distance grass is made of clearly separated similar radial tufts;
  distant hills carry repeated thin tree silhouettes on smooth slopes.
  Evaluate vegetation changes at these distances, not just close-up crops.
- Left foreground crate and main building cast readable shadows, but the
  repeated walls and distant vegetation still read as a sparse constructed
  test scene. Increasing mesh detail on the weapon alone cannot satisfy the
  overall environment requirement.

`realism32-preview-smoke.log` explicitly reports OFFLINE_SMOKE_PASS for
16 actors, reload, heal, damage, victory, raycast, cover, fire interval and
rig. This is useful runtime evidence, not visual acceptance or proof of
multiplayer. The next environment comparison should retain this wide camera
so facade, asphalt shoulder and tree distribution can be evaluated together.

## Current operator review (independent capture, stage33)

Captured the current `operator.glb` with `tests/operator_pose_capture.gd`;
log: `artifacts/realism33-independent-operator.log`. The run reports
`OPERATOR_POSES_PASS clips=15 skin_samples=75`. This verifies sampled skin
bounds, not anatomical quality, weapon contact or animation timing.
Renderer was OpenGL Compatibility on llvmpipe, not the Forward+ game renderer.

Directly inspected `artifacts/realism33-independent-operator/poses-0.png`
and `turnaround-90.png`. Front and side silhouettes remain visibly stylized:

- The helmet is a smooth dome and the face is almost uniformly black.
  Establish visible helmet rim/retention structure and readable fabric
  folds around the covered jaw; verify under gameplay lighting before
  diagnosing this entirely as an albedo problem.
- Chest armor reads as a large flat polygon with thin drawn lines. Model
  layered plate-carrier fabric, stitched borders and attached pouches with
  distinct depth. Avoid simply adding more lines to the flat front.
- The side view exposes the backpack as a plain rounded block with little
  load-dependent shape. Add fabric compression, pocket volume and credible
  strap attachments, then check shoulder movement and crouch clearance.
- The boots have a smooth wedge silhouette, and the kneepads are flat
  rectangles. Improve boot ankle/toe/sole construction and padded knee
  contours while preserving animation deformation.
- Camouflage and shoulder folds provide some variation, but are not
  sufficient to make the equipment or anatomy realistic.

These studio captures omit held weapons, so the empty hand poses do not
establish a grip bug. After model changes, inspect an actual equipped actor
in the game at close and middle distances and compare frontal/side crouch
and reload poses. Retain this operator work in the acceptance scope after
the current first-person weapon pass; the full visual goal remains unmet.

Additional direct inspection of `poses-1.png` and `poses-3.png`:
The downed/crawl view reveals thick, rigid-looking shoulder straps standing
away from the chest and exposes the plate carrier's slab construction.
Prioritize strap fit in bent poses, not just its standing silhouette. The
pouches do have modeled depth visible here; the issue is their identical
box-shaped construction and weak fabric/closure detail, not missing geometry
altogether. Midpoint walk/run/jump still share a very upright torso, but a
single sampled frame cannot establish whether the full animation lacks
weight shift. Review a complete cycle before changing motion curves.
The capture has no ground plane, so it cannot validate foot planting or
downed-body ground contact; those checks need gameplay or a grounded setup.

## Stage 33 equipped operator in gameplay lighting

The independent harness `tests/operator_gameplay_capture.gd` renders the
actual equipped actor in the solo map. Original capture completed 12 images
in `artifacts/realism33-operator-gameplay` (see its sibling `.log`). Directly
reviewed `idle-90.png`, `crouch-90.png`, `reload-0.png`, and `downed-90.png`.
Gameplay lighting confirms the dome-like helmet, nearly featureless dark
face covering, flat carrier plate, smooth wedge boots, and pill-shaped
backpack; these are not only studio-lighting artifacts. Downed side view
also confirms rigid shoulder straps projecting away from the torso.
The reload front view shows readable goggles but insufficient fabric and
layering around the face and armor.

The original crouch side capture shows the rifle near shoulder height while
both arms drop toward the lap. Treat this as a suspected attachment/pose
issue pending the synchronized repeat: the original harness advanced 12
animation steps without allowing deferred skeleton updates between them.
The harness now awaits a process frame after each pose update. Repeat
output is `artifacts/realism33-operator-gameplay-settled`; do not infer a
runtime defect until that result is reviewed. Relevant code paths are
`character_animation.gd`'s spine override and `actor.gd`'s Weapon-bone
attachment update.

This setup fixes actor position at (17, 0.05, 50) and pauses game physics;
it is not a foot-grounding or live collision test. Apparent ground gaps
must therefore not be reported as proven gameplay grounding defects.
These captures use Compatibility/llvmpipe, not a hardware performance test.
Background buildings still expose repeated three-vent facades, vegetation
has conspicuous dark radial tufts, and the terrain silhouette remains
smooth and repetitive. Keep environmental variety and material fidelity
in the outstanding scope along with the equipped-character corrections.

Synchronized repeat result: directly inspected
`artifacts/realism33-operator-gameplay-settled/crouch-90.png` after allowing
every animation step to reach the next process frame. The same difficult-to-read
arm silhouette persists, so tight-loop sampling is not its sole cause.
**Correction after bone-colored mesh inspection below:** the earlier statement
that the hands descend beside the knees was a visual misidentification of the
elbow/forearm silhouette. This image alone does not prove gun/hand separation.
The paused harness still does not establish live transition timing or physics.

### Independent attachment transform probe (stage33)

A headless real Actor probe advanced character_animation.update and update_weapon_attachment for 12 separate process frames in idle, then crouch. Evidence: `artifacts/realism33-operator-diagnostic/attachment_probe.gd` and `.log`.

- Idle gun origin `(0.1, 1.353526, -0.235)`; crouch `(0.1, 0.702292, -0.114981)`: the attachment DOES descend approximately 0.65m.
- Crouch Hand.R global pose `(0.1, 0.552292, 0.000019)` and Hand.L `(0.035, 0.652292, -0.339981)`, Weapon `(0.1, 0.702292, -0.114981)`.
- This weakens the hypothesis that the gun simply keeps the standing attachment transform. The synchronized screenshot has ambiguous overlapping limbs: inspect actual skinned hand/forearm vertices, bind transforms and gun mesh origin before changing attachment offsets or pitch override. A passing bone-origin probe is not proof of correctly rendered hands.
- Probe is headless and bypasses full render_frame/world; it does not replace the graphical evidence or prove the cause.

### Rendered mesh diagnosis corrects the crouch interpretation

Directly inspected `artifacts/realism33-operator-diagnostic/colored-true.png`
and `arm-colors-true.png`; the corresponding probes and logs are alongside
these images. Both run the real Actor with 12 separately awaited render_frame
updates. A baked-skin replacement also reproduces the original silhouette
(`baked-true.png`), which weakens a GPU skinning-specific explanation.

Color legend: right hand red, left hand green, right forearm yellow, left
forearm cyan, right upper arm magenta, left upper arm blue. The right hand is
at the pistol grip and the left hand is beneath the fore-end. The low U-shaped
silhouette is the right elbow/forearm, not hands detached from the weapon.
Crouch baked hand centroids are R `(0.098488, 0.562443, -0.055737)` and
L `(0.035784, 0.662466, -0.395807)`; weapon origin is
`(0.1, 0.702292, -0.114981)`. These are mesh vertices, not only bone markers.

Do not change the Weapon attachment offset to fix the superseded diagnosis.
The remaining concern is anatomical/readability quality: the right elbow
projects low and outward, the forearm has a tight curled silhouette, and bulky
sleeve geometry obscures the arm line. Review another camera angle and live
motion before adjusting elbow bend or garment shape. This diagnostic does
not establish finger contact, reload correctness, or overall operator quality.
The armor, helmet, face, footwear, backpack and environment observations above
remain outstanding; passing this probe does not satisfy the visual goal.

### Stage34 source Forward+ frame: prioritize environmental composition next

Independently viewed `artifacts/realism34-forward/weapon-0-hip.png` (1280x800).
`artifacts/realism34-validation/capture-source.log` identifies Forward+ with
Vulkan llvmpipe and two captured frames. This is source-render evidence, not
proof of exported-package parity or hardware performance.

The exposed receiver edges, camouflage sleeve and cuff now read more clearly
than the surrounding environment. The environment still dominates the overall
quality deficit in this frame:

- The central warehouse and rear-right warehouse repeat the same shallow roof,
  brown facade and three horizontal vents. Give a selected second building a
  distinct roofline, opening arrangement and credible service entrance rather
  than merely changing wall color.
- The road meets bare dirt with a clean geometric boundary and almost no
  drainage, shoulder gravel or accumulated debris. Add a restrained transition
  at this same camera location; preserve traversability and cover collision.
- Many grass tufts have the same upright, radial silhouette and similar size,
  including dense right foreground rows. Introduce a few genuinely different
  grass forms and ground-cover patches with purposeful gaps; simply increasing
  count will not address repetition.
- Distant tree silhouettes are thin and visibly repetitive against smooth
  rounded hills. Improve cluster composition and canopy volumes, then compare
  both this wide shot and a closer tree view before claiming improvement.

After the currently running weapon stage, prioritize one coherent environment
pass across these visible surfaces, with the same camera before/after and a
second traversal angle. Keep operator quality and reload contact outstanding.

Separately, the reviewed stage33 SR ADS open-ring appearance is supported by
`tools/build_weapon_variants.py`'s explicitly open-bore scope geometry. Do not
report missing gameplay zoom: `actor.gd` uses FOV 24 for this weapon. The
remaining issue is optical appearance and reticle presentation; a static
screenshot cannot establish magnification behavior or independent lens optics.

### Stage34 exported preview: grip and reload evidence

Independently viewed the exported preview's
`artifacts/realism34-preview/capture/weapon-0-hip.png` and
`weapon-0-reload-half.png`. Its capture log identifies Forward+ / llvmpipe.
At inspection the capture job had not printed its completion marker; these
two existing frames are evidence, not a claim that the full capture set passed.

The hip frame shows the left hand beneath the fore-end, but the pale cuff is
a conspicuous smooth band and the sleeve has a nearly uniform tube silhouette.
The receiver is legible, while the rear stock still reads as a plain cylinder.
At half reload the left hand is visibly below and separate from the magazine;
no magazine is visibly held in that hand. This single frame does not establish
whether an earlier removal or later insertion frame contacts correctly.
`client/scripts/first_person.gd` translates the magazine on its own local Y
axis with a sine curve (line 115 at inspection). Review hand and magazine
trajectories together in motion before treating the reload as physically
credible; gameplay reload success does not check that contact.

`artifacts/realism34-validation/preview-smoke.log` reports solo smoke success
with 16 actors, reload, heal, damage, victory, raycast, cover, fire interval
and rig. `aim_alignment.log` reports 108 samples across three weapons passing.
These are useful functional checks, not visual acceptance or GPU performance
evidence. The environment priorities in the preceding section remain visible
in the exported hip frame and should be the next coherent improvement pass.

### Stage34 follow-up: stock visibility is a runtime issue to inspect first

Independently inspected `weapon-0-reload-three-quarter.png` and
`weapon-1-reload-half.png` from the exported stage34 capture directory.
The rifle's exposed rear cylinder remains conspicuous at 75% reload.
Before rebuilding that part, inspect `first_person.gd:56`: `bind_weapon`
unconditionally hides every `*Butt*` node. `build_assets.py:171-176` already
builds a buffer tube, profiled butt stock and butt plate; the tube stays
visible when the stock and plate are hidden. SG/SR also create named butt
stock and plate meshes in `build_weapon_variants.py:91-92`.
Thus missing stock silhouette has a concrete runtime visibility contributor,
not just insufficient Blender geometry. Compare visibility in hip, ADS and
reload before choosing a fix; simply unhiding can create camera obstruction.

The shotgun half-reload frame shows the support hand low below the receiver,
with no clear grasp-and-seat relationship visible. Together with the rifle
quarter/half/three-quarter samples, this warrants weapon-specific contact
checks through removal and insertion, rather than accepting the shared
symmetric gesture on gameplay test results alone. These sampled frames do
not establish continuous animation behavior.

Correction to the new stage34 review's final paragraph: the earlier crouch
attachment suspicion was superseded by the bone-colored baked-mesh evidence
above. Low visible anatomy was forearm/elbow, not a hand at the knee. Do not
treat a skinning/binding defect as established or change weapon attachment
offsets on that basis. Preserve the outstanding pose-readability concerns.
After bounded weapon corrections, prioritize the environmental composition
pass described above instead of another small hand-geometry-only iteration.

### Stage34 exported environment: four-camera independent baseline

Captured the existing Linux executable/PCK from `/tmp`, without `--path`,
using `tests/world_visual_capture.gd` and an isolated XDG directory. Evidence:
`artifacts/realism34-environment-independent/{street,building,forest,overview}.png`.
`capture.log` exits successfully with `WORLD_VISUAL_CAPTURE_PASS colliders=276`.
This counts collected shapes; it does not test traversal or collisions.
Rendering is Forward+ on llvmpipe, not hardware performance evidence.

The closer cameras now localize the environmental changes needed:

- `building.png`: the front entrance reveals an almost empty dark room and
  two opaque pale window rectangles; adding exterior trim alone will not
  provide believable depth. Introduce recessed window/frame construction
  and a few purposeful interior structural/storage forms with a clear
  walking route. Keep entrance collision clearance verified afterward.
  The yellow parking lines run toward the doorway; distinguish loading
  space from parking so the building reads as an actual workplace.
- `street.png`: gutter/downpipe, wall panels and roof overhang are readable
  improvements, but the next warehouse repeats the same roof and vent
  arrangement. Alter roof profile and bay/opening arrangement on a subset.
  Apron-to-earth transitions form clean straight cutouts without curb,
  shoulder or drainage; add a physically plausible edge at this camera.
- `forest.png`: the foreground tree has sparse fine foliage, while the
  distant trees have chunky repeated crowns. Their shapes and density
  do not form a convincing continuous forest. The bare flat foreground,
  abruptly rising smooth hills and isolated exposed rock also need
  composition work. Group understory, trunks and ground litter around
  selected trees rather than scattering more identical grass everywhere.
- `overview.png`: the entire play space reads as a flat square with sixteen
  similarly sized isolated sheds arranged around a crossroad. Ground
  texture repetition is visible across broad areas. A local cluster with
  an asymmetric service yard, varied building footprint/height, connecting
  surfaces and irregular vegetation borders would change this composition
  more than another uniform material tint or density increase.

For the next environment pass, retain these four cameras as comparison
evidence and add actual player traversal through the changed entrance and
yard. Start with one coherent warehouse/yard cluster so a before/after can
show improved structure, ground transitions and foliage together. Do not
claim overall realism acceptance from that one cluster; the other repeated
buildings, character and weapon issues remain in scope.

### Stage34 marksman optic: hip/ADS consistency

Independently inspected exported `capture/weapon-2-hip.png` and
`capture/weapon-2-ads.png` in `artifacts/realism34-preview`. Hip shows a long,
opaque-looking black scope; ADS becomes a thin open hoop with a tiny red HUD
dot and uninterrupted scenery through and around it. The warehouse clearly
enlarges, so this is **not evidence of broken zoom**. The missing visual cues
are ocular depth, subdued lens response and a marksman-specific reticle.

Source inspection localizes the tradeoff: `scope_body()` in
`tools/build_weapon_variants.py` deliberately flares the open bore along the
viewing cone with a 2.5 mm wall. `first_person.gd` deliberately hides the
animated weapon dot because the HUD owns ballistic aiming. Future optic
polish should preserve that ballistic alignment and unobstructed target view;
do not restore a gun-attached aiming dot or cover the aperture with opaque
glass. Compare hip, ADS and the transition when introducing ocular shading
or a sight-specific reticle. This is a bounded outstanding weapon issue,
not a reason to defer the higher-impact environment composition pass.

### Stage35 restored rifle stock: visible, but still visually intrusive

Independent inspection of `artifacts/realism35-preview/capture/weapon-0-ads.png`
and `weapon-0-reload-half.png` confirms the restored stock renders. ADS leaves
the red aiming dot and aperture unobstructed in this sampled frame. However,
the stock fills the bottom center with a broad, almost featureless gray
trapezoid. At reload half, its rear/side face reads as a large rectangular slab
beside the right hand. Visibility alone is not visual acceptance: the
camera-facing silhouette and surface treatment still look primitive.

The rifle generator already uses a profiled, recessed `Butt stock` and separate
`Butt plate` in `tools/build_assets.py`; therefore do not diagnose this as a
missing stock mesh, or solve it by hiding all Butt nodes again. Check the
near-camera perspective and rear-face material/edge treatment in these exact
poses before adding more small side details that are invisible here. A modest
pose or geometry refinement must preserve sight alignment and reload hand
contact. Static screenshots do not establish transition clipping or animation
quality.

Read current stage35 logs: aim alignment passes 108 samples over three weapons;
obstruction and weapon visual rules pass; rifle capture reports five frames.
These establish their stated functional coverage, not realistic stock shape.
At review time the remaining capture process was live; offline smoke was not
yet available. The environment composition work described above remains a
higher-impact outstanding part of the overall objective.

### Stage35 cross-weapon follow-up and offline result

The newly available `artifacts/realism35-validation/offline-smoke.log` reports
`OFFLINE_SMOKE_PASS actors=16 reload=ok heal=ok damage=ok victory=ok raycast=ok cover=ok fire_interval=ok rig=ok`.
The weapon-2 capture log reports five frames, and all fifteen weapon PNGs are
present. This closes the earlier missing smoke evidence; it does not close
the visual acceptance gaps.

Independently viewed `weapon-2-reload-half.png`: the marksman shoulder pad
occupies approximately x840–990, y450–675 in the 1280x800 image as a nearly
uniform gray quadrilateral. Its dark rim and cheek rest are visible, but
the dominant camera-facing surface still reads as a block. This corroborates
the rifle finding across weapon types rather than an isolated rifle material.
Viewed `weapon-1-ads.png`: the aiming point remains visible above the receiver,
but the brown stock spreads from roughly x585–700 at y570 to x470–810 at the
bottom edge, with almost no visible surface variation. Preserve alignment;
inspect the shared first-person camera/stock relationship before spending
another iteration on tiny accessories.

For the next environment pass, these captures also preserve a clear baseline:
nearby warehouses repeat the same vent/opening pattern and rectangular apron,
with thin scattered grass and smooth background hills. A coherent warehouse
yard and richer building silhouette remain a larger outstanding visual task
than stock accessory naming. Do not treat passing weapon/offline checks as
evidence that buildings, terrain, vegetation, lighting or character realism
have reached the requested quality.

### Stage35 actual warehouse traversal fails from both entrances

Independent diagnostic `tests/warehouse_traversal_review.gd` loads the world
and real actor from the packaged stage35 Linux client. It settles the actor
under gravity, then walks at normal speed through warehouse (35,34), with no
jump, from each entrance for up to 360 physics frames.
`artifacts/realism35-traversal-independent/run.log` reports exit 1:
from (35,0,44) toward negative Z it stops at (35,-0.000793,40.83319);
from (35,0,24) toward positive Z it stops at (35,0.000103,27.16574).
Neither route passes. Raw results are in the adjacent `traversal.json`.

These positions are consistent with the capsule stopping at the raised
floor edge: the floor spans Z 27.5–40.5 and its top is 0.2m above ground.
Inspect this cause before changing doorway walls. Existing horizontal
clearance rays and collider counts do not cover this walking transition.
Provide a usable threshold/ramp or suitable collision transition and rerun
the real-actor test in both directions; preserve cover and roof collision.
This is a functional issue to address alongside the environment visual pass.

Control experiment confirms the raised floor collider is responsible.
With `TRAVERSAL_DISABLE_FLOOR=1`, the diagnostic disables exactly one
16×0.2×13 collider centered at (35,0.1,34) in runtime memory only. The same
packaged actor then crosses both entrances and the entire building:
Z44→24.93323 and Z24→43.06677, both at ground height. See
`artifacts/realism35-traversal-floor-control/{run.log,traversal.json}`.
This is diagnostic evidence, not a shipped fix: do not remove the floor
collision as the final solution while leaving a visibly raised floor.
The normal test remains the acceptance case; the control flag must be absent.

### Stage36 source apron traversal independently passes

The current source with doorway aprons passes the same real-actor traversal
without the floor-control flag: Z44→24.97425 and Z24→43.02611.
Evidence: `artifacts/realism36-apron-independent/source-traversal.log` and
`traversal.json`. A copied Godot engine without an adjacent PCK loaded
`client` directly with an isolated data directory. This validates current
source, not the pending stage36 packaged preview.

The apron shape's debug mesh contains both line and triangle surfaces
(`check_surface.gd` and `run.log` in the same artifact directory); it is
not exclusively a wireframe. Visual integration still needs screenshot
review. `harness-path-error.log` records an earlier diagnostic executable
versus data-directory naming conflict, not a game failure.

### Stage102 independent review: broaden the next implementation phase

Independently opened the actual packaged `weapon-0-hip.png` in
`artifacts/realism102-validation/packaged-forward/`. The central warehouse,
background warehouses, near grass and distant hills remain clearly visible.
The first-person priority above was an initial review priority, not a permanent
instruction to spend every subsequent phase on small grip corrections.
Stage102's own review acknowledges the remaining environmental deficiencies.

Next implement a substantial environment phase alongside any necessary hand
regression fix. In this screenshot the dominant central building still reads
as a plain rectangular shell. Give this warehouse a coherent loading/service
area: structural roof variation, entrance recess, believable loading equipment
and grouped cover, connected by visibly used ground. Differentiate adjacent
buildings by purpose and silhouette rather than color alone. Preserve existing
entrance walking routes and combat sight lines.

The foreground repeats similar bright green tufts over a mostly uniform brown
surface. Replace the uniform placement impression with patches tied to terrain
and use: sparse worn paths, denser unmanaged borders, low understory and small
debris. Distant slopes look smooth and gray-green with repeated narrow tree
silhouettes; improve terrain/material transitions and tree grouping. Do not
try to hide these issues with stronger fog, blur or different framing.

Keep the existing weapon screenshot for same-view comparison, but require
street, building and forest views from the packaged client as additional
evidence. Verify real actor entrance traversal after changing thresholds,
yard objects or cover; collider counts alone are insufficient. A passing
weapon check cannot establish environment, character or overall fidelity.
Do not label the current overall visual target complete.
