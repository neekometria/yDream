#include "/lib/config.glsl"

#define GI_PASS_GATHER


uniform sampler2D depthtex0;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;
uniform float pixelSizeX;
uniform float pixelSizeY;

varying vec2 texcoord;

#if GLEAM_RSM_GI > 0
    #include "/lib/gi_light.glsl"
#endif

void main() {
    vec4 result = vec4(0.0);

    #if GLEAM_RSM_GI > 0
        float depth = texture2DLod(depthtex0, texcoord, 0.0).r;

        if (depth < 0.99999 && depth > 0.56) {
            result = giGather(texcoord, depth, giNoise(gl_FragCoord.xy));
        }
    #endif

    /* DRAWBUFFERS:2 */
    gl_FragData[0] = result;
}
