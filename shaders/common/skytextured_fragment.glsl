#include "/lib/config.glsl"

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

uniform sampler2D tex;

varying vec2 texcoord;
varying vec4 tintColor;
varying float sky_luma_correction;

void main() {
    #if defined THE_END || defined NETHER
        // The prepared sky is the only sky here. Vanilla quads would overwrite it.
        discard;
    #endif
    #if defined THE_END
        #if MC_VERSION >= 12109
            vec4 blockColor = vec4(ZENITH_DAY_COLOR, 0.0);
        #else
            vec4 blockColor = vec4(ZENITH_DAY_COLOR, 1.0);
        #endif
    #elif defined NETHER
        vec4 background_color_full = vec4(netherFog(fogColor), 1.0);
        vec3 background_color = background_color_full.rgb;
        vec4 blockColor = vec4(background_color, 1.0);
    #else

        vec4 blockColor = texture2D(tex, texcoord) * tintColor;

        blockColor.rgb *= sky_luma_correction;
    #endif

    #include "/src/writebuffers.glsl"
}
