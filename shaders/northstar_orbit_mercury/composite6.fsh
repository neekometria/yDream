#version 120
#extension GL_ARB_shader_texture_lod : enable

// SSR da água (modos medium/raymarch). Roda depois da passagem translúcida,
// então enxerga a cena inteira, e grava a cor refletida em colortex5 na
// resolução interna escolhida em WATER_REFLECTION_RESOLUTION.
#include "/common/reflection_fragment.glsl"
