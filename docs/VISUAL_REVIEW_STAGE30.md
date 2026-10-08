# Stage30 — rounded distant ridges

Compared `artifacts/realism29-forward/gameplay.png` with
`artifacts/realism30-forward/gameplay.png`, captured at the same player position,
yaw and pitch using Forward+ on llvmpipe.

The prominent left peak now has a broader, rounded crest instead of a pointed
cone. The rear crest is lower and less isolated; the skyline reads more as a
continuous range. Ridge radii and placements remain unchanged. Height changes
also redistribute background trees according to the existing slope rejection.

This addresses one visible defect, not the overall realism goal. Hills still
have smooth, pale surfaces; tree billboards repeat and look thin along the
skyline. Foreground grass spacing and silhouettes repeat, soil is blurred, the
buildings lack variety, and the gun and arms still look flat. Next prioritize
ground texture scale and vegetation variation, then weapon/arm material and
shape work. Character and lighting quality still need broader scene review.

Validation:

- `artifacts/realism30-ridges.log`: all 18 rendered ridge meshes sampled;
  2,566 tree anchors agree with rendered triangles within 0.000005 m and
  remain outside the playable square. Compatibility driver V-Sync warning only.
- `artifacts/realism30-terrain.log`: 100 seeds / 600 zone centers pass actual
  collision, navigation connectivity, deterministic fallback and bot rotation.
- Stage29 aiming and roof checks remain prior evidence, not new stage30 passes.
  Networking remains unverified after the prior local auth HTTP 404; no service
  or authentication changes were made.

Software rendering establishes screenshots and execution, not physical-GPU
performance or commercial-quality graphics.

Local preview: `artifacts/realism30-preview/Linux/IronMeridian` with adjacent
PCK. Export succeeded. Executed from a temporary directory outside the source
workspace: `artifacts/realism30-preview/offline.log` reports
`OFFLINE_SMOKE_PASS` (16 actors, reload/heal/damage/victory/raycast/cover/fire
interval/rig); `capture.log` reports `VISUAL_GAMEPLAY_CAPTURE_PASS`. Reviewed
`artifacts/realism30-preview/capture/gameplay.png`: the packaged skyline matches
the source capture. Hashes and check scope: preview `verification.json`.

## Independent packaged-frame review

Reviewed `artifacts/realism30-preview/capture/gameplay.png` independently.
The broader left summit is visible, but its smooth unbroken surface still
resembles a mound. Foreground grass is the strongest repeated pattern: similar
star-shaped clumps cover almost every open patch at similar spacing. More
instances alone will reinforce this pattern. Use distinct dense patches,
sparser transitional areas and exposed soil, with varied clump silhouettes;
retain clear roads and gameplay sight lines.

The asphalt-to-soil boundary around the central building is a perfectly sharp
polygon. Add a narrow, irregular dirt/gravel transition without changing the
collision footprint. Judge soil detail at the current player camera height:
the bottom third of this frame is visibly blurred and should show readable,
correctly scaled grains and small stones, not just stronger color noise.
Keep this exact packaged camera as the comparison view, plus a downward
close view to inspect ground transitions. After the ground pass, prioritize
the smooth gun receiver and glove/forearm material separation; these occupy
a large, continuously visible part of the image.
