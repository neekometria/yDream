#version 120
#extension GL_ARB_shader_texture_lod : enable

#ifdef USE_BASIC_SH
    #define UNKNOWN_DIM
#endif
#define SHADOW_SHADER

#include "/common/shadow_vertex.glsl"
