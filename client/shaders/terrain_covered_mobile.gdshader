shader_type spatial;
// Compile out slope normals, triplanar sampling and rock samplers.
#define TERRAIN_COVERED_STATIC
#include "terrain_slopes_mobile.gdshaderinc"
