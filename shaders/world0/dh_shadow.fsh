#version 120
#extension GL_ARB_shader_texture_lod : enable

#include "/lib/config.glsl"

varying vec4 vColor;
varying float vIsWater;

void main() {
    // Water LODs must not cast a hard opaque shadow, matching shadow.fsh.
    if (vIsWater > 0.5) discard;

    #ifdef COLORED_SHADOW
        /* DRAWBUFFERS:0 */
        gl_FragData[0] = vec4(vColor.rgb, 1.0);
    #else
        /* DRAWBUFFERS:0 */
        gl_FragData[0] = vec4(1.0);
    #endif
}
