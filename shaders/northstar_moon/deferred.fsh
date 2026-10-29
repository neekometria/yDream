#version 120
#extension GL_ARB_shader_texture_lod : enable

#define NORTHSTAR_MOON
#define NO_CLOUDY_SKY
#define DEFERRED_SHADER
#define NO_SHADOWS

#include "/common/deferred_fragment.glsl"
