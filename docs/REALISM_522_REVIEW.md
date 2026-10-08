# Stage 522: vegetation verification in progress

This stage is not an overall visual-quality acceptance or a published client.

## Changes

- Static imported fine-grass and broadleaf meshes are batched by mesh,
  spatial cell and rendering properties. Objects with children, visibility
  gates or unsupported material state stay separate.
- Meadow sampling looks up nearby paving exclusions in 12m cells. The index
  includes each rectangle's 10m margin, matching the original capped distance
  query. Input order and the vegetation random stream remain unchanged.
- Spawn capture now prints elapsed times at scene readiness, solo readiness
  and explicit drawing, to distinguish initialization from rendering delays.

## Evidence

- Pre/post exclusion-grid `world-geometry.json` and `world-geometry-grid.json`
  are exactly equal as parsed JSON. This preserves source geometry counts,
  not a measurement of frame rate.
- With incidental rendering disabled, scene construction took 37.0 seconds
  and solo startup reached 37.6 seconds; explicit drawing began at 39.1 seconds.
  The observed delay is now inside full-frame software rendering.

- `artifacts/realism522-validation/batching/regression-renderer.log`:
  real Compatibility renderer passed transform/material retention and
  child/range/override exclusion checks for static batching.
- `artifacts/realism522-validation/batching/exclusion-grid.log`:
  22,928 sample and boundary points exactly matched original obstruction and
  paving-distance results. Candidate counts were 69,430 versus 2,797,216.
  This measures candidate reduction, not game FPS or loading time.
- The first Forward+ spawn capture ended without an image. Its log does
  not establish which initialization or rendering phase exhausted the limit.
- The earlier Compatibility capture also ended without an image. The process
  is no longer present; its log contains renderer startup only.
- The capture harness now disables automatic rendering before constructing
  the scene, avoiding incidental software-rendered frames during setup.
  The final explicit draw remains enabled.

## Remaining checks

Inspect complete scene screenshots and capture the final changed scene. Source triangle
counts do not establish GPU work or visual quality. Character, weapon,
terrain and vegetation realism still require direct visual review.

No GitHub push or client publication is part of this stage.
