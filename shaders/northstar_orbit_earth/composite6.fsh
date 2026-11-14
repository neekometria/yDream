#version 120
#extension GL_ARB_shader_texture_lod : enable

#define NORTHSTAR_ORBIT_RADIUS 1.0
#define NORTHSTAR_ORBIT_EARTH
#define NORTHSTAR_ORBIT

// Passe desativado: o reflexo da água agora é inline no passe dela.
// Mantido apenas como stub válido caso o programa volte a ser habilitado.
#include "/common/reflection_fragment.glsl"
