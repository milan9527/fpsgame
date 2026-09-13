# Realistic environment asset notices

The photographs, PBR texture maps, fir tree source and sky panorama in this directory
are derived from [Poly Haven](https://polyhaven.com), released under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
Poly Haven's licensing statement: https://polyhaven.com/license.

Sources:
- https://polyhaven.com/a/aerial_grass_rock — ground albedo, OpenGL normal, roughness.
- https://polyhaven.com/a/grey_plaster_02 — plaster maps.
- https://polyhaven.com/a/asphalt_02 — road maps.
- https://polyhaven.com/a/corrugated_iron_02 — roof maps.
- https://polyhaven.com/a/fir_tree_01 — Rob Tuytel (photography), Rico Cilliers (modeling).
  Variant C normalized to 9 m; preserved geometry for close range and a Blender-rendered
  transparent billboard for distance.
  Embedded/extracted fir textures are also derivatives of this source.
- https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky — Greg Zaal (Original),
  Jarod Guest (Sky edits). Tonemapped panorama resized to 2048 × 1024.

Exact download URLs and texture checksums are recorded in SOURCES.json.
`shutter_panel.glb` is an original project asset created by tools/build_realism_assets.py.
`uniform.png` is an original procedural camouflage weave made by tools/generate_uniform_texture.py.
No assets from Peace Elite or PUBG are included. This project is not affiliated with them.

`grass.glb` is original curved-blade geometry authored by tools/build_grass.py.

Additional Poly Haven CC0 sources (including their embedded/extracted maps):
- https://polyhaven.com/a/wooden_military_crate — Prabhjinder Singh. Rescaled to the existing cover bounds and reduced to 11,998 triangles.
- https://polyhaven.com/a/boulder_01 — Rico Cilliers. Normalized, welded and reduced to 12,000 triangles for background scenery.

Ground and plaster maps now use the original 2K versions. Their exact URLs and checksums are recorded in SOURCES.json.

Additional facade assets from Poly Haven, CC0:
- https://polyhaven.com/a/exterior_aircon_unit — Monsta3D. First variant selected and normalized for wall mounting.
- https://polyhaven.com/a/industrial_wall_lamp — Kuutti Siitonen. Normalized for wall mounting.
- https://polyhaven.com/a/rollershutter_window_01 — MP. First variant selected and normalized for wall mounting.

`supply_case.glb` is original project geometry authored by tools/build_supply_case.py.

`roof_gable.glb` and `roof_shed.glb` are original project geometry authored by
`tools/build_roofs.py`. They use the project's existing metal roof material at runtime.

`fir_background.png` is a Blender-rendered derivative of Poly Haven
`fir_tree_01`, variant B (Rob Tuytel / Rico Cilliers, CC0).
The high-resolution authoring scene can be regenerated with
`tools/fetch_tree_variant.py` and `FIR_VARIANT=B tools/build_tree_impostor.py`
(the latter runs inside Blender). Download ranges and hashes are recorded in
`SOURCES.json`; the large intermediate Blend stays under local `artifacts/`.

`plaster_painted.jpg` is a contrast/saturation/brightness-adjusted derivative
of the existing CC0 `grey_plaster_02` albedo, prepared by
`tools/prepare_wall_finish.py`. Its original source is listed in `SOURCES.json`.

`concrete_albedo.jpg`, `concrete_normal.jpg`, and `concrete_roughness.jpg`:
https://polyhaven.com/a/concrete_floor_02 — Rob Tuytel, CC0.
Original 2K maps for interior floors; URLs/checksums are in `SOURCES.json`.

`terrain_rock_albedo.jpg`, `terrain_rock_normal.jpg`, and
`terrain_rock_roughness.jpg`: https://polyhaven.com/a/rock_face_03 —
Dario Barresi (Photography), Rico Cilliers (Processing), CC0.
Original 2K maps blended by slope on background terrain; source URLs and
checksums are recorded in `SOURCES.json`.

`facade_0.glb`, `facade_1.glb`, and `facade_2.glb` are original project
warehouse facade assemblies authored with `tools/build_facades.py`.
Their concrete members use the existing CC0 `concrete_floor_02` scan at runtime,
and the steel infill uses the existing CC0 `corrugated_iron_02` scan.
Folded sheet steel, closed louvers, frames and backing are original geometry.
