shader_type spatial;
uniform bool vertical_grain = false;
uniform float board_seed = 0.0;
varying vec3 timber_position;
void vertex() { timber_position = VERTEX; }
void fragment() {
    float across = vertical_grain ? timber_position.z : timber_position.y;
    float along = vertical_grain ? timber_position.y : timber_position.x;
    float grain = sin(across * 420.0 + sin(along * 8.0 + board_seed) * 2.5);
    float resolved = 1.0 - smoothstep(0.002, 0.012, fwidth(across));
    // Long fibres and board-to-board bleaching, avoiding broad plastic-looking bands.
    float weather = 0.5 + 0.3 * sin(across * 53.0 + sin(along * 1.7) + board_seed)
        + 0.2 * sin(board_seed * 3.1);
    float fibres = sin(across * 137.0 + sin(along * 3.0 + board_seed) * 0.8);
    float split = smoothstep(0.96, 1.0, fibres) * resolved;
    float foot_damp = vertical_grain ? 1.0 - smoothstep(-0.52, -0.20, along) : 0.0;
    ALBEDO = mix(vec3(0.085, 0.073, 0.057), vec3(0.17, 0.155, 0.125), weather) * (1.0 + grain * resolved * 0.14);
    ALBEDO *= 1.0 - split * 0.30 - foot_damp * 0.24;
    ROUGHNESS = 0.94;
    SPECULAR = 0.16;
}
