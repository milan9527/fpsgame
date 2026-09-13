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
Committed checkpoint 0f2b9d5: stages 12–14 character, yards and terrain.
Stage 14 adds slope-blended scanned rock/soil on decorative mountains:
client/shaders/terrain_slopes.gdshader, world_visuals terrain material cache,
world.gd material assignment, terrain_rock maps and fetch_terrain_material.py.
Forward+ capture passed: artifacts/realism14-forward/gameplay.png.
Compatibility verification and review recorded in docs/VISUAL_REVIEW.md.
No collision geometry changed in stage 14. Content ash-valley-19, protocol17.
Stage13 tests rejected old18 peers/checkpoints and preserved old save files.
276 collision shapes in artifacts/realism13-world/collision.json match stage11.
Full historical changes/evidence are in docs/VISUAL_REVIEW.md; read selectively.

## Next substantive work
Improve architectural silhouettes and natural layout, dense ground vegetation,
and realistic equipment. Current screenshot still falls well below reference.
Stage14 Compatibility capture passed; license and review updated.
Current desktop packages: artifacts/visual-preview/0f2b9d5f721b/, stages6–14,
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
