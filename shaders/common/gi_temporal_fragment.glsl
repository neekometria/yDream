#include "/lib/config.glsl"
#include "/lib/luma.glsl"

#define GI_PASS_TEMPORAL

uniform sampler2D depthtex0;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
#if YDREAM_RSM_GI > 0
    uniform sampler2D colortex2;
    uniform sampler2D colortex10;
#endif

varying vec2 texcoord;

#include "/lib/gi_light.glsl"

void main() {
    float depth = texture2DLod(depthtex0, texcoord, 0.0).r;

    #if YDREAM_RSM_GI > 0
        vec4 giResult = vec4(0.0);

        if (depth < 0.99999 && depth > 0.56) {
            giResult = giResolve(colortex10, texture2DLod(colortex2, texcoord, 0.0), texcoord, 0.93);
        }
    #endif

    #if YDREAM_RSM_GI > 0
        /* RENDERTARGETS: 14 */
        gl_FragData[0] = giResult;
    #else
        /* RENDERTARGETS: 14 */
        gl_FragData[0] = vec4(0.0);
    #endif
}
