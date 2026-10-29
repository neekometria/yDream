#version 120
#extension GL_ARB_shader_texture_lod : enable

#define USE_BASIC_SH

#ifdef USE_BASIC_SH
    #define UNKNOWN_DIM
#endif
#define GBUFFER_WATER
#define WATER_F

#include "/common/water_blocks_fragment.glsl"
