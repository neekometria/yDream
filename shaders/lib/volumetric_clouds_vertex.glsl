#if MC_VERSION >= 11300
    umbral = ((1.0 - smoothstep(0.0, 1.0, rainStrength)) * .3) + CLOUD_BASE_UMBRAL;
#else
    umbral = ((1.0 - smoothstep(0.0, 1.0, rainStrength)) * .3) + CLOUD_BASE_UMBRAL;
#endif

#include "/src/cloud_palette.glsl"
