#version 120
#extension GL_ARB_shader_texture_lod : enable

#define USE_BASIC_SH

#ifdef USE_BASIC_SH
    #define UNKNOWN_DIM
#endif

#define PREPARE_SHADER
#define NO_SHADOWS
#define SET_FOG_COLOR

#include "/common/prepare_fragment.glsl"
