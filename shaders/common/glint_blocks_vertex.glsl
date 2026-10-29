#include "/lib/config.glsl"

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

varying vec2 texcoord;
varying vec4 tintColor;

#if AA_TYPE > 0
    #include "/src/taa_offset.glsl"
#endif

void main() {
    #include "/src/basiccoords_vertex.glsl"
    #include "/src/position_vertex.glsl"

    tintColor = gl_Color;
}
