# Stage 528: static grass diagnostic

The Android 0.52.7 release remains the latest published, tested client.
This diagnostic does not change game source or publish another APK.

The Pixel 10 walkthrough still shows unusually dark roadside grass.
Two desktop Compatibility renderer probes were run under Xvfb:

- `artifacts/realism528-validation/static_grass_probe.gd`: imported
  MeshInstance3D versus MultiMesh without instance colors versus MultiMesh
  with explicit white instance colors.
- `artifacts/realism528-validation/static_grass_srgb.gd`: imported standard
  material versus explicit false/true `vertex_color_is_srgb`.

Both screenshots show dark blades in all three groups. Imported material
albedo is white and its sRGB vertex-color flag is already false. Explicit
white instance colors do not visibly solve the dark imported static grass.
Therefore the missing `use_colors` setting in `batch_static_grass` is not
established as the cause; no speculative production patch was applied.

These probes use Mesa llvmpipe, not an Android GPU. They cannot establish
the mobile root cause. Next investigation should compare imported standard
material lighting with the meadow grass shader using identical transforms
and fixed vertex colors, including backface and normal behavior.

The overall realism goal remains incomplete.
