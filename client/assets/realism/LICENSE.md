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
