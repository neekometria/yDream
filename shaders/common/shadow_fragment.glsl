#include "/lib/config.glsl"

uniform sampler2D tex;
// Jogador submerso: o corpo dele no shadow map carva a silhueta nos feixes
// volumétricos e os godrays ficam horriveis. Fora d'água a sombra continua.
// Iris zera entityId fora de draw de entidade, então o descarte atinge só o
// modelo do jogador (mesmos ids de entity.properties usados nos gbuffers).
uniform int entityId;
uniform int isEyeInWater;

varying vec2 texcoord;
varying float is_noshadow;

#if YDREAM_RSM_GI > 0
    varying vec4 tintColor;
    varying vec3 worldRelPos;
#endif

#ifdef COLORED_SHADOW
    varying float is_water;
#endif

void main() {
    if (isEyeInWater == 1 && (entityId == 10301 || entityId == 10302)) {
        discard;
    }

    #ifdef COLORED_SHADOW
        if(is_water > 0.98)
            discard;
    #endif

    if (is_noshadow > 0.98) {
        discard;
    }

    vec4 blockColor = texture2D(tex, texcoord);

    #if YDREAM_RSM_GI > 0
        blockColor.rgb *= tintColor.rgb;
    #endif

    #if YDREAM_RSM_GI > 0
        /* DRAWBUFFERS:01 */
        gl_FragData[0] = blockColor;
        gl_FragData[1] = vec4(worldRelPos, 1.0);
    #else
        /* DRAWBUFFERS:0 */
        gl_FragData[0] = blockColor;
    #endif
}
