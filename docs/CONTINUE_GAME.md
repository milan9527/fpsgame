# Game development handoff

Updated 2026-09-13. Repo: /home/ec2-user/project/fpsgame, branch feature/vehicles.

## Active goal
Improve the Godot + Blender shooter toward realistic visuals in the direction of
Peace Elite: characters, weapons/arms, architecture, terrain, vegetation, lighting.
Inspect gameplay screenshots, verify offline gameplay and aiming/collision, and
provide current runnable local previews. The goal is NOT complete. Work
autonomously; NEVER push GitHub without confirmation. No AWS changes needed.

## Current checkpoint
Stages 6–8 are ready for a local checkpoint; see docs/VISUAL_REVIEW.md.
- Detailed shotgun/marksman geometry and wide smooth scope bore. Initial scope
  support/turret intrusion was fixed. Final dedicated optic capture passed in
  Compatibility and Forward+ (artifacts/realism8-optic*/).
- Full six-view Compatibility capture timed out at 180 seconds; its partial
  outputs are not a pass. The dedicated optic test settles animations numerically
  before rendering a few frames. It verifies images, not gameplay correctness.
- Background groves follow decorative mountain heights via a shared function.
- Blender gable/shed roofs with matching convex collisions on 8 buildings.
- Roof ray tests pass: three slope positions each, blocked shots, clear doors.
- Collision snapshot artifacts/realism8-review/collision.json: original 268
  entries unchanged plus 8 roof hulls. Convex snapshots record vertices.
- Offline smoke passed after roof changes: artifacts/realism8-smoke.log.
- Aim alignment passed 108 samples before the final support/turret adjustment;
  anchors were not changed. Model rules passed before roof changes.
- Actual scene screenshots: artifacts/realism8-review/ (Compatibility).
  Optic screenshots: artifacts/realism8-optic-forward/ and realism8-optic/.

## Next work
1. Inspect current status/logs; no capture is expected to remain running.
2. Continue substantial visual work: flat repetitive compound, sparse tree crowns,
   simple wall/roof finish and uniform layout still fall well below the requested
   overall quality. Do not equate more small details or green tests with success.
3. Improve material consistency and architectural variety; preserve server/client
   collision consistency. World.gd is shared by dedicated and offline modes.
4. Current local previews are in artifacts/visual-preview/b3fdf590901d/:
   Windows and Linux ZIPs include stages 6–8. verification.json records archive
   hashes, exports and packaged Linux offline/roof test passes. Launch the EXE
   or Linux executable directly after extraction; no play.sh/Godot install.
   Top-level older ZIPs remain stage 3: use the commit-specific directory.
   These previews default to localhost/offline. Windows export was not tested
   on Windows hardware. Do not deploy or publish as part of this graphics work.
   Rebuild using python3 tools/package_visual_preview.py from a clean commit.
   It copies official Godot notices retained in artifacts/visual-preview/.

## Environment and context
Godot tools/godot 4.4.1; Blender tools/blender-4.3.2-linux-x64/blender 4.3.2.
EC2 uses Mesa llvmpipe software rendering, no physical GPU. Forward+ commands use
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.x86_64.json LP_NUM_THREADS=8
with xvfb-run. Compatibility: --rendering-method gl_compatibility.
Avoid anisotropic triplanar textures (driver stall); planar anisotropic works.
Read small relevant log tails and only necessary images. For input-too-long,
Codex CLI /compact summarizes history. If unavailable, start a new chat in this
repo, request continuation from this file and explicitly restore the original
goal. Do not paste full conversation or delete history/secrets. A handoff file
itself does not change the context limit.
