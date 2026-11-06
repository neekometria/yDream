#version 120
#extension GL_ARB_shader_texture_lod : enable

#define THE_END

#include "/lib/config.glsl"

varying vec4 vColor;
varying float vIsWater;

void main() {
    vColor = gl_Color;
    vIsWater = (dhMaterialId == DH_BLOCK_WATER) ? 1.0 : 0.0;

    // The DH shadow pass keeps the normal shadow projection/modelview.
    // Do NOT use dhProjection here: that matrix belongs to the main LOD pass
    // and has a different near/far range.
    vec4 clipPos = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;

    // Must match world1/shadow.vsh and get_shadow_pos() in lib/shadow_vertex.glsl.
    // If this distortion diverges, DH shadows land at the wrong place in the map.
    float dist = length(clipPos.xy);
    float distortFactor = dist * SHADOW_DIST + (1.0 - SHADOW_DIST);
    clipPos.xy *= 1.0 / distortFactor;
    clipPos.z *= 0.2;

    gl_Position = clipPos;
}
