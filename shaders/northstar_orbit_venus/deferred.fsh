#version 120
#extension GL_ARB_shader_texture_lod : enable
#define NORTHSTAR_ORBIT_RADIUS 0.72333199

#define NORTHSTAR_ORBIT
#define NO_CLOUDY_SKY
#define DEFERRED_SHADER
#define NO_SHADOWS

#include "/common/deferred_fragment.glsl"
