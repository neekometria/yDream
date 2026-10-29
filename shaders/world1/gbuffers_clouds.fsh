#version 120
#extension GL_ARB_shader_texture_lod : enable

#define THE_END
#define GBUFFER_CLOUDS
#define NO_SHADOWS
#define SPECIAL_TRANS

#include "/common/clouds_blocks_fragment.glsl"
