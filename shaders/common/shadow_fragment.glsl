#include "/lib/config.glsl"

uniform sampler2D tex;

varying vec2 texcoord;
varying float is_noshadow;

#if GLEAM_RSM_GI > 0
    varying vec4 tintColor;
    varying vec3 worldRelPos;
#endif

#ifdef COLORED_SHADOW
    varying float is_water;
#endif

void main() {
    #ifdef COLORED_SHADOW
        if(is_water > 0.98)
            discard;
    #endif

    if (is_noshadow > 0.98) {
        discard;
    }

    vec4 blockColor = texture2D(tex, texcoord);

    #if GLEAM_RSM_GI > 0
        blockColor.rgb *= tintColor.rgb;
    #endif

    #if GLEAM_RSM_GI > 0
        /* DRAWBUFFERS:01 */
        gl_FragData[0] = blockColor;
        gl_FragData[1] = vec4(worldRelPos, 1.0);
    #else
        /* DRAWBUFFERS:0 */
        gl_FragData[0] = blockColor;
    #endif
}
