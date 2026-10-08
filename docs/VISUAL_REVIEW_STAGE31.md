# Stage31 — grass colonies and ground texture scale

Compared the downward camera in
`artifacts/realism29-preview/capture/grass-close.png` with
`artifacts/realism31-close/grass-close.png`.

The foreground now includes exposed soil between dense colonies instead of
near-uniform tufts. Broad density noise is interrupted by smaller patches;
independent dry/green color variation and varied height/width break up the
repeated silhouette. Roots darken gradually toward the soil. The same imported
grass mesh is still reused, so close colonies retain recognizable repeated
leaf shapes.

The playable ground texture now repeats every approximately two metres instead
of six; small stones read more clearly at the player camera height. This does
not add geometric stones or remove the sharp polygon boundary with asphalt.
The soil still has broad muddy color patches. That boundary needs a separate
irregular gravel/dirt transition pass.

Source Forward+ check: `artifacts/realism31-grass.log` reports 385 grass cells,
124,056 grounded tufts, roads and hardscape clear. The extended check also
requires actual rendered instance height and color variation, preventing
uniform instances or missing shader data from silently passing.

The overall realism objective remains open: weapon receiver and forearm
materials look flat, buildings repeat, skyline trees remain thin billboards,
and characters and lighting need more views. Stage29 aiming and roof checks
are prior evidence only. Networking remains unresolved after the previously
observed local `/auth/login` HTTP404; it was not retested in this stage.

Preview and packaged validation are recorded in
`artifacts/realism31-preview/verification.json`. Screenshots use Forward+
llvmpipe and do not establish physical-GPU performance.

Packaged screenshots `capture/grass-close.png` and `capture/gameplay.png` were
visually reviewed: the grass colonies and finer ground stones survive export;
rounded stage30 ridges remain intact. The gameplay view still shows flat
weapon/arm shading, repeated boxlike buildings and a sharp asphalt boundary.
The executable ran outside the source directory with isolated user data.
`offline.log` passes 16 actors, reload, healing, damage, victory, raycast, cover,
fire interval and rig checks. `grass.log` passes grounding/exclusions and
instance height 0.186–2.222 with dry/green data spanning 0–1.
`capture.log` reports `VISUAL_GAMEPLAY_CAPTURE_PASS`.
Run `artifacts/realism31-preview/Linux/IronMeridian` with its adjacent PCK
for the current local preview.
