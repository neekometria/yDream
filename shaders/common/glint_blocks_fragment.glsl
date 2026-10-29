#include "/lib/config.glsl"

uniform sampler2D tex;

#if ENCHANT_GLINT_COLOR_MODE == 2 || ENCHANT_GLINT_COLOR_MODE == 3
    uniform float frameTimeCounter;
#endif

varying vec2 texcoord;
varying vec4 tintColor;

void main() {
    vec4 blockColor = texture2D(tex, texcoord) * tintColor;

    #if ENCHANT_GLINT_COLOR_MODE == 1
        vec3 glintTint = vec3(ENCHANT_GLINT_COLOR_R, ENCHANT_GLINT_COLOR_G, ENCHANT_GLINT_COLOR_B);
        blockColor.rgb = mix(blockColor.rgb, blockColor.rgb * glintTint * 2.2, ENCHANT_GLINT_STRENGTH);
    #elif ENCHANT_GLINT_COLOR_MODE == 2
        vec3 glintTint = 0.5 + 0.5 * cos(6.283185307179586 * (frameTimeCounter * 0.05 * ENCHANT_GLINT_SPEED + vec3(0.0, 0.33, 0.67)));
        blockColor.rgb = mix(blockColor.rgb, blockColor.rgb * glintTint * 2.4, ENCHANT_GLINT_STRENGTH);
    #elif ENCHANT_GLINT_COLOR_MODE == 3
        float glintPhase = 0.5 + 0.5 * sin(frameTimeCounter * 0.6 * ENCHANT_GLINT_SPEED);
        vec3 glintTint = mix(GLINT_SCHEME_LOW, GLINT_SCHEME_HIGH, glintPhase);
        blockColor.rgb = mix(blockColor.rgb, blockColor.rgb * glintTint * 2.2, ENCHANT_GLINT_STRENGTH);
    #endif

    #include "/src/writebuffers.glsl"
}
