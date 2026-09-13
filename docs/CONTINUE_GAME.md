# Game handoff
Updated 2026-09-13; /home/ec2-user/project/fpsgame; feature/vehicles.

## Active goal
Autonomously improve Godot+Blender shooter realism toward Peace Elite: characters,
weapons/arms, buildings, terrain/vegetation/light. Inspect actual game images,
verify offline play and aiming/collision, provide runnable local previews.
NOT complete: environment/layout and characters remain visibly below reference.
NEVER push without confirmation. No AWS changes or publishing needed.
Do not claim execution survives UI exit. Keep tool outputs/images selective.

## Current source and evidence
Source checkpoint3406be7: stages17 side-wall frames/louvers/steel and18 roof covers,
plaster ends/flashing/gutters. Blender generators tools/build_facades.py and
build_roofs.py; corresponding .blend and .glb committed. Material scans CC0.
Main image artifacts/realism18-forward/gameplay.png; roof closeups realism18-roofs/.
Forward+ and Compatibility captures passed. Roof tests8 slopes/shots/doorways pass.
Stage17 collision snapshot matches all276 shapes from stage13. Content19 unchanged.
Stage17 model UV/bounds checked; see docs/VISUAL_REVIEW.md for detailed evidence.
Current Windows/Linux previews artifacts/visual-preview/3406be77d44d/ include18.
verification.json: exports, packaged Linux offline/roof checks, ZIP hashes.
Packaged Forward+ actual game capture also passed from /tmp; image capture/gameplay.png.
Windows exported, not Windows-hardware tested. No live deployment changed.
Content19 cannot join old18 servers/checkpoints; old saves remain intact.

## Next substantial work
Address near/distant tree crown mismatch, empty repetitive layout and ground
material layers. Avoid substituting endless small trims for overall realism.
Near fir is variantC (~505494 triangles) with thin crown; distant grove uses fullerB.
B source artifacts/realism-sources/tree-b/tree.gltf; packed authoring Blend is
background_fir.blend there. Source primitives: bark9582,trunk78776,twig2207296,
deadbranches4970 triangles. This is authoring input, too heavy to ship unchanged.
Investigate a lower-cost fuller crown and matching LODs, inspect actual renders.
tools/build_tree_impostor.py currently exports C near model unless FIR_VARIANT=B;
B branch only renders background billboard. Do not overwrite source/high-res Blend.
Keep collision trunk unchanged unless intentionally updating shared gameplay world.

## Environment
Godot tools/godot4.4.1; Blender tools/blender-4.3.2-linux-x64/blender4.3.2.
Software llvmpipe, no physical GPU. LP_NUM_THREADS=8; Forward+ uses
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.x86_64.json and xvfb-run.
CAPTURE_ARTIFACT_DIR=<absolute> tools/godot --path client --audio-driver Dummy
--script ../tests/visual_gameplay_capture.gd. CAPTURE_INTERIOR=1 for indoors.
Add --rendering-method gl_compatibility for Compatibility. Use --headless for rules.
Avoid anisotropic triplanar sampling (driver stall); planar anisotropic is fine.
Enable mipmaps on new textures. Headless MultiMesh transform readback is invalid;
use graphics for placement diagnostics. Preserve shader UIDs/import metadata.
Package clean source with python3 tools/package_visual_preview.py; no publishing.
CLI /compact can summarize chat; this file itself cannot change context limits.
