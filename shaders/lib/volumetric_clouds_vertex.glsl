#if MC_VERSION >= 11300
    umbral = ((1.0 - smoothstep(0.0, 1.0, rainStrength)) * .3) + .22;
#else
    umbral = ((1.0 - smoothstep(0.0, 1.0, rainStrength)) * .3) + .52;
#endif

#include "/src/cloud_palette.glsl"
