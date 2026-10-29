#include "/lib/config.glsl"

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

uniform mat4 gbufferModelView;
uniform float rainStrength;

varying vec3 upVector;
varying vec3 zenithSkyColor;
varying vec3 horizonSkyColor;

#include "/lib/luma.glsl"

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

    #include "/src/hi_sky.glsl"
    #include "/src/low_sky.glsl"

    upVector = normalize(gbufferModelView[1].xyz);
}
