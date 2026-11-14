#version 430 compatibility
#extension GL_ARB_shader_texture_lod : enable

#define GBUFFER_TERRAIN
#define FOLIAGE_V
#define EMMISIVE_V
// Exige #version 430+; por isso este programa é o único em 430.

#include "/common/solid_blocks_vertex.glsl"
