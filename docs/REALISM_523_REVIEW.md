# Stage 523: operator head and first-frame diagnosis

This stage is incomplete. No overall realism acceptance or client publication.

## Assets

`tools/build_operator.py` now bakes subdivision into the masked face, replaces
the disconnected goggle strap with a continuous curved band, and follows the
helmet shell with curved accessory rails. Blender generation and Godot import
completed. Actual imported-model renders are in
`artifacts/realism523-validation/head-band/{front,side,rear}.png`.

The face still reads as a featureless mannequin and the helmet and goggles
need further material and silhouette work. These images do not establish
full-scene quality or the requested realism level.

## Full-scene capture

The 320×200 Compatibility capture process has terminated without an image.
`spawn-320.log` records scene readiness at 36.482 seconds, solo readiness at
37.089 seconds and drawing beginning at 38.556 seconds, with no drawing end.
Reducing output resolution alone did not make that attempt complete.

The capture harness now supports `CAPTURE_DISABLE_SHADOWS=1` for diagnosis
only. It disables shadow flags on lights after building the full world;
production lighting and geometry are untouched. Diagnostic output records the
flag and affected light count and prints a different pass marker.

The first shadow-disabled run uses the same 320×200 viewport and full scene,
with a 180-second process limit. Its log is
`artifacts/realism523-validation/spawn-no-shadows.log`. It reports 61 affected
lights, scene readiness at 37.323 seconds and drawing beginning at 39.407
seconds. That process subsequently reached its 180-second limit without
finishing the draw. Disabling shadows alone did not resolve the stall.

Further material-isolation captures (all at 320×200 with shadows disabled):

- `spawn-flat.log`: replacing all 6,889 geometry materials completed drawing
  in 4.931 seconds.
- `spawn-without-service-ground.log`: replacing only the three geometries
  using `service_ground.gdshader` completed drawing in 8.424 seconds.
- `spawn-noise-lattice.log`: the production noise-lattice version still failed
  to complete within 180 seconds.

The service-ground path therefore warrants investigation in the full scene.
It is not enough to measure this shader on a standalone plane:
`service-isolated/baseline.log` completed in 628 ms, while
`service-isolated/branchless.log` completed in 898 ms. Those single draws do
not demonstrate a speed improvement from replacing the nearest-cell branch.
The candidate remains an artifact, not a production fix.

`tests/default_spawn_review_capture.gd` now accepts
`CAPTURE_SERVICE_SHADER_PATH` for a temporary in-memory shader replacement.
Such captures are explicitly diagnostic and record the candidate path.
Do not accept material-isolation images as final visual results.

Additional isolation on September 23:

- The branchless candidate also timed out in the full world.
- Isolated original material with eight spot lights drew in 744 ms; the
  four-sample MSAA variant drew in 184 ms (potentially warm shader caches).
  Neither measurement represents full-world performance.
- `spawn-no-msaa.log` completed with MSAA and 61 light shadows disabled,
  taking 30.001 seconds for the explicit draw at 320×200. Its image is a
  diagnostic, not a playable-performance or visual acceptance result.
- A candidate in `artifacts/realism523-validation/opaque-ground.gdshader`
  replaces alpha hashing with world-anchored coverage discard. The experiment
  retains the mineral shading and feathers transitions with fine grains.
  It requires full-world timing and visual review before production adoption.

## September 24: directional shadow diagnosis

The full-world 640×400 capture retains four-sample MSAA and all shadow
lights. Increasing the sun's depth bias from 0.5 to 2 did not remove the
dense diagonal road stripes (`spawn-sun-bias2/default-spawn.png`).
Changing normal bias from 0.3 to 2 with depth bias still at 0.5 visibly
reduced those stripes (`spawn-normal-bias2/default-spawn.png`); shoulder
texture and vegetation artifacts remain. Artifacts are under
`artifacts/realism523-validation/`.

The latter explicit software-rendered draw took 99.655 seconds. This is
visual diagnostic evidence, not acceptable runtime-performance evidence.
The production sun now uses normal bias 2, pending close-range contact
shadow review. Shadows remain enabled. The capture harness records both
bias overrides and labels any override as diagnostic.

Current gameplay checks:

- `aim-alignment-current.log`: 108 samples across three weapons, including
  recoil, lean, transitions and camera/raycast alignment. This does not
  verify Android native multiplayer or terrain traversal.
- `entrance-collision-current.log`: 32 entrance hoods and 96 underside
  rays pass. This verifies canopy bullet collision, not player traversal.

The close entrance capture (`entrance-normal-bias2-retry.log`) reached
`ENTRANCE_DRAW_BEGIN` after 38.342 seconds but terminated with timeout exit
124 at 420 seconds without an image. This does not validate canopy contact
shadows. Do not reuse the spawn image as evidence for this close view.

The road shader now explicitly decodes photographic pavement into linear
reflectance before mixing aggregate with binder, and converts the resulting
asphalt mixture to sRGB for Compatibility. The shoulder and shared meadow
samples retain their existing working colour space. This addresses the
nearly black asphalt visible in the normal-bias spawn capture. The full-world
`spawn-asphalt-color-space/default-spawn.png` was rendered and visually reviewed:
the road now reads as gray aggregate instead of near-black pavement. Retain the
color-space correction. The bright edge paint and muddy, repetitive vegetation
along the shoulders still need work; this image does not establish overall
visual acceptance. The 640 × 400 Compatibility capture kept MSAA and shadows
enabled and took 104.002 seconds for its first draw on llvmpipe
(`spawn-asphalt-color-space.log`, exit 0). This is visual evidence, not evidence
of playable frame rates.

## Still required

September 24 follow-up: lowering edge-paint reflectance and filtering fine
paint flakes by pixel footprint was inspected in the successful 640 × 400
`spawn-filtered-paint-final/default-spawn.png` capture. Retain this change:
the paint reads as worn markings against gray aggregate. The olive-brown
shoulders still look flat, vegetation is visibly repeated, and the first-person
sleeve silhouette remains angular. This is not overall visual acceptance.
The draw took 99.828 seconds on llvmpipe with MSAA and shadows enabled;
it does not establish playable performance.

Earlier,
`spawn-filtered-paint.log` reached the first draw at 38.606 seconds but exited
124 at the 260-second limit without a screenshot. The 320-wide entrance
attempt (`entrance-contact-320.log`) likewise timed out at 300 seconds without
an image. Neither failed attempt proves a material improvement or contact-shadow
quality. Close entrance contact shadows still require a successful capture.

`roof-ridge-solid.log` now passes all 12 roof checks, sloped monitor-roof
rays and doorway clearance. The visible monitor ridge cap now blocks shots.
Center rays explicitly test its horizontal top at 8.085 m; off-center rays
test the sloping sheet normals and heights. This covers bullet collision,
not character traversal or visual contact-shadow quality.

The local preview packager now exports an isolated client snapshot, excluding
the Godot editor cache/credentials, instead of requiring a clean Git worktree.
The verification report and package build metadata distinguish the base
commit from the snapshot SHA-256 and record dirty-worktree status; the
per-file source manifest is retained beside the packages.

The snapshot `c1fa59a12512-20260924T012325800212Z` now has
`packaged-and-linux-verified` status. Its source SHA-256 is
`227e3d146bdb5ee919cce14ab8821a7a4b87bcec9a9371914275e6d9f1ddb66c`.
The actual packaged Linux runtime passed solo gameplay (16 actors, reload,
healing, damage, victory, raycast, cover, fire interval and rig), 108 aim
samples across three weapons, and the 12-roof collision test. Logs and
`verification.json` are retained in its `artifacts/visual-preview/` directory.
Linux and Windows ZIPs are available there; Windows was exported but has
not been executed. These are local previews, not a public release, and
the tests do not establish physical-GPU frame rates or visual acceptance.

Full-world visual acceptance, head/material improvements, first-person hands
and weapons, landscape and architecture review, and player traversal remain
outstanding. The packaged single-player, aim and roof-ray checks above are
complete for this snapshot only. No GitHub push was performed.

## Entrance lighting follow-up

The `entrance-cell-batches/entrance-close.png` capture completed at 640 × 400.
The draw alone took 254.571 seconds on llvmpipe. It shows the canopy and
interior trusses, but the shaded weapon remains very dark and the sleeve
silhouette is still angular. Sixty local shadow lights were disabled for
this diagnostic; this image cannot establish final contact-shadow quality.

Facade and detail batches now occupy separate 16-metre cells. The dedicated
`tests/facade_batch_test.gd` check passed transformed-world placements and
rotated non-cubic detail geometry. Box dimensions are applied along local
mesh axes before rotation. These checks establish transform preservation,
not an improvement in frame rate.

Compatibility sky reflections are retained after inspecting the same-camera
comparison in `entrance-sky-reflection/entrance-close.png`. The capture exited
successfully with `ENTRANCE_DIAGNOSTIC_CAPTURE_PASS frames=1`; its draw took
250.074 seconds on llvmpipe. The receiver, door surround and canopy now retain
visible shaded surface detail instead of approaching black. The weapon still
looks uniformly grey, the sleeve remains angular, and the sparse interior is
not visually accepted. This comparison also includes the local-axis box scale
correction, so it is not a strictly isolated reflection experiment.

Both images disable 60 local shadow lights. Neither the four-second difference
in these single software-rendered frames nor the clearer metal establishes
hardware performance or correct indoor reflection occlusion. Check full
lighting on a physical GPU and review weapon roughness variation next.
The reflection change is not yet included in the local preview or Android
release.

## Receiver finish and sleeve follow-up

The same-camera `entrance-dark-anodizing/entrance-close.png` capture completed
with `ENTRANCE_DIAGNOSTIC_CAPTURE_PASS frames=1` (249.223-second software draw).
The darker receiver base and tighter roughness retain readable shoulder
highlights while separating the receiver from the stock. Retain this change
for subsequent review; the small image does not establish final weapon quality.
The material check passed 3 models / 29 surfaces and the aim check passed
108 samples across 3 weapons, including transitions, recoil, lean and raycasts.

The sleeve still presents long, angular sides in this capture. The next asset
revision removes the superellipse expansion of the forearm cross-section,
keeping the anatomical ellipse, localized folds, seam endpoints and rig.
That revision requires a rebuilt asset, pose checks and a new rendered image
before visual acceptance. Neither change has been added to the public APK.

The elliptical sleeve asset has now rebuilt and imported successfully.
`sleeve-ellipse-rules.log` reports `VIEWMODEL_RULES_PASS`, covering rig,
optic alignment, reload durations, throw, heal, inventory preservation, reset
and death behavior. This headless check does not prove rendered skin quality.
The same-camera `entrance-sleeve-ellipse/entrance-close.png` capture completed
and was compared visually against the dark-anodizing baseline. The silhouette
change is small and the arm still reads as a model; this is not realism
acceptance. Its diagnostic draw took 249.069 seconds with 60 local shadow
lights disabled.

`entrance-interior-review/entrance-inside.png` also completed (49.286-second
draw with the same shadow diagnostic). Inspection revealed that this pose
faces the exit, not the rear workbench and shelves. It shows flat wall paint
and the doorway, but does not establish interior furnishing quality. A
separate `warehouse-rear` pose now looks from the entrance toward the rear
wall so that subsequent review can assess the actual interior.

## West workshop material review

The `warehouse-rear` pose is in the east warehouse at positive X; it cannot
validate the west workshop fixtures centered at (-42, 0, 34). Added
`workshop-rear` at (-40.2, 0.25, 37), looking toward (-42, 1.9, 28).
`workshop-rear-before/workshop-rear.png` now shows the actual workbench and
rear shelves, with an 8.391-second diagnostic draw.

Lower wall protection now uses world-scale triplanar painted plaster,
roughness and a restrained normal strength of 0.18. The matching
`workshop-rear-plaster/workshop-rear.png` completed with
`ENTRANCE_DIAGNOSTIC_CAPTURE_PASS frames=1` (7.795-second draw).
Visual inspection shows subdued mottling instead of the pale solid stripe,
but the darker wall loses some separation from the fixtures. The repeated
boxes and block-like workbench still need improvement; this is not overall
realism acceptance. Both images use 640x400 and disable 60 local shadow
lights; these software renders establish neither production performance nor
full-shadow appearance. The solo scene initialized successfully; this
material-only change does not constitute a new aim/collision test or a new
published/local packaged build.

### Workshop cargo variety

Replaced the twelve repeated green shelf boxes with eight cartons in
different dimensions and separated groups. Cardboard has dedicated matte
materials, avoiding the default wall-material mapping. Top fold seams,
sealing tape and front labels give the shelves a recognizable storage use.
All cartons remain inside the shelf footprint.

`artifacts/realism523-validation/workshop-cargo/workshop-rear.png` is an
actual solo-scene capture (`ENTRANCE_DIAGNOSTIC_CAPTURE_PASS frames=1`,
7.616-second software draw). Inspection shows more varied silhouettes and
clearer storage contents; the labels remain rather bright and the room,
bench and first-person arm still look simplified. The minimap obscures
part of the top shelf. This is incremental improvement, not acceptance
of the overall requested realism.

`workshop-cargo-traversal.log` reports `WEST_WORKSHOP_TRAVERSAL_PASS`,
covering real standing/crouched movement, rack/workbench obstruction and
the test's shot-collision checks. The capture uses the same 640x400
Compatibility setup with 60 local shadow lights disabled; it does not
prove full-shadow quality or real-device frame rate. These edits are not
yet in the Android release or the existing local packaged preview.

### Refreshed desktop preview, 2026-09-24 03:07 UTC

The accumulated weapon finish, elliptical sleeve, workshop paint and cargo
changes are now packaged in
`artifacts/visual-preview/c1fa59a12512-20260924T030733606790Z`.
The source snapshot includes uncommitted work; its aggregate SHA-256 is
`141038f596ce74eed25663ded42a64bd6fd3c08552b79a2b583857783e0ec6ef`.

The packaged Linux executable passed offline play with 16 actors,
reload/healing/damage/victory, 108 aim samples across three weapons,
12 roof collision cases, and the additional west workshop traversal
script. Both ZIP archives passed full entry CRC and recorded SHA-256
verification. Evidence is in that directory's `verification.json` and
`logs/packaged-*.log`.

Windows export succeeded but has not been executed on Windows. These are
local desktop previews, not a new Android release or online publication.
The workshop cargo screenshot above remains the visual evidence for the
source changes: it is not a screenshot captured from the packaged build.
Actual GPU performance and overall realism acceptance remain unverified;
the visible arm, bench, cargo labels and room lighting still need work.

### Workshop bench and concrete material review, 2026-09-24

Rebuilt the workshop hand-tool asset in Blender with open/ring spanners,
ribbed screwdriver grips and a shaped hammer. The board now has filtered
perforations, folded edges and fasteners; the bench has timber seams and
steel legs/bracing. Added a cast-body bench vise with separate jaws,
guide, screw, sliding handle and mounting bolts, and varied hanging-tool
spacing. Sources are `tools/build_workshop_tools.py`,
`art/workshop_tools.blend` and `client/assets/realism/workshop_tools.glb`.

Corrected linear procedural concrete colour conversion for the
Compatibility renderer. Inspected actual solo-scene images:
`artifacts/realism523-validation/bench-concrete-color/workshop-bench.png`,
`exterior-concrete-color/entrance-oblique.png`, and
`bench-vise/workshop-bench.png` (the latter two under the same validation
directory). Concrete now reads as grey rather than overly dark; the vise
is visible and recognizable at the bench. The latest capture reports
`ENTRANCE_DIAGNOSTIC_CAPTURE_PASS frames=1`, and
`bench-vise-traversal.log` reports `WEST_WORKSHOP_TRAVERSAL_PASS`.

These are 960x600 software Compatibility captures with 60 local shadow
lights disabled, not full-shadow or device performance acceptance.
The wall lighting is still flat, the timber lacks convincing wear,
the tools remain rather uniformly aligned, and the first-person sleeve
and weapon finish remain simplified. Overall requested realism is not
achieved. These changes are not in the public Android stable release.

The desktop packaging script now checks workshop traversal against the
packaged Linux game and reads every ZIP entry for CRC validation before
reporting success. A fresh build is recorded in
`artifacts/realism523-validation/bench-vise-package.log`; its verification
report, rather than build initiation, determines packaging success.

The completed desktop build is
`artifacts/visual-preview/c1fa59a12512-20260924T072542610501Z/`.
Its `verification.json` reports `packaged-and-linux-verified`: Linux
offline, roof collision, aim alignment and workshop traversal passed,
and both desktop ZIP archives passed full CRC reads. The actual packaged
Linux screenshot is
`artifacts/realism523-validation/packaged-bench-vise/workshop-bench.png`.
Windows execution and physical GPU performance remain unverified.
This package predates the receiver coating experiment below.

Receiver coating experiment: reduce the body metallic factor from .70
to .28 and increase roughness from .34 to .46, retaining a more reflective
shoulder (.55 metallic, .35 roughness). This targets the overly uniform
blue-grey receiver in the packaged screenshot. No geometry, sight anchor,
animation or collision edits are involved. Visual acceptance is pending
the matching actual game capture; these values alone do not prove realism.

### Receiver runtime coating verification — 2026-09-24

Found that `weapon_finish()` overwrote the imported receiver metalness with
0.7, defeating the Blender coating experiment. Baked receiver finishes now
retain source metalness, and baked roughness maps retain their source multiplier.
The procedural finish remains available for untextured parts.

`tests/weapon_finish_rules.gd` passes for 3 models / 29 surfaces / 4 baked
normal surfaces, including source isolation, cache reuse, retained roughness
factor and authored receiver metalness. Shotgun still carries its previous
0.7 source metalness; the new sub-0.6 coating check applies to the rebuilt
carbine. `tests/aim_alignment.gd` passes all 108 samples across 3 weapons,
including recoil, lean and authority raycast checks.

Actual Compatibility screenshot:
`artifacts/realism523-validation/receiver-runtime/workshop-bench.png`.
The difference from `receiver-coating/workshop-bench.png` is confined to
(605,414)–(730,559), confirming the receiver change reaches the rendered game.
This is a small material correction, not overall visual acceptance: the room
still has flat illumination, overly uniform tools/bench surfaces and simplified
first-person arms. The capture disables 60 local shadows for software-renderer
diagnostics; it does not establish full-quality lighting or hardware performance.
Previously packaged desktop previews and published Android APK do not include
this runtime change. Goal remains incomplete.

### Workshop detail and desktop refresh — 2026-09-25

The bench now uses metre-scaled wood grain, board colour variation, oil wear,
a partial cup ring and subtle cuts. The Blender assembly includes the task
light and conduit, parts tray and oil bottle, a lower shelf with an open tool
tote and coiled hose. Seven hanging tools have individual heights and angles;
the maintenance cloth uses tapered irregular creases instead of periodic waves.
Two wider spot lights distribute illumination along the bench.

Reviewed actual game screenshot:
`artifacts/realism523-validation/bench-natural/workshop-bench.png`.
Its log records a successful solo diagnostic capture, with 61 local shadows
disabled on llvmpipe. The altered silhouettes and stored objects are visible;
the room still looks sparsely furnished, illumination is flat, and the forearm
is thin and lacks convincing fabric volume. This does not meet overall visual
acceptance and does not establish physical GPU lighting quality.

`bench-storage-traversal.log` records `WEST_WORKSHOP_TRAVERSAL_PASS`;
`bench-storage-aim.log` records all 108 samples passing for 3 weapons,
including transitions, recoil, lean and raycasts. A new desktop preview is
exported from the current client snapshot passed its packaged Linux offline,
roof collision, 108-sample aim alignment and workshop traversal checks.
Both archive CRC checks passed. Evidence:
`artifacts/visual-preview/c1fa59a12512-20260925T022918410859Z/verification.json`
(`packaged-and-linux-verified`, source SHA-256
`afa531068e279c41d7f4fc3cc04ab693cb503b5b833b95878d6400593167e6a0`).
The directory contains Linux and Windows VisualPreview ZIPs. Windows was
exported but not executed on Windows hardware; packaged full-quality GPU
rendering and online play are not established by these headless checks.
The published Android stable build remains separate from these changes.
