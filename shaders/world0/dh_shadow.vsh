#version 120
#extension GL_ARB_shader_texture_lod : enable

#include "/lib/config.glsl"

varying vec4 vColor;
varying float vIsWater;

void main() {
    vColor = gl_Color;
    vIsWater = (dhMaterialId == DH_BLOCK_WATER) ? 1.0 : 0.0;

    // Usa exatamente a mesma transformacao de shadow.vsh (gl_ModelViewProjectionMatrix,
    // que o Iris define como as matrizes do shadow map na passagem de sombra).
    // Esse e o caminho que ja funciona no terreno vanilla. Nao usar dhProjection
    // aqui: essa matriz pertence ao passe principal do LOD e tem outro near/far.
    vec4 clipPos = gl_ModelViewProjectionMatrix * gl_Vertex;

    // Must match world0/shadow.vsh and get_shadow_pos() in lib/shadow_vertex.glsl.
    // If this distortion diverges, DH shadows land at the wrong place in the map.
    float dist = length(clipPos.xy);
    float distortFactor = dist * SHADOW_DIST + (1.0 - SHADOW_DIST);
    clipPos.xy *= 1.0 / distortFactor;
    clipPos.z *= 0.2;

    gl_Position = clipPos;
}
