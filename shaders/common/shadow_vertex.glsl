#include "/lib/config.glsl"

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

varying vec2 texcoord;
varying float is_noshadow;

#if YDREAM_RSM_GI > 0
    varying vec4 tintColor;
    varying vec3 worldRelPos;
#endif

#ifdef COLORED_SHADOW
    varying float is_water;
#endif

attribute vec4 mc_Entity;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #if YDREAM_RSM_GI > 0
        tintColor = gl_Color;
    #endif

    vec4 position = shadowModelViewInverse * shadowProjectionInverse * gl_ModelViewProjectionMatrix * gl_Vertex;
    gl_Position = shadowProjection * shadowModelView * position;

    #if YDREAM_RSM_GI > 0
        worldRelPos = position.xyz;
    #endif

    float dist = length(gl_Position.xy);
    float distortFactor = dist * SHADOW_DIST + (1.0 - SHADOW_DIST);

    gl_Position.xy *= 1.0 / distortFactor;
    gl_Position.z = gl_Position.z * 0.2;

    is_noshadow = 0.0;
    if (mc_Entity.x == ENTITY_NO_SHADOW_FIRE || mc_Entity.x == ENTITY_F_EMMISIVE) {
        is_noshadow = 1.0;
    }

    #ifdef COLORED_SHADOW
        is_water = 0.0;

        if(mc_Entity.x == ENTITY_WATER) {
            is_water = 1.0;
        }
    #endif
}
