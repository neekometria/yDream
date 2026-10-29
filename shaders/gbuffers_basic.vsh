#version 120
#extension GL_ARB_shader_texture_lod : enable

#define USE_BASIC_SH

#ifdef USE_BASIC_SH
    #define UNKNOWN_DIM
#endif
#define GBUFFER_BASIC
#define NO_SHADOWS
#define SHADER_LINE

#include "/common/basic_blocks_vertex.glsl"
