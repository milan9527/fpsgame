# Current game handoff
Updated 2026-09-13. Repo /home/ec2-user/project/fpsgame; branch feature/vehicles.

## Goal and constraints
Continue realistic Godot + Blender visuals toward Peace Elite: characters,
weapons/arms, architecture, terrain/vegetation and lighting. Inspect actual game
images, verify offline play and aiming/collision, provide current local previews.
Goal NOT complete: architecture/layout remain repetitive and character/equipment
still visibly procedural. Work autonomously. NEVER push without confirmation.
No AWS changes or publication needed. Do not claim UI-independent execution.

## Current work
Stage18 adds split roof cover/plaster ends/flashing and gutters with metre UVs.
Images artifacts/realism18-roofs/ and realism18-forward/gameplay.png.
Roof collision tests8 roofs passed; Forward+/Compatibility rendering passed.
Stage17: Blender side-wall assemblies (concrete frames, closed louvers,
folded steel infill). tools/build_facades.py; facade_0/1/2.glb and art/*.blend.
Final main image artifacts/realism17-final/gameplay.png; final style1 material
close-up realism17-steel/facade_1.png; style0/2 realism17-facades-final/.
Models9144/2448/9144 triangles; UV/bounds checks passed. Initial flat backlit
panels fixed with scan UVs, wider louver gaps and disabling louver auto LOD.
276 world collisions match stage13; offline smoke passed. Content19 unchanged.
Stage16 grass remains:169031 tufts,388 cells; shrinks24–48m,culls58m.
Current packages below predate stages17–18 until refreshed. Goal remains unfinished.
Full historical changes/evidence are in docs/VISUAL_REVIEW.md; read selectively.

## Next substantive work
Improve architectural silhouettes/fronts/roofs and natural layout,
and realistic equipment. Current screenshot still falls well below reference.
Current packages include stages15–16; packaged Linux render also passed.
Current desktop packages: artifacts/visual-preview/8de4240141a5/, stages6–16,
content19. verification.json records both exports, packaged Linux offline/roof
checks and archive hashes. Rebuild via python3 tools/package_visual_preview.py
from a clean commit. Previous 9648cb40b560 packages are obsolete content18.
Linux packaged offline/roof checks passed; Windows exported, not hardware-tested.
New source19 cannot join old18 servers. Stage14 aim checks passed 108 samples. No live deployment has been changed.

## Tools and validation
Godot tools/godot 4.4.1; Blender tools/blender-4.3.2-linux-x64/blender 4.3.2.
Software llvmpipe, no physical GPU. Use LP_NUM_THREADS=8 and
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.x86_64.json with xvfb-run.
CAPTURE_ARTIFACT_DIR=<absolute> tools/godot --path client --audio-driver Dummy
--script ../tests/visual_gameplay_capture.gd captures actual offline game.
Add --rendering-method gl_compatibility for Compatibility; CAPTURE_INTERIOR=1
for indoors. Headless tests use --headless --path client --script ../tests/NAME.gd.
Do not use anisotropic triplanar filtering (software driver stalls).
Enable mipmaps for new script-loaded 3D textures. Preserve genuine shader imports.

## Context recovery
Keep tool outputs short and images selective; do not reload full history.
Codex CLI /compact summarizes history. A fresh chat can read this file and
explicitly restore the goal if compaction is unavailable. This file alone does
not alter service input limits. Never delete private session history or secrets.
