#include "/lib/config.glsl"

uniform mat4 gbufferProjectionInverse;

#if defined SHADOW_CASTING && !defined NETHER
    uniform mat4 gbufferModelViewInverse;
#endif

varying vec2 texcoord;
varying vec4 tintColor;
varying vec3 eyeViewPos;

#if AA_TYPE > 0
    #include "/src/taa_offset.glsl"
#endif

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    // Keep per-vertex tint/alpha: entity eyes (e.g. Punchy Moves' animated face)
    // fade their glow through gl_Color.a instead of the lightmap.
    tintColor = gl_Color;
    eyeViewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;

    #include "/src/position_vertex.glsl"
}
