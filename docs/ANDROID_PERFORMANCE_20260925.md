# Android performance investigation — 2026-09-25

The user reports severe Android lag. Version 0.52.8 introduces Android-only
rendering defaults while retaining the latest world, building and weapon assets:

- Render through a 1440 × 900 viewport rather than scaling only the UI over
  the device's native-resolution 3D framebuffer.
- Keep one in four grass instances, preserving coverage, transforms, colors
  and shader custom data. Hide grass beyond 40 metres and disable its shadows.
- Use a single directional shadow map, 1024 pixels, with a 45-metre range.
- Disable MSAA and cap the frame rate at 60.

These initial changes reduce rendering work; they do not establish a measured speedup
over 0.52.7. The older native walkthrough did not record frame times.

`tests/mobile_performance_test.gd` checks instance reduction and preservation,
shadow settings, viewport configuration and collision preservation.
`tools/android_native_walkthrough.py` now captures wall-clock frame timing
during six cycles of native movement, firing and camera movement.
Loading/menu samples are excluded from that measurement.

The r11 candidate failed measured gameplay performance on Pixel 10: samples
ranged from 1.8 to 14.3 FPS, with up to 116 million primitives per frame.
It must not be published as a performance fix. Its functional walkthrough
passed before the walkthrough acquired explicit performance assertions.

The r12 candidate additionally identifies embedded grass shaders by their code
(packed resources can lose the original shader path), explicitly culls
distance-limited geometry on the CPU, and uses the existing far fir model for
Android trees. Desktop tree detail is unchanged. The native walkthrough now
requires at least four samples, each at least 24 FPS with p95 frame time no
greater than 75 ms. These are release gates, not claimed results.

r12 also failed the performance gate: measured gameplay samples ranged from
2.3 to 7.2 FPS with p95 frame times as high as 2006 ms. Inspection found that
desktop cache baking bypassed the Android fir replacement, retaining expensive
tree LODs. It is not released.

The r14 candidate (0.52.9) applies the mobile tree replacement during cache
baking as well as native construction. A Blender-generated mobile fir has
7,241 triangles, down from approximately 60,000 in the previous far model.
Hidden original trees are excluded from manual distance-culling registration.
The mobile profile disables decorative local lights and world shadows, reduces
grass to one in sixteen instances with a 30-metre visibility limit, and uses
0.65 3D scaling. Grass detection also checks mesh surface materials.
These settings supersede the initial settings listed above.

r14 signed APK construction, mobile performance configuration checks, and all
five UI/control regressions passed. Native validation failed: 10.3–20.5 FPS,
with p95 frame time up to 101.3 ms. Screenshots also showed the player had
already been eliminated, so that run does not establish live combat performance.
It is not released.

r15 (0.52.10) adds Blender-decimated shrubs (3,397 triangles) and birches
(8,608 triangles), retaining their materials. Small facade decorations are
distance-culled according to their bounds. The native walkthrough starts
earlier and requires telemetry confirming the player remains alive in combat.
Native validation failed: the surviving player initially reached 24.7–25.9 FPS,
but died before the sustained sample window. This candidate is not released.

r16 (0.52.11) batches repeated static meshes in 16 m cells, preserving transforms,
materials and collision children. Hidden meshes, explicit LODs, surface overrides,
and shader materials are excluded. The regression check passes for transforms,
hidden exclusions and retained physics nodes. The exact packaged source passes
all five UI/control regressions, the mobile rendering regression, AWS solo/duo
connections and remembered-login checks. Pixel 10 fuzz validation passes.
Sustained native gameplay validation failed: 15.3–59 FPS, with p95 frame time
up to 123.9 ms. All nine samples confirmed live gameplay with the player alive.
The dense starting area submitted about 2,739 draws and 2.38 million primitives;
performance improved after leaving it. This candidate is not released.

r17 (0.52.12) merges differently sized BoxMesh facade pieces by material and
16 m cell. This extends the previous identical-mesh batching while retaining
collision children and hidden-mesh exclusions. The local rendering regression
checks merged geometry bounds, material assignment and retained collisions.
Signed APK construction and functional checks passed. Sustained native
performance failed (15.8–58 FPS, p95 up to 90 ms); all nine samples were live
with the player alive. This candidate is not released.

r18 (0.52.13) adds mobile meshes for rocks, crates, air conditioners and lamps,
and combines opaque static primitive shapes sharing a material per spatial cell.
Signed APK construction, exact-snapshot static batching regression, five UI
checks, solo/duo network checks and Pixel 10 fuzz validation passed. Native
gameplay performance failed (13.6–60 FPS, p95 up to 109.6 ms), with all nine
samples live and alive. This candidate is not released.

r19 (0.52.14) extends static batching to single-surface triangle ArrayMeshes
and equivalent opaque material copies, and reduces small/medium detail ranges
to 24/64 m. Local regression verifies copied identical materials merge while
a different albedo remains separate, alongside existing collision, transforms,
hidden geometry, grass and window checks. APK construction, UI, networking
and fuzz checks passed. Native validation failed at 10.9–35.5 FPS, p95 up
to 353.4 ms; all eight gameplay samples were live and alive. Not released.

r20 (0.52.15) replaces Android terrain's procedural fragment geology with
scanned texture variation and slope-based rock coverage, and fixes warehouse
crates bypassing the mobile mesh selector. Build, packaged configuration, UI,
networking and physical fuzz checks passed. Native gameplay failed at
6.9–29.4 FPS, p95 up to 583.3 ms; all eight samples were live and alive.
Not released. The next diagnostic records CPU process, physics and distance
culling peaks, and avoids redundant visibility updates.

Build and validation evidence is stored under
`artifacts/android-performance-20260925-r11/` and
`artifacts/android-performance-20260925-r12/`.
The current candidate evidence is in
`artifacts/android-performance-20260925-r21/`.
r21 (0.52.16) avoids rebuilding unchanged loot meshes and records CPU peaks.
Build, exact packaged static checks, five UI checks, solo/duo networking and
Pixel 10 fuzz checks passed. Native combat validation failed: movement samples
fell to 8.3 FPS with p95 593.3 ms, and the player died during the walkthrough.
Live process peaks reached 1595.3 ms, while physics and culling peaked at
24.5 ms and 11.3 ms in the movement samples. These counters do not establish
whether script work or rendering caused the stalls. This APK is not released.
The working tree now records slow game-loop sections separately (actors,
network, team UI, sound, world/loot and HUD interactions) to localize stalls.
Device-specific frame rates do not establish performance on all Android phones.
Native multiplayer performance and physical gyroscope feel need separate tests.

The APK also contains the static-grass shader correction investigated in
Stage 529. Its isolated desktop diagnostic improves grass color and lighting;
full-scene desktop before/after captures did not complete on software rendering.
The overall visual-quality goal remains unfinished.


r22 (0.52.17) native validation failed: live gameplay 8.3–33.3 FPS,
p95 up to 595.3 ms after joining. Instrumented script sections did not emit
any >=50 ms warning despite TIME_PROCESS peaks above one second. This does
not isolate the engine-side cause. Not released.

r23 candidate (0.52.18) restores instancing of original imported ArrayMesh
resources; only PrimitiveMesh details are rebuilt with SurfaceTool. This
preserves imported LOD data rather than discarding it during surface merging.
Regression with a secondary index LOD verifies original mesh resource retention,
instance transforms and existing collision/grass checks. Passed:
artifacts/android-performance-lod-test.log. HUD text is assembled before assigning
labels, avoiding repeated clear/append invalidation. Build, packaged static checks,
UI, source networking and Pixel 10 fuzz checks passed. Native gameplay failed:
9.0–27.8 FPS, p95 up to 588.4 ms; all nine samples were live and alive.
Rendering submitted 1.2–2.1 million triangles. Not released.

r24 candidate (0.52.19) halves Android terrain subdivision outside the service
yard, using the same sampling axis for rendered ground and collision. Yard
detail and desktop sampling remain unchanged. Build, packaged static checks,
UI, source networking and Pixel 10 fuzz checks passed. Native gameplay failed:
10.6–38.4 FPS, p95 up to 455.3 ms; all eight samples were live and alive.
Terrain collision triangles fell from 410688 to 210520. Not released.

r25 candidate (0.52.20) shares distance rules between individual meshes and
static batches: sub-0.5m details end at 10m, sub-3m props at 18m, and sub-12m
props at 40m. Larger silhouettes retain their previous range. This reduces
distant decoration submissions. Native gameplay failed: 10.8–59 FPS, p95 up
to 387 ms; all eight samples were live and alive. Build, static, UI, networking
and fuzz checks passed. Not released.

r26 candidate (0.52.21) renders eight ground-level headings behind the loading
screen before accepting input, to exercise nearby GLES material variants.
Adds viewport CPU/GPU render timing to distinguish rendering stalls from
script time (unsupported GPU timer readings may be zero). Native performance
failed: live gameplay fell to 11 FPS with p95 up to 339.1 ms. GPU timing
returned a constant approximately 5.5e12 ms, so those GPU readings are invalid.
Not released.

r27 candidate (0.52.22) selects imported mesh LODs at a four-pixel threshold
on Android, reducing distant geometry while retaining the latest assets.
Removes the invalid GPU timer instrumentation; frame-time measurements remain.
Native gameplay failed: 11.8–58.8 FPS, p95 up to 362.9 ms; all eight
samples were live and alive. Not released.

r28 candidate removes unused procedural weapon texture generation for baked
materials and Android explosion point lights (GLES extra lighting passes).
Latest weapon maps, models, smoke and sparks are retained. Build, static, UI,
source networking and Pixel 10 fuzz checks passed. Native gameplay failed:
15.3–59.6 FPS, p95 up to 298.7 ms; all eight samples were live and alive.
Draw submissions fell from roughly 1400 to 266 as the view changed, so the
later high FPS does not establish that dense views are fixed. Not released.

Next candidate adds distance detail selection for dynamic loot, which is
created after the static culling registry. Beyond 24m it uses the existing
category-coloured proxy; nearby cases and attachments retain the latest assets.
Pickup positions and gameplay data are unchanged. r29 native validation failed:
16–59 FPS, p95 up to 343.5 ms. Not released.

Next candidate adds Android adaptive 3D resolution (0.45–0.65), sampling
sustained frame times over two seconds and allowing recovery only after eight
seconds of headroom. UI dimensions, models and textures remain unchanged.
Diagnostics retain every frame, including loading stalls. This addresses
rendering load; it does not establish that the opening stall is fixed.

r30 adaptive-resolution native test failed: 17.3–59.8 FPS, p95 up to
100.8 ms. UI, networking and fuzz passed; candidate remains unpublished.
r31 applies VRAM compression and a 1024px cap to mipmapped asset textures
in the Android staging directory, retaining original desktop sources.
The import policy is recorded separately from the original source manifest.
This targets texture memory/upload pressure; improvement requires native testing.

r31 failed native gameplay: 22.4–59 FPS in the scored movement/fire window,
with opening live samples as low as 14.5 FPS and p95 528 ms. Not published.
CPU process peaks reached 812 ms; static culling alone reached 14 ms.
Main gameplay process section instrumentation did not explain the large stalls.
The next change budgets static visibility scanning to 1.5 ms per frame,
retaining a continuation cursor, and adds render pre/post-draw CPU wall timing
to distinguish render/driver waits from gameplay work. This is diagnostic
evidence gathering, not a claim that Android stutter is resolved.

r32 reduced static culling peaks to about 2 ms. Native scored samples were
29.8–58.8 FPS, p95 24.2–40.6 ms, but the player died in the final three
samples, so the walkthrough failed and the APK was not published.
Opening live diagnostics still showed 268.4 ms p95 and 520 ms render
wall-time peaks. Steady-state numbers do not establish smooth entry to combat.

r33 caches military materials by source material and renders both sides of
nine combat assets behind the loading screen before exposing the menu.
Hidden warmup resources remain alive to retain uploaded materials/geometry.
The warmup regression check verifies camera restoration, hidden resources,
material reuse and absence of collision objects. It passed under software GL.
Android import now uses Godot's separate render thread: the previous safe
mode failed render-device finalization under llvmpipe. Import, terrain baking,
APK export and signature verification passed after this change.
Candidate 0.52.28 SHA256:
625de943d02cc982aa25233838ce5d669c8e29d4c96dc87a94bcf837ec4f803c.
The first native walkthrough failed its living-player gate. Its scored FPS
was 31–57.3 and p95 was 24.5–40.9 ms, but four of eight samples were after
death and cannot establish sustained combat performance. Opening live
diagnostics were 24.1–30.8 FPS with p95 up to 43.1 ms.
The continuous forward sprint may have carried the player out of the safe
zone; incoming enemy fire is also visible. The cause of death is unconfirmed.
A second walkthrough of the identical APK alternates strafing near the
initial approach and uses ordinary healing controls, with per-cycle
screenshots. No game rules or performance gates were changed.
Evidence is in `artifacts/android-performance-20260925-r33-route`.
The second test failed: all ten scored samples were spectator frames.
The cycle-01 screenshot identifies a bot frag grenade, 1m from the blast,
as the cause of death (91 health and 36 armor damage). Its 28.1–33.8 FPS
cannot establish combat performance. A third run of the same APK uses
shorter forward/lateral movements to evade grenades while staying in the
zone, retaining every living-player and frame-time gate.
Evidence is in `artifacts/android-performance-20260925-r33-moving`.
The third native run PASSED. All eight measured states were live/alive;
FPS 25.9–32.4, p95 frame time 38.7–45.7 ms. Screenshots 03-fire,
04-look and cycle-06 were reviewed: geometry, gun, firing, camera and HUD
are present, with visible resolution/foliage aliasing. This is a short
Pixel 10 solo test, not evidence of stable 60 FPS, thermal stability,
physical gyro feel or native online performance on other devices.
The APK is approved for this performance-fix release; public verification
is recorded separately in publication.json after upload.

Published 0.52.28 through the existing private S3/OAC distribution.
Public APK download SHA-256 matches the tested archive; updated page
and QR target this build. Public login form absent, /login denied,
/api/docs unavailable and GET /api/auth/login rejected as expected.
Download: https://d3j1sc8stx5n1c.cloudfront.net/downloads/IronMeridian-Android-0.52.28-20260925.apk
Publication evidence: artifacts/android-performance-20260925-r33-moving/publication.json

### Follow-up: bounded dynamic loot scanning (source only)

The reported Android stutter remains unresolved at the device level. The
published short Pixel 10 run above measures roughly 26–32 FPS.
Dynamic loot previously scanned its entire dictionary on every static-cull
continuation frame, outside that scan's time budget. It now has an independent
cursor, a 500 µs soft budget and a 64-entry maximum per frame. Static scanning
uses a 1,000 µs soft budget; both scans retain their 50 ms cooldown.
Loot snapshots store IDs and resolve current proxies each step, tolerating
pickups and replacements without retaining freed node references. Snapshot
creation and an individual visibility update can still exceed the soft budget.

Validation: `mobile_performance_test.gd` passes with Xvfb/OpenGL compatibility,
including 150 loot entries, multi-frame continuation, deletion and replacement.
The headless dummy-renderer run reached an existing MultiMesh transform assertion;
the real OpenGL run passed the complete suite. These are functional regressions,
not native Android performance measurements. No new APK has been published for
this change; the current download is still 0.52.28.

### r34 native result and Android animation sampling

The unpublished 0.52.29 candidate (`android-performance-20260925-r34`)
passed UI, source-network, Device Farm fuzz and native walkthrough gates.
Its eight live/alive Pixel 10 samples were 25.4–32.3 FPS, with p95 frame
times of 39.4–47.0 ms. This is not a material improvement over the published
0.52.28. Passing the functional gate does not establish that stutter is fixed.
The public download remains 0.52.28.

Further source changes sample Android character poses by camera distance:
local/nearby/seated actors retain full-rate animation; visible actors at
20–50 m use 30 Hz and beyond 50 m use 15 Hz; distant offscreen actors use
10 Hz. Elapsed animation time is accumulated, and stance, grounded state,
reload, weapon, seating, downed and death transitions force a pose update.
Network position interpolation and collision simulation remain per-frame.
This reduces pose/weapon-attachment work, but has no native FPS evidence yet.

Validation passed:
- `animation_cadence_test.gd`: elapsed-time conservation and state transitions.
- `android_actor_animation_test.gd`: actual imported actor, continuous network
  movement during skipped pose updates, immediate crouch/reload/death.
- `animation_rules.gd` under Xvfb/OpenGL: skin deformation, foot contact,
  walking/running/reload/jump/death. The fixture now loads the actor directly
  instead of constructing the unrelated full map and navigation mesh.

### r35 candidate validation

Built candidate 0.52.30 as a signed APK containing the
animation sampling and bounded loot scan changes. APK SHA-256:
`6fcc33073341a3ea44ffc35e8ee019a79a53eb0e1b6dc3319307d52eebc6aa74`.
Evidence directory: `artifacts/android-performance-20260925-r35`.

The Android packaging importer now uses Xvfb/OpenGL compatibility instead of
the dummy headless renderer. A clean import attempt encountered a renderer
shutdown error; resuming the validated cached import completed without errors.
Failed import logs are retained alongside the successful build logs.

Source-based login memory, mobile controls, aim alignment, gyro and solo/duo
network checks passed. Device Farm fuzz and native walkthrough passed on Pixel 10.
Eight live/alive combat samples measured 27.6–36.9 FPS (mean 32.5), with maximum
p95 frame time 43.0 ms. The preceding r34 candidate averaged 29.675 FPS in
one comparable short run; this is indicative improvement, not a controlled
benchmark or proof of sustained smooth performance. Screenshots 03-fire and
04-look show intact scene and HUD; low-resolution aliasing remains.
Published 0.52.30 through the existing private S3/OAC distribution. Public APK
SHA-256 matches the tested archive; download page and QR updated. Public site
contains no login form; login/docs endpoint exposure checks passed. Evidence:
`artifacts/android-performance-20260925-r35/publication.json`.
Android lag remains unresolved overall; this release is an incremental improvement.

### r36 mobile character candidate

The Android actor and combat warmup now load `operator_mobile.glb`, derived
from the current Blender character by `tools/build_android_operator.py`.
Rest-mesh triangle count falls from 132,460 to 33,114 while retaining the
rig, texture materials and animation actions. Desktop still uses the full
character. This targets rendering and skinning cost without removing the
latest character artwork.

Both full and mobile character animation rules passed under Xvfb/OpenGL:
17 bones, 15 clips, six materials, cloth UV coverage, crouch deformation and
feet contact, walking/running/reload/jump/death. A side-by-side render shows
the same silhouette, clothing and equipment without obvious missing parts.
Evidence is stored in `artifacts/android-performance-20260925-r36`.

Candidate 0.52.31 is signed and packaged. The first import encountered the
existing renderer shutdown error; the cached-import resume completed.
Login memory, touch, aim and gyro source checks passed. Native performance
testing completed: Device Farm fuzz and native solo walkthrough passed on Pixel 10.
Eight live/alive combat samples measured 26.3–38.2 FPS (mean 33.775),
maximum p95 frame time 41.2 ms. The previous short run averaged 32.5 FPS;
this small difference is not a controlled benchmark. Minimum sampled FPS
regressed from 27.6 to 26.3, so sustained smooth gameplay remains unresolved.
Screenshots 03-fire and 04-look show intact scene, weapon, arms and HUD;
aliasing and side black bars remain. Solo/duo source network checks also passed.
Native Android networking, physical gyro and thermal endurance remain untested.

Published 0.52.31 through the existing private S3/OAC distribution; the download
page and QR code point to the new APK. Public download SHA-256 matches the
tested archive:
`d60d8ae69eee5294c063103f7f7d8a07c20334e16d258d16d4442d2287f4895d`.
The publication check found no login form on the public website. Evidence:
`artifacts/android-performance-20260925-r36/publication.json`.
This is an incremental optimization release; Android lag is not fully resolved.

### Mobile first-person arms (candidate 0.52.32, not published)

`tools/build_android_first_person.py` derives the mobile arms from the authored
Blender rig, reducing mesh triangles from 108,464 to 27,115. Android actor setup
and combat warmup select this asset. Materials, skeleton and four actions remain.
Mobile forearm rules compare every bone rest transform and sampled animation
poses with the desktop asset. The authored forearm is 0.26 m; the stale
0.27–0.34 m assertion was corrected to match the Blender source.

OpenGL rendered skin, ADS alignment, reload contact across three weapons,
throw/heal/reset/death and rig equivalence checks pass. The isolated mobile
viewmodel fixture now includes lighting so screenshots can be inspected.
The reload capture shows both sleeves/hands and the weapon without obvious
missing geometry. Evidence: `artifacts/android-arms-optimization-20260925`.
The signed 0.52.32 candidate passed Device Farm fuzz, source solo/duo,
remembered-login, touch, aim and gyro checks. The native Pixel 10 walkthrough
failed because the player died. Live samples were approximately 29–37 FPS,
with render-phase peaks up to 492 ms; reducing arm geometry did not resolve
the stalls. Evidence: `artifacts/android-performance-20260925-r37`.
This candidate is not published. No frame-rate improvement is claimed for it.

### September 26: mobile weapons and measurement isolation (r38, not published)

`tools/build_android_weapons.py` derives mobile third-person weapons from the
current authored models. Triangles fall from 58,444 to 12,509 for the carbine,
17,020 to 3,571 for the shotgun, and 30,958 to 6,684 for the marksman rifle.
First-person weapons retain their full assets. OpenGL mobile weapon rules pass
for bounds, anchors, material regions, source texture pixels and asset selection.
The mobile first-person arms from r37 are also included.

The native walkthrough now excludes screenshots from its six measured input
cycles and discards the first rolling telemetry interval. Survival, sample
count and performance thresholds remain unchanged. Retesting r37 this way still
measured 27.5–38.8 FPS and failed the survival assertion, so screenshot capture
does not explain the persistent performance problem.

Signed r38 (0.52.33-android.20260926, version code 20261025) passed Device Farm
fuzz on Pixel 10, source solo/duo network checks, remembered-login, touch, aim
and gyro checks. Native solo samples measured 26.8, 33.7, 36.6, 36.5, 37.4 and
34.7 FPS, with p95 frame times 38.2–45.5 ms. The final sample was dead, causing
the walkthrough to fail. This candidate is not published and lag is unresolved.

Evidence: `artifacts/android-performance-20260926-r38`; APK SHA-256
`86f0b8fdd2664b332ddbc9a798e9cd3334bf424eeba77491a5ef10f196404c75`.
Combat telemetry reports 649–1,464 draws and approximately 618k–1.62M primitives;
one render-wall peak is 285.4 ms. Render-wall time includes CPU/driver waits and
is not a GPU timing measurement. Smaller character, arm and weapon meshes have
not demonstrated a material frame-rate improvement. Next investigation should
attribute scene draw submissions and physics cost before another asset-only
rebuild. Native network, physical gyro and thermal endurance remain unverified.
The public download remains the previously tested 0.52.31 release.

### September 26: tree batching (r39, validation failed; unpublished)

The mobile batcher previously rejected every mesh with a visibility end
distance, including the 460 fir trees. It now batches meshes with a plain end
cutoff, grouping by that exact cutoff as well as mesh/material identity.
Near ranges, end margins and visibility fades remain excluded. Range culling
uses each 16 m batch's center, so individual trees can disappear slightly
earlier or later at the boundary.

The scene audit retains all 460 trees: 252 individual meshes plus 95 batches
containing 208 trees, reducing fir render nodes from 460 to 347. This is a
node-count observation, not a measured draw-call or FPS improvement.
`tests/mobile_performance_test.gd` passes for distinct 90 m and 180 m groups,
mesh/LOD identity, transforms and unsupported-range exclusions.
Evidence: `artifacts/android-draw-audit-20260926`.

Signed r39 (0.52.34-android.20260926) also contains the mobile arm and weapon
optimizations from r37/r38. APK SHA-256:
`6222960ba862860accfc0ddf124897154d6d470f8a9491718775a15cf1f86b14`.
Evidence directory: `artifacts/android-performance-20260926-r39`.
Native performance validation completed: 26.4–37.3 FPS, p95 frame times
38.0–45.6 ms. This is not a meaningful improvement over r38. The final two
samples recorded a dead player, so the survival gate failed. Fuzz, source
solo/duo networking and five UI checks passed. This APK is not published.

The next source change rejects out-of-range supplies before inventory checks
in the per-tick bot pickup search and uses squared distance for ranking.
It preserves the pickup radius and accessibility checks. This change is not
included in r39 and has no measured Android FPS benefit yet.
The existing supply integration test passed with this change (exit 0,
`SUPPLY_RULES_PASS` in `/tmp/android-supply-range-test.log`): pickup conservation,
usable-item priority, wall/range restrictions and network replay checks remain
intact. This validates gameplay behavior, not a performance improvement.

### September 26: ground litter distance (r40 candidate)

Android now cuts ground litter cells off at 26 m instead of 42 m. Each cell
is 12 m wide, retaining its nearest details to approximately 17 m. Desktop
range remains unchanged. New terrain bakes tag these cells with metadata;
older cached scenes use the material shared with the named GroundLitterCell
because Godot automatically renames its siblings.

At road positions (0, 2.6, 90), (0, 2.6, 45), and (0, 2.6, 0), the scene
audit reduces distance-eligible litter cells from 56/72/67 to 24/25/29,
and instances from 726/879/805 to 288/277/335. This is a distance-only
census, not measured draw calls or a phone FPS result. Evidence:
`artifacts/android-draw-audit-20260926/litter-range.log`.
The existing mobile performance test passes with the Compatibility renderer.
The headless dummy-renderer run fails its existing imported-transform
assertion; use the real Compatibility renderer for that check.
r40 passed the functional native walkthrough, touch, source network (solo/duo),
login-memory and UI checks. Its six alive gameplay samples measured
26.9/38.1/34.5/35.6/33.6/30.7 FPS (mean 33.23), with p95 frame times
42.5/37.6/40.4/39.6/41.2/40.4 ms. This does not establish a smoothness
improvement over r36; r40 has not been published.
Evidence: `artifacts/android-performance-20260926-r40/native-walkthrough-result.json`
and its extracted `gameplay-performance.json`. The released download stays r36.

### September 26: render profiling and Vulkan candidate (r41/r42)

r41's native walkthrough passed functional checks but measured 28.7–36.8 FPS.
Rendering on the CPU took approximately 17–23 ms per frame, with additional
startup spikes. Static culling peaks were 1.2–2.1 ms; reducing geometry alone
has not established a frame-rate improvement. These are CPU timings, not GPU
timestamps. The compatibility renderer reported PowerVR D-Series on Pixel 10.

r42 tests Godot's Mobile Vulkan renderer with the same assets and mobile
quality controls. Its first APK failed Device Farm validation because Godot
4.4.1 serializes Vulkan feature `required` and `version` attributes as strings
and omits the Android resource ID for `version`. Packaging now repairs those
attributes, realigns and signs the APK, and requires `aapt dump badging` to
succeed before accepting the build. The repair is idempotent on the actual
manifest. Repaired APK SHA-256:
`4df65ab9fd67cd0b544142ea46f05af7252e16188518150aa07e669d90abb063`.

The repaired candidate passed Device Farm fuzz and UI checks, but failed the
native performance gate. Six alive movement/fire samples measured FPS
24.8, 27.2, 28.5, 26.3, 27.0, 25.5 and p95 frame times
77.8, 68.0, 65.1, 68.4, 67.0, 66.6 ms. Vulkan is slower on this
device; r42 must not be published. The mobile renderer is restored to GLES.
Per-section profiling is still enabled for diagnosis and needs disabling in
a final release after measurement.

### September 26: shader isolation (r43–r45)

On Pixel 10 with GLES, r43 measured 60.1 FPS when scene geometry was hidden,
versus 29.3–34.0 FPS with it visible. There is no fixed 33 FPS pacing limit.
r44 held the camera and render scale (0.65) constant and replaced materials
without removing geometry. Original shaders measured 25.3 FPS / 49.5 ms p95;
flat custom materials measured 59.2 FPS / 19.5 ms p95, both at 597 draws.
Hiding custom materials reached 60 FPS; hiding standard materials left only
28.8 FPS. This isolates expensive custom shading as the dominant bottleneck
in that view. These are diagnostic runs, not release performance claims.
Evidence: `artifacts/android-performance-20260926-r44/native-walkthrough-artifacts/`
(the initial `native-walkthrough.logcat`, before gameplay log clearing).

r45 reuses the existing linear-data value-noise lattice for Android meadow
and road shading. Each repeated four-hash cubic-noise evaluation becomes
one bilinear texture lookup. Desktop keeps the analytical version. Road
and meadow receive the same parameters to preserve their shared boundary.
The lattice is quantized to 8-bit and repeats every 1024 noise cells; visual
and device performance validation are required before release. The diagnostic
baseline now distinguishes ground shading from other custom materials.

r45 completed both native and fuzz tests but still measured 27.3–36.8 FPS
in gameplay. At a fixed view, original shading reached 27.3 FPS / 47.8 ms
p95, replacing ground alone reached 60.1 FPS / 18.8 ms p95, and replacing
other custom shaders reached only 29.1 FPS / 46.6 ms p95. Draw count stayed
597. Cached noise alone is insufficient; r45 remains unpublished.

### September 26: lightweight Android ground (r46)

Android meadow and road now use dedicated photographic-texture shaders,
sharing a six-sample ground function instead of repeated procedural noise.
Colony masks retain vegetation/mineral variation; ground normals and road
edge blending remain. Desktop materials are unchanged. Diagnostic material
replacement and default section profiling are disabled in this candidate.
Actual local GLES rendering of both shaders passed without shader errors.
Version 0.52.41 (20261033) is undergoing installed-APK gameplay measurement;
local rendering and packaging alone do not establish phone smoothness.

Installed r46 APK passed native gameplay and fuzz testing. Six live/alive
samples: 32.1, 42.8, 42.1, 41.4, 40.7, 36.7 FPS (mean 39.3), maximum
p95 38.3 ms. Reviewed fire/look screenshots retain textured environment and
weapon, with visible aliasing/reduced resolution. Source-bound solo/duo
network, remembered authentication, UI, aim and gyro tests passed. This is
an improvement over published r36 mean 33.8 FPS, not stable 60 FPS; phone
networking, thermal stability and other devices remain unverified.

### Follow-up: serialized Android background material

r46 publication completed; `android-performance-20260926-r46/publication.json`
confirms the public APK matches the tested SHA-256 and the download site has
no login form.

The next source revision fixes a separate export-path omission:
`meadow_surface()` now honors `bake_android_ground` when selecting its shader.
Previously the Linux export process serialized the desktop meadow shader into
Android's background ground. The bake verifier now rejects that desktop shader
and requires a mobile meadow surface after loading the saved scene again.

Local GLES baking completed with 1 mobile ground surface, 253886 validated grass
instances, and 210520 terrain collision faces. Log:
`/tmp/android-ground-mobile-bake.log`. Renderer shutdown reported two 5460-byte
texture leaks despite exit code zero; this run is bake/serialization evidence,
not a clean runtime or phone performance pass. This follow-up is not included
in the published r46 APK.

The r47 (0.52.42) installed-APK native run completed with two passing tests
and one failure: "Player must remain alive in combat". Its first five
live/alive gameplay samples were 32.6, 39.2, 43.7, 42.2 and 41.2 FPS.
The sixth sample (42.8 FPS) was in the dead state and must not be combined
with the others to claim an equivalent six-sample improvement over r46.
The candidate remains unpublished; stable 60 FPS is not established.
Evidence: `artifacts/android-performance-20260926-r47/native-walkthrough-result.json`
and its `native-walkthrough-artifacts/` directory.

The local GLES mobile performance regression passed density, instance colors
and custom data, collision, viewport, shadow and distance-culling checks.
These checks establish behavior, not phone frame rate.

The diagnostic ground-material classifier also omitted `road_surface_mobile`.
It now includes that shader and tests both external and embedded resources.
This fixes future ground-versus-other shading attribution; it is not a runtime
frame-rate optimization and does not change the published APK.

### Road texture sampling follow-up (r48, local only)

The mobile road shader skips the six meadow texture samples on pure asphalt.
Explicit texture gradients are calculated before the conditional branch to
preserve mip selection at the blend boundary. The road review fixture now
binds the actual ground textures and supports shoulder, crossing-axis and
road-end camera views.

Before/after GLES renders passed in all four views on llvmpipe at 640x400.
The default, shoulder, crossing-axis and end images respectively changed
78, 99, 84 and 187 pixels, with a maximum channel difference of one 8-bit
level. Evidence: `artifacts/android-road-20260926-r48/comparison.json` and
`seam-comparison.json`. The isolated fixture does not establish full junction
geometry, sloped-ground behavior, phone frame rate or thermal stability.
This optimization has not been published or measured on a phone.

The full desktop environment capture passed separately:
`artifacts/visual-review-20260926-r47/environment-spawn.png`. It predates r48.
Review still shows stretched foreground ground shading, foliage aliasing and
overly rounded distant terrain. The realism goal remains unfinished.

### Ground layer sampling follow-up (r49, unpublished candidate)

The shared mobile meadow shader now samples soil only where its blend weight
is nonzero, and gravel only where its blend weight is nonzero. Exact endpoint
conditions preserve the whole transition; explicit gradients remain outside
the branches. Including the colony mask, pure soil uses four texture lookups,
pure gravel three, and the blend still uses six. Actual GPU savings depend on
branch execution and must be measured on a phone.

Twelve local GLES renders (before/after for meadow and road, each at shoulder,
crossing-axis and road-end views) completed without shader errors. All six
640x400 RGB comparisons are pixel-identical. Evidence:
`artifacts/android-ground-sampling-20260926-r49/renders.json` and
`comparison.json`; expanded before/after shader sources are retained there.
The reviewed meadow shoulder image retains its textured surface, but this
isolated plane does not establish full-scene realism or phone smoothness.
The installed 0.52.43 APK subsequently passed the Device Farm fuzz and native
walkthrough runs (three tests each). Six live/alive movement/fire/look samples
were 31.6, 43.5, 41.9, 42.2, 39.2 and 34.4 FPS (mean 38.8); their p95 frame
times were 38.8, 33.3, 35.4, 34.9, 36.4 and 39.0 ms. The published r46 mean
was 39.3 FPS. These single runs establish no measurable improvement and do
not establish stable 60 FPS. Candidate remains unpublished.
Evidence: `artifacts/android-performance-20260926-r49/native-walkthrough-artifacts/Host_Machine_Files/$DEVICEFARM_LOG_DIR/gameplay-performance.json`,
`native-walkthrough-result.json` and `devicefarm-result.json` in the r49 directory.

Local candidate checks passed remembered login, login UI and aim alignment.
The gyro check timed out after 300 seconds without its pass marker; the
sequential touch check did not run. This is not a complete local validation
pass. The orphaned Godot process from that timeout was terminated.

### Mobile coverage texture storage (r50, local only)

Android now stores the 256x256 coverage map in RG8 instead of RGBAF.
Desktop retains its floating-point map in a separate cache. A runtime check
verified both formats, cache reuse and image data sizes: 1,048,576 bytes for
desktop versus 131,072 bytes for mobile. This 87.5% reduction applies only to
this map's image data, not total game memory or measured GPU allocation.

Twelve local GLES renders compared floating-point and RG8 maps with identical
mobile shaders across meadow/road shoulder, crossing and road-end views.
All passed; the maximum RGB channel difference was 2/255 in each pair.
The road shoulder screenshot was visually inspected without obvious banding.
Evidence: `artifacts/android-cover-20260926-r50/comparison.json`,
`check-cover.log`, and the paired screenshots in that directory.
These isolated renders do not establish phone frame rate, full-scene visual
quality or thermal stability. This change has not been packaged, tested on
Android hardware or published; the frame-drop issue remains unresolved.

### Mobile distant ground normal sampling (r51, local only)

The shared mobile ground shader now fades relief over a world-space pixel
footprint of 0.15–0.4 metres. Beyond that fade it skips soil/gravel normal-map
reads, while retaining albedo and coverage sampling. Nearby relief is retained.
GPU branch cost and actual phone frame time still require device measurements.

Sixteen isolated GLES renders compare before/after meadow and road materials
at shoulder, crossing, end and grazing views. All eight comparisons have a
maximum RGB channel difference of 1/255. The road grazing and end images were
visually inspected; no obvious new seam or distant normal shimmer is apparent
in these stills. They do not test temporal stability or full-scene quality.
Evidence: `artifacts/android-normal-lod-20260926-r51/comparison.json` and
the adjacent paired screenshots and expanded shader snapshots.

Current-source gameplay checks also passed: navigation used 2,385 polygons,
entered/exited the building in 237/223 simulated ticks, and checked unreachable
roofs, route caching, target memory, supplies and zone behavior. Aim alignment
passed 108 cases across three weapons, lean, recoil and authoritative ray hits.
These runs used artifact copies of the existing tests with viewport 3D drawing
disabled, preserving physics and gameplay logic to avoid software-renderer
stalls. They establish logic/collision behavior, not rendered playability or
Android FPS. Logs and exact executed scripts are under
`artifacts/android-normal-lod-20260926-r51/logic/`.

No new APK was built or published for r51. The Android frame-drop issue remains
unresolved, and the overall realistic-visuals goal remains incomplete.

### Combined mobile ground changes (r53, Android device result)

The r50 coverage-map and r51 distant-normal changes were subsequently packaged
in candidate 0.52.44 (version code 20261036). Six native solo movement, firing
and camera cycles measured 31.0, 40.0, 44.1, 41.9, 42.9 and 39.4 FPS: mean
39.9 FPS, minimum rolling sample 31.0 FPS, worst interval p95 frame time
39.6 ms. All six recorded gameplay states remained live and alive. Screenshots
were excluded from measurement and the first rolling interval was discarded.

Against the published r46 mean of 39.3 FPS, this does not demonstrate a
meaningful improvement or stable 60 FPS. Gameplay smoke-test success must not
be interpreted as resolving frame drops. This candidate remains unpublished;
the frame-drop issue and overall visual-quality goal remain unresolved.

Evidence:
`artifacts/android-performance-20260926-r53/native-walkthrough-artifacts/Host_Machine_Files/$DEVICEFARM_LOG_DIR/gameplay-performance.json`.

### Ground diagnostics and adaptation policy (r54, local candidate)

The diagnostic now compares two ground-level views at 0.65, 0.55 and 0.45
render scale, plus ground/other/all custom-material substitutions. Production
diagnostics remain disabled. A graphical fixture completed all cases and
restored camera global transform, cull mask, render scale, material overrides,
layers and the diagnostic flag. This fixture is not a gameplay benchmark.

The previous resolution controller reduced scale only below 32 FPS, leaving
sustained 35–45 FPS views without adaptation. The candidate reduces scale below
48 FPS, retains the 0.45 floor, and increases it only after eight seconds above
55 FPS. The 48–55 FPS band avoids immediate reversals. This can reduce image
sharpness; it cannot fix CPU stalls and has not yet proved a device FPS gain.

Expanded regression checks reproduce the 40 FPS plateau, verify no change at
50 FPS, suspend adaptation during diagnostics, and exercise scale limits,
isolated hitches and recovery. The full mobile performance test passed under
Godot 4.4.1 OpenGL Compatibility with Xvfb/llvmpipe. A headless attempt passed
the adaptation assertions but failed the existing imported-MultiMesh assertion
and timed out; the graphical rerun passed that assertion as well.

Evidence: `artifacts/android-baseline-20260926-r54/restore.log` and
`artifacts/android-baseline-20260926-r54/adaptation-gl-test.log`.
Candidate 0.52.45 (version code 20261037) is now built and signed, but unpublished.
The initial import failed during render-thread finalization; resuming the same
snapshot completed import, bake, export and signing with exit code 0.
APK SHA-256:
`a69214b51b834bb5da03dbcdc8ec7abb0ed59c8255bc41ac7bf042542bb44bdd`.
The native Device Farm review completed PASSED under run
`707957c4-a737-46b0-a34c-4bc8452abb3b`; results were collected in
`artifacts/android-performance-20260926-r54/`.
The seven gameplay sample FPS values were 29.7, 41.7, 42.0, 42.2, 40.8,
34.7 and 36.0 (unweighted mean 38.2, lowest interval 29.7).
Their p95 frame times ranged from 34.6 to 46.9 ms. All seven recorded
gameplay states remained live and alive. The smoke-test pass does not
establish acceptable frame pacing or a performance improvement over r53.

Logcat confirms adaptation reached the 0.45 scale floor before all seven
measured intervals. Lower resolution alone did not resolve the slowdown.
The reviewed `04-look.png` still has visibly jagged foliage, roofs and
weapon edges; this is not sufficient evidence for the realistic visual goal.
Keep this candidate unpublished. Frame drops remain unresolved; investigate
scene submission, geometry and gameplay CPU costs before lowering resolution
further. These samples are interval measurements, not minimum individual
frame FPS, and one run is not a controlled statistical comparison.

### r54 script profiling and pending material changes

The separate profiled native run
`4c1f6338-7ca3-4602-b846-d17ca78fce2f` completed PASSED with the same
unpublished r54 APK. Its six sampled intervals were 32.5, 41.7, 41.8, 41.9,
40.9 and 37.7 FPS (unweighted mean 39.4); p95 frame times were 36.4–38.9 ms.
Evidence is the `gameplay-performance.json` under
`artifacts/android-profile-20260926-r54/native-walkthrough-artifacts/`.
The profiling flag was confirmed, and all six states remained live and alive.
This remains below the frame-rate goal.

Measured script process sections sum to roughly 1–1.4 ms per frame, excluding
engine rendering and other uninstrumented work. Bot input and simulation are
per-actor measurements, so their approximately 0.18–0.22 ms combined means
must not be mistaken for the total physics tick cost. These timings do not
prove a GPU bottleneck.

Two subsequent source changes are not in that APK:

- Mobile slope shading skips the three rock texture reads where rock weight
  is zero. Explicit gradients are evaluated before the varying branch.
- Mobile road shading skips pavement sampling where earth fully covers it,
  likewise preserving gradients and the existing material blend.

Isolated OpenGL/llvmpipe image comparisons at 960×600 passed: all four road
views were pixel-identical; one slope view was identical and the other two
differed in 155 and 13 pixels by at most one 8-bit channel value. Evidence:
`artifacts/android-road-sampling-20260926/comparison.json` and
`artifacts/android-slope-sampling-20260926/comparison.json`, alongside scripts,
before-shader snapshots, images and render logs. These fixtures establish
limited material equivalence, not whole-game visual acceptance or Android
performance benefit. Device testing is still required before publication.

The opt-in rendering diagnostic now additionally excludes ground geometry,
other geometry, and all mesh geometry in separate cases at scale 0.65. This
complements flat-material substitution: it can distinguish shader cost from
geometry submission and the remaining non-mesh workload. Render layers are
restored between cases and at exit; nodes and collision shapes are retained.
There are now ten cases per view, taking approximately 80 seconds across two
views, plus any rendering overhead. Production diagnostics remain disabled.

The graphical restoration regression passed under Xvfb/OpenGL with exit code
0 (`artifacts/android-baseline-20260926-r54/geometry-exclusion-test.log`).
It observed all three geometry exclusion combinations and verified restoration
of camera state, render scale, material overrides, mesh layers and the diagnostic
flag. This small desktop fixture does not establish Android frame-rate gains.

The r55 candidate (0.52.46, version code 20261038) now includes the road and
slope sampling changes. Its resumed build completed with exit code 0, signed
arm64-v8a and x86_64 output, and SHA-256
`0c332386f54f8617bf1c036114eb1596c63b41808391285580a0d10a7a15a650`.
Build provenance and logs are in `artifacts/android-performance-20260926-r55/`.
The first import failure is preserved separately; it was not counted as a
successful build. The post-build runner now accepts an already completed build
without requiring its former process to remain present.

Native Device Farm run `4fea56ce-881b-4638-8a43-e4605d2bba77` completed FAILED
on the same comparison pool; its runner collected the test output and artifacts.
The failure is `AssertionError: Player must remain alive in combat`: the sixth
sample records the player dead. This is not an APK upload or build failure.

The six intervals recorded 32.0, 43.0, 41.9, 42.1, 41.9 and 42.1 FPS, with
p95 frame times of 34.3–42.0 ms. The first five, alive intervals average
40.18 FPS (minimum 32.0); the final dead interval is not valid evidence of
combat performance. Evidence is `gameplay-performance.json` under the r55
`native-walkthrough-artifacts/` directory and `native-1-TESTSPEC_OUTPUT.txt`.
These results do not establish a meaningful improvement over r54 or resolution
of frame drops. The full gameplay validation did not pass, and r55 remains
unpublished. Further bottleneck measurement and a complete alive combat test
are still required.

### Opt-in rendering diagnostic validation

The Android startup now accepts `--render-baseline`; ordinary startup keeps
the existing rendering settings. `ANDROID_RENDER_BASELINE=1` selects the
static rendering runner in `tools/schedule_android_walkthrough.py`. It checks
20 ordered cases across two viewpoints and requires the completion marker,
valid frame measurements and a live application process. It is mutually
exclusive with the gameplay profiling option.

Local validation passed: three Python parser tests, GDScript syntax checking,
and the graphical `tests/mobile_baseline_restore_test.gd` fixture. The fixture
confirmed geometry exclusion and restoration of materials, layers, camera,
render scale and diagnostic state; it printed `ANDROID_BASELINE_COMPLETE`
and `MOBILE_BASELINE_RESTORE_PASS`.

The subsequent r56 APK (0.52.47, version code 20261039) completed the static
Android diagnostic. Evidence is `render-baseline.json` under
`artifacts/android-baseline-20260926-r56/native-walkthrough-artifacts/`.
At 0.65 render scale, the original scene measured 53.4 FPS at spawn and
44.7 FPS on the road (repeat: 53.4 and 44.8). Road rendering submitted 872
draws and 1,382,351 primitives. Reducing scale to 0.45 only increased road
performance to 46.5 FPS.

Replacing the ground shader with a flat diagnostic material reached 60.1 FPS
at spawn and 49.0 on the road. Excluding other scene geometry reached 60.0
and 60.1 respectively. These isolation cases implicate both ground shading
and other geometry costs; they are diagnostic interventions, not acceptable
visual changes or proof of a completed fix.

r56 passed the static diagnostic only; combat performance remains unverified.
Neither r55 nor r56 is published as a performance fix, and the frame-drop
issue remains unresolved. Desktop fixture frame rates are not evidence of
mobile gameplay performance.

### Structural steel batching candidate (not yet measured on Android)

The mobile batcher now permits the reviewed structural-steel shader on
primitive meshes. Arbitrary shaders remain excluded. Geometry with nonuniform
scale, shear or reflection retains its original transform rather than baking
it through Godot 4.4 SurfaceTool.append_from, which transforms normals using
the vertex basis. This avoids changing curved-surface highlights. Imported
mesh LODs and collision children continue to use their existing preservation
paths.

The graphical `tests/steel_batch_review.gd` fixture passed: four uniformly
scaled primitives merge while the nonuniform cylinders, excluded shader and
collision shapes remain. Images in `artifacts/steel-batch-safe-20260926/`
have a maximum RGB channel difference of 1/255. The existing graphical
`tests/mobile_performance_test.gd` regression also passed.

Full-world inventory in
`artifacts/mobile-world-steel-safe-inventory-20260926.json` records 609 steel
surfaces before batching and 39 after, with 34,036 vertices in both cases.
Total batched instances increased from 1,772 to 2,368 compared with
`artifacts/mobile-world-inventory-20260926.json`. This measures the
desktop-generated world under the mobile profile, not visible Android draw
calls or frame rate. The candidate still needs an APK build and real-device
static and live-combat validation before a performance release.

The candidate APK is now built as 0.52.48 (version code 20261040), SHA-256
`0f797deb4e1b3dac7d2314a9180962bca5dc115af8feb072518a452cc2f05fd2`.
The first import reported a render-thread shutdown error; its log is retained
as `artifacts/android-baseline-20260926-r57/import.log.attempt1`. Resuming
the same source snapshot completed import, terrain bake, export and signing
without weakening the error checks.

Static Device Farm run
`909aaf67-a863-4632-9831-5194eb88f184` is running; results are not yet known.
A detached follow-up in `artifacts/android-performance-20260926-r57/`
waits for this static review to pass, then tests the same signed APK and
existing app upload in combat mode. It stops on static review failure.
These runners do not publish an APK or push GitHub changes, and passing
the existing combat acceptance thresholds alone would not demonstrate that
the reported frame drops are resolved.

### r57 static results collected

Static run `909aaf67-a863-4632-9831-5194eb88f184` completed PASSED.
At the original 0.65 scale, spawn measured 53.3 FPS / 31.2 ms p95;
road measured 44.6 FPS / 33.6 ms p95. Draw calls fell from r56's
375 to 332 at spawn and 872 to 772 at road, but FPS did not improve
materially (r56: 53.4 and 44.7). Batching alone has not resolved the
reported frame drops. Raw results are in the r57 baseline artifact's
`render-baseline.json`.

The detached follow-up successfully scheduled combat run
`30bbdf2d-f534-4274-8165-3dd19146a13f`, which completed PASSED.
Its six native solo movement/fire/look cycles retained a live, alive player.
Excluding the first rolling interval, mean sampled FPS was 41.08,
with samples ranging from 37.5 to 43.1 and worst sampled p95 frame time
38.1 ms. Raw results are in
`artifacts/android-performance-20260926-r57/native-walkthrough-artifacts/Host_Machine_Files/$DEVICEFARM_LOG_DIR/gameplay-performance.json`.
Passing this acceptance gate does not establish smooth 60 FPS or resolve
the reported frame drops. r57 remains unpublished.

### r58 terrain LOD and Android review

Candidate 0.52.49 (version code 20261041), APK SHA256
`1076c06c2c468e61595a1485b09a170caa774129845fe222a54c293885438e7a`,
remains unpublished. Terrain LOD reduces the reviewed terrain draw geometry
from 210520 to 84352 triangles while retaining original collision geometry.
Local cached-Android-terrain aim/damage and service-yard traversal checks passed;
these are not evidence of mobile performance or multiplayer acceptance.

Device Farm static run `526cf63a-a538-4e4e-acf8-bc75658c666b` passed.
At render scale 0.65, spawn measured 54.0 FPS and road 45.1 FPS,
versus r57's 53.3 and 44.6 FPS. These small static improvements do not
resolve frame drops. Flat-ground diagnostic substitution reached 60.1 FPS
at spawn and 49.6 FPS on the road, indicating remaining ground-material
cost; road geometry also remains expensive. Flat materials are diagnostic only.

Combat run `ecac7475-1b97-4f6e-82ab-eddce6e3b980` completed FAILED:
`AssertionError: Player must remain alive in combat`. Only the first two
of six gameplay-state samples had a living player. FPS samples were
33.1, 41.6, 43.0, 46.2, 47.6, 48.2; later samples cannot establish a
combat performance improvement because the player had died. Do not report
their average as accepted combat FPS or claim r58 fixes the issue.
Raw evidence: `artifacts/android-performance-20260926-r58/native-walkthrough-artifacts/Host_Machine_Files/$DEVICEFARM_LOG_DIR/gameplay-performance.json`.

### r59 material-family diagnostic (completed; frame drops unresolved)

Added independent meadow, terrain, road and service material substitutions to
the static diagnostic. The 28-case desktop validation completed, including
restoration checks; parsed evidence is retained in
`artifacts/android-baseline-20260926-r59/local-diagnostic-validation.json`.
This validates the experiment, not Android frame rate.

Started a fresh 0.52.50 diagnostic build and subsequent Device Farm review
using a detached process (PID recorded in that directory's `process.json`).
The process was verified alive with parent PID 1 and its own session.
It has no boot startup and covers this build/review only, not indefinite
autonomous development. Results remain pending; no new APK has been published.

The first build attempt failed the strict import-log gate with Godot's
`finalize` render-thread error. Its logs are preserved in `attempt-1/`.
Before resuming the build, all 740 source-manifest files were verified;
the error gate was retained. Attempt 2 successfully imported, baked,
exported and signed version 0.52.50 (version code 20261042), APK SHA256
`904a1123a793312f15efae167201ffc762b1e48b04d660c85c4efdf98aab05e3`.
Device Farm run `7535351d-068a-4342-82a4-cef05d424765` is RUNNING as
of 2026-09-26 20:10 UTC, with results still pending. The detached runner
PID 1122840 was verified alive with PPID 1; it collects this review only.
This is an unpublished diagnostic APK, not a verified frame-drop fix.

The run subsequently completed PASSED and all 28 static cases were collected.
At the original 0.65 render scale, spawn measured 53.9 FPS / 31.7 ms p95
and road 45.1 FPS / 30.9 ms p95; repeat controls measured 53.8 and 45.0 FPS.
Flattening only the service material raised spawn to 60.1 FPS and road to
48.8 FPS without changing geometry or draw counts. Meadow, terrain and road
material substitutions individually produced little improvement. This identifies
service shading as the main ground-material target; the road also retains
substantial non-ground rendering cost (772 draw calls in the original case).
Flat substitution is diagnostic only and does not preserve the required visuals.
No combat acceptance was performed in this run, and no new APK was published.
Raw evidence:
`artifacts/android-baseline-20260926-r59/native-walkthrough-artifacts/Host_Machine_Files/$DEVICEFARM_LOG_DIR/render-baseline.json`.
The runner wrote `review-complete.txt`; this bounded review is complete,
not evidence of a continuing background development process.

### r60 service-material optimization (completed; frame drops unresolved)

Version 0.52.51 / code 20261043 replaces repeated segment square roots
with squared-distance comparisons and reuses the ground noise lattice for
service-access shading. Local access-material image comparison measured
mean absolute RGB error 0.387/255; it does not establish mobile performance.
Images, comparison data and a full-world service-shelter capture are retained
in `artifacts/service-material-review-20260926/`. Full-world capture passed;
combat performance and overall visual acceptance remain unverified.

The first import failed the strict log gate on Godot's render-thread finalize
error. Logs are preserved in `artifacts/android-baseline-20260926-r60/attempt-1/`.
All 740 manifest files were verified before resuming at 2026-09-26 21:02 UTC.
The detached runner is recorded in `process.json` and covers this build and
static Device Farm review only. Error checks remain enabled. Results are
pending; no optimized APK has been published and frame drops remain unresolved.

Duplicate extracted Linux/Windows files were removed only after matching
the retained ZIP contents by SHA256; the cleanup audit is retained in
`artifacts/duplicate-cleanup-20260926.json` (1,480,774,364 bytes reclaimed).

The resumed review completed and wrote `review-complete.txt`. At the original
0.65 render scale, spawn measured 54.8 FPS / 30.8 ms p95 and road measured
45.6 FPS / 32.4 ms p95. Repeat controls measured 54.9 and 45.5 FPS.
Compared with r59's 53.9 and 45.1 FPS, this is a small change, not evidence
that frame drops are fixed; road p95 also did not improve.
Road still requires 772 draw calls and 1,256,135 rendered primitives.
Reducing road render scale to 0.45 only reached 47.4 FPS. Hiding non-ground
geometry reached 60.1 FPS, identifying remaining geometry/render-submission
cost for investigation, not a visually acceptable optimization.
These are static rendering measurements only, not combat acceptance.
Version 0.52.51 remains unpublished.
Raw evidence:
`artifacts/android-baseline-20260926-r60/native-walkthrough-artifacts/Host_Machine_Files/$DEVICEFARM_LOG_DIR/render-baseline.json`.

### r61 drainage geometry batching (build and review in progress)

Version 0.52.52 / code 20261044 bakes 460 individual drainage gravel
meshes into two ArrayMesh batches. Vertex positions retain the seeded layout;
normals use the inverse transpose of each nonuniform fragment scale.
An earlier MultiMesh experiment changed the lighting and was rejected.
The current batches retain vertex colors and the existing mobile visibility range.

Isolated GL compatibility captures measured mean absolute channel error
0.03016/255 against the individual-mesh baseline. All 50 collision shapes
and other drainage transforms matched. Desktop scene inventory with mobile
policy reduced mesh candidates from 1846 to 1388; this is not Android
draw-call or FPS evidence. Artifacts are under
`artifacts/drainage-batch-20260926/`; `baked/` is the accepted local comparison,
while `after/` preserves the rejected MultiMesh experiment.

A detached build and static Device Farm comparison runner was started under
`artifacts/android-baseline-20260926-r61/`, with its PID recorded in
`process.json`. It was verified running with PPID 1 and its own session.
This covers this candidate only, has no boot startup, and does not establish
continuous autonomous development. Android results remain pending; the
candidate is unpublished and frame drops remain unresolved.

Regenerable import caches from completed r59/r60 reviews were removed to
provide build space, retaining their APKs, source and evidence. The audit is
`artifacts/import-cache-cleanup-20260926.json`.

The first r61 import hit Godot's render-thread `finalize` error and failed
the strict log gate. Logs are preserved in `attempt-1/`. All 740 source
manifest files matched the working tree before attempt 2 was started.
The resumed runner was verified alive with PPID 1; results remain pending.

The r61 runner subsequently completed with Device Farm result `PASSED`.
Version 0.52.52 remains unpublished. This run covers static rendering only,
not combat acceptance. At render scale 0.65, spawn measured 54.8 FPS
(332 draws); road measured 45.3 FPS (772 draws), with repeated road p95
frame time 33.1 ms. The corresponding r60 road result was 45.6 FPS.
The drainage batching produced no measured improvement in these views;
local node reduction must not be described as an Android FPS improvement.
Road scale 0.45 still measured only 47.3 FPS. Frame drops remain unresolved.
Raw results: `artifacts/android-baseline-20260926-r61/native-walkthrough-artifacts/Host_Machine_Files/$DEVICEFARM_LOG_DIR/render-baseline.json`.

### r62 and service ground trimming (2026-09-26)

r62 completed its static diagnostic, but combat performance remains unverified.
The unpublished 0.52.53 APK measured spawn 54.9 FPS (293 draws), road
45.6 FPS (687 draws) at scale 0.65. Repeated road p95 frame time was
32.8 ms. Road scale 0.45 still measured 47.6 FPS. Fir surface batching
reduced draws but did not establish a meaningful FPS improvement.
Frame drops remain unresolved; the published version remains 0.52.41.
Raw results: `artifacts/android-baseline-20260926-r62/native-walkthrough-artifacts/Host_Machine_Files/$DEVICEFARM_LOG_DIR/render-baseline.json`.

A subsequent, unpackaged change trims the repair yard grid outside conservative
bounds of the service shader's visible coverage. It preserves original vertex,
normal and UV arrays, generates normals before trimming, and leaves collision
unchanged. Yard triangles fall from 51,072 to 18,856 (63.1%).
The first implementation repacked mesh normals twice and failed exact normal
equality; using SurfaceTool raw arrays before a single mesh commit fixed this.
`tests/service_ground_trim_review.gd` passed under Godot 4.4.1 Compatibility
with identical attributes and zero changed image channels in the isolated
overhead comparison. The resulting screenshot was inspected.
Evidence: `artifacts/service-ground-trim-20260926/review.json`,
`original.png`, `trimmed.png`. This desktop check establishes preservation
of that view only; Android FPS and full-scene/combat acceptance remain pending.

The full-world rut traversal check subsequently passed with
`CAPTURE_ANDROID_TERRAIN=1`: all four crossings exceeded seven metres,
without recorded blocking colliders. Evidence:
`artifacts/service-ground-fullscene-20260926/service-yard-rut-traversal.json`.
This uses the cached Android terrain collision in desktop Godot and establishes
traversability only, not device frame rate.

The optional same-world mesh-swap comparison in
`tests/service_yard_review_capture.gd` had a Variant type inference parse
error; the node array now has an explicit type. Its first rendered comparison
at 960 pixels timed out after 120 seconds without a comparison report.
It is not a passing visual check.

### Ground trim full-scene verification (2026-09-27)

The native-viewport comparison subsequently completed successfully.
`artifacts/service-ground-fullscene-ab-native-20260926/service-shelter-trim-comparison.json`
records zero changed channels and zero mean absolute channel error between
original and trimmed meshes in the same full-world frame. The capture log
`artifacts/service-ground-fullscene-ab-native-20260926/capture.log` records first draw at 153,331 ms and
comparison completion at 414,205 ms, followed by `SERVICE_YARD_REVIEW_CAPTURE_PASS`.
Earlier short timeouts therefore did not establish a rendering failure.
This software-rendered desktop view verifies visual preservation, not Android
performance or combat acceptance.

### Ground trim Android result (r63, 2026-09-27)

Candidate 0.52.54 completed the 28-case static Device Farm render diagnostic.
Evidence: `artifacts/android-baseline-20260927-r63/candidate.log` and
`native-walkthrough-artifacts/Host_Machine_Files/$DEVICEFARM_LOG_DIR/render-baseline.json`
under that directory. Spawn measured 55.2 FPS (p95 30.1 ms), versus r62
54.9 FPS; road measured 45.7 FPS (p95 32.7 ms), versus r62 45.6 FPS.
Removing 32,216 rendered triangles did not materially improve frame rate.
Replacing only the service-ground shader with a flat diagnostic material
measured 60.1 FPS at spawn and 48.9 FPS at road. This identifies remaining
material cost, but does not establish a playable fix or combat acceptance.
The candidate has not replaced the public 0.52.41 download.

### Unpackaged material optimizations and visual checks (2026-09-27)

Service path segment vectors and inverse squared lengths now come from CPU
material setup. An isolated overhead comparison of both service shaders
recorded identical image bytes:
`artifacts/service-path-precompute-20260927/review.json`.

The access material also skips explicit-LOD noise samples for broom, aggregate,
and mineral detail when their existing screen-footprint fade reaches zero.
Four overhead scales and four perspective camera heights (0.3, 1.65, 4, and
12 metres) each recorded zero changed channels against the saved pre-change
shader. The standing-height perspective screenshot was inspected: the worn
entrance marking and mottled aggregate remain visible, with no new apparent
detail boundary in this view. Evidence:
`artifacts/service-access-detail-cull-20260927/review.json`,
`grazing-review.json`, and `service_access-grazing-1.65-after.png`.
These are isolated desktop material checks; they do not prove Android frame
rate gains, full-scene visual acceptance, or combat performance. Neither change
is included in r63 or the public download. Android performance remains unresolved.

### Material optimization Android result (r64, 2026-09-27)

Candidate 0.52.55 completed all 28 static Device Farm render diagnostic cases.
Evidence: `artifacts/android-baseline-20260927-r64/candidate.log`,
`review-complete.txt`, and
`native-walkthrough-artifacts/Host_Machine_Files/$DEVICEFARM_LOG_DIR/render-baseline.json`
under that directory. The material changes described above are included.

Spawn measured 55.1 FPS (p95 30.9 ms); road measured 45.5 FPS (p95 32.6 ms).
Repeated originals measured 54.9 and 45.5 FPS respectively. Compared with r63,
there is no material frame-rate improvement; the frame-drop issue remains open.
Reducing road render scale from 0.65 to 0.45 yielded only 47.5 FPS.
Replacing custom materials with flat shading yielded 52.2 FPS, while excluding
non-ground geometry yielded 60 FPS. These diagnostic exclusions change the
scene and are not playable fixes; they motivate investigating geometry and
draw overhead as well as material cost.

The test pass establishes diagnostic completion, not combat performance or
overall visual acceptance. This candidate has not replaced the public download.

### Geometry partition diagnostic (r65, 2026-09-27)

Added separate exclusions for non-ground MultiMeshInstance3D batches and
individual MeshInstance3D nodes. Together with the existing exclusions these
distinguish instanced vegetation/details from independent models while retaining
original materials in each measured partition. These are diagnostic cases only,
not changes to playable scene visibility. There are now 32 cases across two views.

The three Python parser tests pass. The Godot restoration test completed with
`MOBILE_BASELINE_RESTORE_PASS`; it checks partition visibility, retained ground,
materials, camera, render scale, layers, and the diagnostic flag.
Evidence: `artifacts/android-geometry-partition-20260927/restore-test.log`.
Its desktop synthetic-scene FPS is not Android performance evidence.

Candidate 0.52.56 (code 20261048) was started in
`artifacts/android-baseline-20260927-r65` with a detached build/review runner.
`runner.json` retains the process identity; `candidate.log` and the eventual
Device Farm run record are the status evidence. This bounded job can continue
after the interface disconnects on the current host; it is not a boot service
or an indefinitely running development agent. Android results remain pending,
and the public download is unchanged.

R65 build recovery (2026-09-27 01:35 UTC): first import terminated with Godot render-thread `finalize` error. Preserved its logs under `artifacts/android-baseline-20260927-r65/attempt-1/`; verified all 746 source manifest hashes against the working tree and resumed import/build with existing cache. Detached runner PID 1775324 was verified alive. Build and device results remain pending; this is not frame-drop acceptance.

R65 terminal result: Device Farm run
`7c1fdd4f-e2ae-449a-b086-d51d8b0fa4b0` completed **PASSED**.
APK SHA256: `a1903223cb3c4414702ef1e11144296f455959538d7a89e9866253acf48e2f04`.
Original spawn measured 55.1 FPS; road measured 45.7 FPS (p95 32.6 ms),
with road repeat 45.5 FPS. There is no material improvement over r64.
On the road, excluding non-ground instanced geometry yielded 53.3 FPS
(424 draws / 557,152 primitives), while excluding independent geometry yielded
50.9 FPS (375 draws / 795,377 primitives), compared with the original
687 draws / 1,223,919 primitives. Both partitions contribute substantial cost;
neither exclusion alone restores 60 FPS. These altered diagnostic views are
not playable fixes or combat acceptance. Raw evidence is retained in
`artifacts/android-baseline-20260927-r65/native-walkthrough-artifacts/Host_Machine_Files/$DEVICEFARM_LOG_DIR/render-baseline.json`.
The public APK remains unchanged. Completed build cache was removed with a
cleanup record; source, APK, and test evidence remain available.


## 2026-09-27 Android 路肩索引复用（未打包）

四条路肩存储顶点57600→10836，19200tri、完整顶点属性及碰撞面精确保留。Xvfb/OpenGL三对截图零像素差，测试exit0；证据 `artifacts/android-shoulder-indexing-20260927/REVIEW.md`。Android帧率收益未知，r81仍不达标，无新构建或云任务，公网仍0.52.41。

## 2026-09-27 r82诊断结束与草叶颜色运算优化

- r82 run 06b607d9-471d-462a-8944-45e51c80a339 已COMPLETED/FAILED；六移动窗口32.2/22.6/38.6/41.6/42.0/40.9FPS，p95 40.2/39.5/36.6/34.3/35.4/35.2ms。失败 `Gameplay below 24 FPS`，原始证据已下载到r82目录。不能将该候选视为掉帧已解决。
- 草叶 authored COLOR 与实例基础色/尖端色差的乘法移到顶点阶段，减少片元乘法和base_tint varying，保留完整几何/风/淡出。27组真实OpenGL截图中21组严格一致，其余总计8像素、最大通道差1/255；严格测试FAIL如实保留。详见 `artifacts/android-grass-color-20260927/REVIEW.md`。尚未打包，Android性能未知；公网仍0.52.41。


## 2026-09-27 14:28 UTC — r101 入口网格顶点缓存顺序
- 本轮具体修改：world_visuals.gd 的 RepairServiceAccess 在Android生成法线后 optimize_indices_for_cache；保留全部3185顶点属性、6144有向三角形及碰撞几何，只重排提交顺序。未裁剪场景、改变材质或开启ground bake。草丛检查后未做推测性shader改动。
- 新增 tests/android_access_index_cache.gd，执行实际生产网格构造，精确核对全部属性及有向三角形重数。LRU16/32模型miss由6272降至3888/3855（约38%）；仅局部复用模型，不能声称Android FPS提升。headless通过，Xvfb真实OpenGL/llvmpipe生产材质两视角像素差0，前景1619/9890像素。日志、PNG及范围说明在artifacts/android-baseline-20260927-r101/REVIEW.md；git diff --check通过。r101尚未打入APK。
- r100既有Device Farm run 5c1e9d4a-edba-4491-a4c1-ffe10558810f（项目a7d44e50-743e-403f-a4f5-e09236e85bca，us-west-2/account632930644527）仍RUNNING/PENDING；14:28检查PID1583365/start ticks4443571匹配。完整ARN在r100/native-walkthrough-run.json，状态device-review-status.json，检查device-review-process.log短尾；runner自动收集。禁止重复提交、上传或重建r100；其已签名APK及SHA见14:23检查点。
- 下一轮先接管r100真机移动诊断结果，与r95比较；若仍运行继续独立性能工作。r101可纳入后续累积候选，避免为小改动立即重复长构建。磁盘本轮起始约1.5GiB，无清理，全部既有修改和原始证据保留。
- 掉帧尚未解决，六轮>=300秒真实Android单机/联网逐帧呈现及视觉/功能验收未完成，无acceptance.json。公网仍0.52.41，未发布、未push、未改后台服务、未启动代理。状态continue。


### 2026-09-27T15:09:38+00:00 r108

压顶微孔噪声在现有过滤权重为零时跳过；14组 OpenGL 材质对比逐像素一致，证据 artifacts/android-baseline-20260927-r108/README.md。Android增益未测量。r106已结束FAILED：六个短诊断样本27.5–42.9FPS，最后周期玩家死亡触发断言，原始证据已收集；详见最新后台检查点，禁止重复提交或称为验收通过。


### 2026-09-27 16:10 UTC r118

r117 Pixel10/Android17正常场景静态诊断spawn52.4FPS、road45.2FPS/p95 32.9ms，仍未达标；PASSED仅诊断成功。原始证据 artifacts/android-baseline-20260927-r117/native-5-CUSTOMER_ARTIFACT.zip。本轮service_ground最近车道改为平方距离比较，三个OpenGL视角前后逐像素一致，尚未打包或证明Android收益；证据 artifacts/android-baseline-20260927-r118/README.md。最新候选0.52.83，公网0.52.41；详细接管状态见后台检查点。


r832：r828扫描复验终态PASSED仅代表执行成功。全部24项证据已保存；截图04存在准星右侧可辨识敌人，换弹成功，无命中和呈现帧时间证据。详见artifacts/android-baseline-20260930-r828/r832-combat-review.md。下一轮同.175无截图短时帧采样，再做有测量依据的性能修改；公网.132不变。


### r843：真实呈现短测与下一轮持续测试
- r839 COMPLETED/PASSED，Pixel10 Android17；原始证据在artifacts/android-baseline-20260930-r839/combat-evidence，run-status.json与r843-inventory.json记录回收。框架通过不等于验收。
- 1478个真实SurfaceFlinger呈现间隔，与1479个actualPresentTime时间戳差分逐项一致；25.050秒平均59.0017FPS、p95 16.7589ms、p99 33.3096ms、>50ms比例0.06766%、max66.6248ms。短测满足数值门槛，持续热机/联网仍未验证；分析artifacts/android-baseline-20260930-r843/short-combat-review.json。
- 22组战斗观察均存活，包含移动/转向/射击/换弹及受伤治疗。warmup-present-probe因预热边界中止而无效，不将其纳入正式25秒呈现结论。截图初审场景/控件可见，visual-note.md明确尚非完整视觉和功能验收。
- ListRuns确认无活动任务后，启动r843同一r757/.175 APK的30秒活动预热+300秒单机呈现测试。worker PID3959292/start_ticks11103866；恢复artifacts/android-baseline-20260930-r843/RECOVERY.md、worker.json、status.json及native-walkthrough-run.json（调度完成后写入）。先恢复现有任务，禁止重复提交。

### 2026-09-30T09:11:04.918972+00:00 — r848诊断 / r849恢复点
- r843 run `6f42838d-438d-4c04-a12b-8ef99bd0eb94` 已结束 FAILED：角色死亡，300秒对战未完成。原始日志、操作、截图与呈现时间保存在 `artifacts/android-baseline-20260930-r848/raw/`；结论见同目录 `review.json`。
- Google Pixel 10 Android17，中止前3083个真实呈现间隔、52.082秒：平均59.195FPS，p95 16.761ms，p99 33.312ms，>50ms比例0.03244%。`partial-frame-times.json` 仅为不完整诊断，可能含死亡切换，不能算验收通过。
- 修正 `tools/android_native_walkthrough.py` 操作路线：治疗期间允许根据真实墙接触向外脱困，并在同观测或10秒有效恢复窗口保留脱困方向；保留普通低位移防误判。录制状态回归及路线测试58项通过。未添加生产微优化，也未构建新APK。
- r849沿用r757未发布0.52.175，SHA256 `4c9419f889f119b99e98b4f4a1093707043d374a7ff53189d991d22d8158047f`；完整场景单机30秒活动预热+300秒多点触控对战已提交。run ARN `arn:aws:devicefarm:us-west-2:632930644527:run:a7d44e50-743e-403f-a4f5-e09236e85bca/b59e3082-afbc-4802-b94f-27786b7232d8`，本次查询状态 RUNNING / PENDING。调度PID3980114已成功返回，`artifacts/android-baseline-20260930-r849/status.json` 为scheduled；恢复方式见该目录 `RECOVERY.md` 和 `native-walkthrough-run.json`。下一轮先查询/收集此run，禁止重复提交仍在运行的任务。
- 磁盘仅约107MiB可用，禁止复制大APK/视频/ZIP；需内存选择性解压原始证据。公网仍0.52.132，本轮未发布。持续真机单机/联网各3轮及视觉功能验收未完成，保持continue。


## 2026-09-30 10:16 UTC — r880 已有候选实测追踪（continue）

- r879 Device Farm 在10:16:02 UTC复查仍 RUNNING/PENDING。run ARN：`arn:aws:devicefarm:us-west-2:632930644527:run:a7d44e50-743e-403f-a4f5-e09236e85bca/86dd6bfd-52a8-44d4-9860-78bc4eb177c2`。状态存 `artifacts/android-baseline-20260930-r880/r879-run-status.json`；恢复方法沿用 r879/RECOVERY.md。没有重复提交任务或构建。
- 对 r877 原始 SurfaceFlinger actualPresentTime 数组重查：>50ms 的三个呈现间隔为199.868125、316.626537、216.5025ms，分别距首帧2.182、12.842、18.138秒；逐项原始时间戳及首次收集poll已存 `artifacts/android-baseline-20260930-r880/r877-presentation-stall-review.json`。这是死亡中断的预热短测，非300秒验收；既有56.91FPS平均不能掩盖长帧。
- render_wall 192.947ms事件与呈现数据的时钟原点不同，不直接做时间相减或声称确定关联。本轮先完成已有证据诊断，没有据此叠加未实测生产优化。
- 根盘约34MiB可用。收集已完成任务须用 `tools/collect_android_zip_subset.py` HTTP range和磁盘预算，保留16MiB余量；禁止完整下载大ZIP。保留APK、源码和原始证据。
- 下一轮先GetRun；若完成，按r879恢复说明收集逐帧、路线、战斗/死亡和热机证据，判断30秒预热+300秒实际对战是否完成，再决定具体修复。仍运行则复用现有任务，不提交副本。
- 候选仍r757 0.52.175（未发布），公网0.52.132。尚未达到单机/联网各三轮验收，不能complete。未修改后台、基础设施、验收脚本/schema或发布下载。


## 2026-10-07 r979：已回收.176真实gfx追踪，约300ms停顿未解决
- r976 run 4fea7eaa-165f-4e58-a127-70b31e4fab6c已COMPLETED/FAILED，Pixel10 Android17，因角色死亡只完成1周期；r977收集PID289838已结束，原始raw-evidence.tar.gz已持久化，勿重复提交或收集。
- 真实呈现299.895756ms间隔对应引擎render_wall283.43ms/prepare.148ms；完整场景移动/转向/射击有记录，但不足热机/联网验收。trace无报告丢失/覆盖，目标窗口有效。
- 主线程gfx标记空白275.911ms；附近swap仅.258/.262ms，目标窗口GPU等待最长23.228ms。没有sched，不能断言CPU忙/驱动阻塞/根因；不能以降低画质为修复证据。详见 artifacts/android-baseline-20261007-r979/REVIEW.md、target-window.json 及四份派生分析JSON，已解析/哈希验证。
- 下一轮先按需查已有scheduler/simpleperf证据，针对标记空白选择能区分CPU工作与调度等待的采样；复用r975 .176 APK，无需新增候选。未改游戏参数、未新增云任务或发布；线上.132，候选.176未发布。根盘约31MiB，大文件继续tmpfs。六轮正式验收缺失，continue。

## 2026-10-07 r984：原生阶段采集器已通过桌面协议验证，Android待接入
- 证据：artifacts/android-baseline-20261007-r984/REVIEW.md、review.json。新增tools/capture_godot_visual_profile.gd，loopback远程visual profiler，保存真实引擎帧号及原始阶段累计时间（不是呈现间隔）。2117唯一帧，2112完整阶段；只验证协议，不作Android性能结论。
- release/debug官方libgodot_android.so保留阶段标记；Android运行开启仍待短测。下一轮优先将采集器接入已有Device Farm流程，ADB reverse并验证现有r975 APK启动参数，短测成功后关联r982 CPU长帧；不要重复无归因sched/gfx长任务。r980已FAILED，无新任务/构建。
- 根盘约228MiB；两个可重建官方Android模板迁/dev/shm并链接，SHA记录template-relocation.json；重启需恢复模板。未删APK或真机证据。
- .176候选未发布，公网.132；未改后台/验收器，未发布；完整验收仍未通过。continue。

## 2026-10-07 r1000 既有候选实战诊断完成回收，长帧尚未解决
- r995 run尾6b6f3692-811a-4987-b94a-39467a845da4已COMPLETED/FAILED；调度502349及收集502666均结束，勿重复提交/收集。Pixel 10 Android 17，候选r975 .176 SHA256 ae48d5f7b29a7fb698e29d28eb8bfcd3e5baaf2adae1d10509f4b63f50985945；未发布，公网记录.132。
- 已将原始归档持久化到artifacts/android-baseline-20261007-r995/raw-evidence.tar.gz（2838058字节），SHA256 21f774a023f638dda8524c946dd788d7521c2dc96b1f081789c20b60141305a5；121份manifest文件大小及SHA全通过，collection-status.json已记录持久路径。分析见同目录failure-review.json及native-late-window-review.json。
- 实际呈现短样本：预热1708间隔/28.982秒，58.932FPS、p95 16.795ms、p99 33.322ms；正式诊断仅278间隔/5.446秒，51.042FPS、最大832.804ms。约38秒死亡，仅抵达前两个路角，目标120秒未完成，二者均非验收。不得删除长帧后宣称通过。
- native帧8691 totalCPU803.435ms，其中Render Opaque Pass→Render Sky相邻CPU边界间隔797.492ms；实际呈现833ms停顿与该native帧尚未精确对齐，不能直接断言着色器编译、死亡切换或某函数独占耗时。启动加载长帧另计，GPU值不可信。
- 本轮优先完成现有候选实测分析，无游戏代码修改、新APK或性能修复结论。下一轮针对上述渲染边界/驱动等待排查事件时间和可验证修复；路线标签safe_corners不能证明有实际掩体，治疗延后仍未解决存活限制，勿继续盲堆微优化或重复提交相同失败诊断。
- 根盘余约5MB，未删除源码/APK/原始证据/历史快照；未找到可安全释放的大型项目构建缓存。后续写入/构建前先核查空间和硬链接，保持原始证据。单机/真实Android联网各3×300秒、视觉和功能验收尚未完成，continue。


### 2026-10-08T02:33:08.986341+00:00 r1008 shader attribution (diagnostic only)
Recovered existing run and full raw archive; see `artifacts/android-baseline-20261008-r1008/diagnosis.json` and latest background checkpoint. Synchronous compile_specialization scopes occupy263.963/282.881ms and177.701/195.606ms of two gameplay render stalls. Bounded clock alignment shows possible overlap with actual299.943/199.867ms presentation gaps. Shader/material identity is still missing; next instrument identities then warm only missed variants. Short capture aborted on death:54.205592FPS,p95 17.177813ms,p99 33.406823ms,max516.441484ms,976intervals/18.005522s including death. This modified-engine diagnostic is not acceptance. All r1008 workers finished; no resubmission needed. Production .177 and public .132 preserved; no performance completion claimed.


## 2026-10-08T02:55:09.405666+00:00 — r1011 normal .178 packaged; physical short measurement in progress (continue)
- r1001–r1009 completed/recovered; do NOT resubmit. This is the normal-engine physical measurement of r1010 shared tracer resources and actual-tracer combat prewarm, with full scene retained. No further speculative graphics change. Six300s solo/online acceptance remains outstanding.
- Signed installable candidate: artifacts/android-baseline-20261008-r1011/build/IronMeridian-Android-0.52.178-20261008.apk; SHA256 d5ffa472cdcfb4e7bb37ba5b6df7ad2a752e658931ae623fa353580c5b90c79f;272444633bytes;code20261170;arm64-v8a+x86_64. Normal Godot export template, not diagnostic shader/swappy engine. build/build.json and build-result.json show success at02:53:59UTC; package workflow verifies manifest/signature. Actual installation awaits Device Farm.
- First build import returned0 but logged render-thread-finalize error; preserved attempt-1 logs/state. ADB daemon was started, then SAME source snapshot resumed with ANDROID_RESUME_BUILD=1. Do not assert ADB caused failure. Resume PID26035 finished0; no active build. Local tracer/warmup correctness results remain r1010/test-results.json (isolated warmup rerun PASS; initial Xvfb failure retained). Scoped git diff --check PASS. These tests are not Android performance evidence.
- Launched one scheduler PID27968/start_ticks651075 and collector PID27969/start_ticks651075 at02:54:31UTC. launch.json preserves identity. Last worker state uploading; active_runs_before_schedule=[]; APK upload ARN arn:aws:devicefarm:us-west-2:632930644527:upload:a7d44e50-743e-403f-a4f5-e09236e85bca/ca630b9c-8471-4166-bd85-777b366242ee. DO NOT restart scheduler: inspect worker-state.json and native-walkthrough-run.json for resulting run ARN first; reconcile saved upload if interrupted.
- Existing normal workflow: multitouch/building route, gameplay profiling30s/joint system trace, full scene, no render-baseline or hide-object probe. This short run is NOT acceptance. Prior route can end on player death; preserve any aborted evidence honestly. Collector waits run creation, polls status20s, saves run-status.json/collection-status.json, recovered-evidence files + SHA inventories and raw-evidence.tar.gz, without /dev/shm. If collector exits after polling timeout, resume collector only against saved run.
- Next: recover this run and raw presentation intervals, compare firing stalls against normal .177 (~299.8ms maximum) and inspect gameplay completion. Any improvement needs measured evidence; no claim of solved stutter. Then address remaining shader stalls/route survival as evidence warrants and complete required long solo/online, visual and functional reviews. No acceptance manifest yet. Public .132 unchanged; .178 unpublished. No push, infrastructure/service/validator/schema changes.

- r1011 handoff update: saved Device Farm run arn:aws:devicefarm:us-west-2:632930644527:run:a7d44e50-743e-403f-a4f5-e09236e85bca/6735d8f8-f546-4935-9325-c5ac7dcd1d95; do not resubmit. Read run-status.json and collection-status.json for current progress.


### 2026-10-08 r1021 targeted .179 shader timing diagnosis
Signed diagnostic with verified unchanged .179 payload scheduled once; run arn:aws:devicefarm:us-west-2:632930644527:run:a7d44e50-743e-403f-a4f5-e09236e85bca/e5a97e6b-9692-4eb2-8a38-8974a7444920. Evidence/recovery: artifacts/android-baseline-20261008-r1021/review.md and launch.json. Collector45539/start_ticks1160117 alive. Instrumented APK cannot satisfy acceptance; remaining ordinary-client stalls and six300s acceptance rounds unresolved.


### 2026-10-08 r1090：正常 .186 复测证据恢复
- r1089真机run已COMPLETED/FAILED，热机第16操作周期玩家死亡，未达到测试时长；不能当性能验收。原采集HTTP503后正在增量恢复同run，不重提。恢复及自动分析的PID/路径见ANDROID_BACKGROUND_CHECKPOINT.md最新r1090。
- 已恢复正常引擎日志仍有313.435ms和260.066ms render_wall停顿（后者为死亡观战）；记录artifacts/android-analysis-20261008-r1090/partial-render-observations.json。这是引擎渲染耗时，尚不是呈现间隔结论；待原始SurfaceFlinger与系统trace完整恢复后自动计算对齐。现有木纹/孔板预热尚未证明解决掉帧。
- APK仍为未发布.186；没有追加猜测性画质改动，六轮持续验收及视觉/功能回归未完成，continue。

## 2026-10-08 r1092：存活长帧驱动标记范围收敛（continue）
- 直接复用r1089已完整恢复的原始trace；无新Device Farm任务、构建或后台worker。正常候选仍r1088 .186，SHA aa4b340789577549ae6d4c1f4615c6a0f580dce3d9cdc08618dc1071daa07bc0，未发布。此前55.695FPS短诊断仍未达标，不能宣布解决。
- 新增tools/android_gfx_stall_summary.py及tests/test_android_gfx_stall_summary.py：按精确tid/tgid提取窗口，跨CPU时间排序，配对同步scope并输出标记间隙；边界缺失不伪造scope。3项单元测试通过，真实压缩trace解析完成。不是验收脚本，不修改验收schema。
- artifacts/android-analysis-20261008-r1092/analysis-summary.json保存原始trace SHA、结论和下一步；alive-gfx-scopes.json为可重算报告，alive-stall-thread-markers.txt为窗口摘录。tid25393/tgid25354、6291.70..6292.10共334标记，未配对end=0、末尾open=0。
- 最大标记间隙6291.740148..6292.050272为310.124ms，从E到TAKick:71159，已记录open_scopes为空。完整dequeueBuffer最大5.034ms、waitForBufferRelease最大5.026ms，无法解释该长间隙。结合r1091的GL线程running308.506ms仍只定位到未标记的CPU执行窗口；不等于shader编译证据，也不能排除驱动自旋或GPU依赖。
- 本轮是诊断工具与证据收敛，未修改游戏性能源码，不把分析进展当修复。下轮按需检查既有native-visual-profile.jsonl及tools/android_visual_profile_review.py的边界时序，确认正常模板可用profiling点，再做针对性修改；诊断路线第16周期死亡仍待解决，不改伤害/隐藏场景。
- 六轮>=300秒、视觉和完整功能回归均未完成，无通过acceptance manifest。无push、发布、服务/基础设施更改或开发代理，continue。只读本检查点尾部，禁止完整加载历史。


## 2026-10-08 r1093：原生剖析定位不透明渲染长区间（continue）
- 复用r1089完整原始证据，无新Device Farm任务、构建或worker。r1001及其后恢复工作不重复提交。候选仍r1088正常引擎.186，未发布；公网.132不变。
- artifacts/android-analysis-20261008-r1093/analysis-summary.json记录原始native-visual-profile.jsonl SHA和精确边界；late-native-boundaries.json限定8317..8349，native-boundaries.json为全部帧（含启动，不能混作对战统计）。frame8318 Render Opaque Pass 2.409ms到Render Sky 311.688ms，区间309.279ms，总313.406ms；frame8349对应3.100到256.035ms，区间252.935ms，总260.035ms。邻帧8317/8319同区间仅1.742/2.551ms。
- 两个总时长接近此前render回调313.435/260.066ms，但不是已确认的相同frame ID；接收时间含传输延迟。这是CPU剖析边界差值，不是呈现间隔，也不唯一证明具体材质、shader编译或驱动/GPU根因。
- client/scripts/mobile_performance.gd长帧快照增加begin_ticks_usec（保留原回调时间）、engine_frames_drawn和engine_process_frames，供后续关联；不是性能修复，尚未打包。tests/mobile_render_stall_test.gd新增字段快照检查。两项headless回归mobile_render_stall_test/render_stall_state_rules、限定区间剖析及git diff --check通过，validation.json保存结果；合成测试不是性能证据。
- 下轮直接读r1093 analysis-summary.json；按Godot GLES3实现检查Opaque到Sky边界内操作，选择针对性诊断/修复，不继续盲目预热材质。同时需改善现有路线存活（不改伤害或隐藏场景）才能完成持续测量。现有真实呈现55.695FPS/max333.060ms、约32秒，仍未解决；六轮>=300秒及视觉/完整功能回归待完成，无通过manifest。
- 未push、发布、修改服务/基础设施/验收脚本或启动代理。无新增待恢复任务；仅按需读检查点尾部，continue。


## 2026-10-08 r1119 — .188正常包真机证据已恢复；提前死亡，不能验收（continue）

- r1118 run77b31aba-ff71-4326-a259-721d90558359已COMPLETED/FAILED，采集完成，71文件SHA校验无误；调度和采集进程均完成，无待恢复任务，不重复提交。原始归档artifacts/android-baseline-20261008-r1118/raw-evidence.tar.gz（23414164字节）。
- Pixel 10 / Android 17正常.188包1008真实呈现间隔、16.956秒：59.446FPS、p95 16.765ms、p99 17.328ms、max50.009ms、>50ms比例0.0992%。角色约17秒死亡，60秒probe valid=false；短测不能证明预热修复或满足300秒验收。
- 长帧附近120ms窗口GLThread运行91.157ms、可运行19.280ms、睡眠9.563ms；GPU辅助线程24.569ms等待不是GPU执行计时，也不是主线程阻塞证据。trace/scheduler/slice及路线分析见artifacts/android-analysis-20261008-r1119/review.md、handoff.json；没有据此推测性修改画质。
- 路线cycle5治疗被伤害打断，医疗数量仍2；cycle6装弹期间在(-36.912,49.285)降至4.731血，cycle7死亡。失败截图是观战视角，不能用于证明死亡玩家所在掩体。旧外侧路线未证明安全，下一轮先核对首次工坊接近过程的伤害/敌人观测及实际掩体几何，验证具体触屏路径修正；不降低敌人伤害、不隐藏场景、不重复盲跑相同路线。
- 可安装正常候选沿用r1117/build/IronMeridian-Android-0.52.188-20261008.apk，SHA256 824041022c4b7fc37fa0badeb6d8ca14e8de7e793415d99e2b5f9593b033ab7e；本轮未重建/发布。公网.132不变。6轮300秒热机单机/联网、视觉及触屏/陀螺仪/命中/登录回归仍缺，无验收通过声明；未修改后台服务/基础设施/验收脚本/schema，未push或启动代理。

## r1138 — 2026-10-08T13:22:32.809797+00:00 Android grenade-evasion diagnostic
- r1135 completed FAILED and recovered by r1137; do not resubmit/recollect it. 21.469s warmup presentation sample is NOT acceptance (death from grenade). Raw and audit: artifacts/android-baseline-20261008-r1135/raw-evidence.tar.gz; artifacts/android-analysis-20261008-r1137/review.md.
- Updated tools/android_multitouch.py and tools/android_native_walkthrough.py: building-route grenade warning temporarily suppresses aim/fire so normal sprint can escape; bound movement to 250–750ms by remaining corner distance, preserve post-touch camera observation and restore combat when warning clears. Movement planning uses the same input duration. Gameplay/client damage, scene and APK unchanged. This is diagnostic control improvement, not proof of performance fix.
- Tests: test_android_multitouch.py 23 passed; test_android_walkthrough_timing.py 100 passed; py_compile passed. Includes warning-clear integration and distance/input-budget checks.
- New recoverable r1138 diagnostic directory: artifacts/android-baseline-20261008-r1138. Reuses signed .188 code20261180 SHA256 824041022c4b7fc37fa0badeb6d8ca14e8de7e793415d99e2b5f9593b033ab7e; existing upload. Worker checked zero active runs before scheduling. 30s active warmup +300s full-scene combat, no trace/video; diagnostic only.
- Workers: schedule PID148896/startticks4417743; collect PID148897/startticks4417743, details launch.json. Latest state=scheduling; run=pending: consult native-walkthrough-run.json. Persisted workers use start_new_session and collector polls/saves run-status.json then collected archive. Do not duplicate schedule.
- Next: read worker-state.json, native-walkthrough-run.json, run-status.json, collection-status.json in r1138; verify /proc PID start ticks before any recovery. If schedule is ambiguous, reconcile Device Farm list_runs first. When collected, review warning evasion, corner path, death/heat/full300s actual SurfaceFlinger presentation data before further client changes. No acceptance manifest generated; all six required solo/online rounds and functional/visual reviews remain. Public .132 unchanged, no publishing.
