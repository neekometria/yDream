#include "/lib/config.glsl"
#include "/lib/luma.glsl"

#define GI_PASS_TEMPORAL

uniform sampler2D depthtex0;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

#if GLEAM_RSM_GI > 0
    uniform sampler2D colortex2;
    uniform sampler2D colortex10;
#endif

#if GLEAM_VOXEL_LIGHT > 0
    uniform sampler2D colortex12;
    uniform sampler2D colortex13;
#endif

varying vec2 texcoord;

#include "/lib/gi_light.glsl"

void main() {
    float depth = texture2DLod(depthtex0, texcoord, 0.0).r;

    #if GLEAM_RSM_GI > 0
        vec4 giResult = vec4(0.0);

        if (depth < 0.99999 && depth > 0.56) {
            giResult = giResolve(colortex10, texture2DLod(colortex2, texcoord, 0.0), texcoord, 0.93);
        }
    #endif

    #if GLEAM_VOXEL_LIGHT > 0
        vec4 clResult = vec4(0.0);

        if (depth > 0.56) {
            clResult = giResolve(colortex13, texture2DLod(colortex12, texcoord, 0.0), texcoord, 0.84);
        }
    #endif

    #if GLEAM_RSM_GI > 0 && GLEAM_VOXEL_LIGHT > 0
        /* RENDERTARGETS: 14,15 */
        gl_FragData[0] = giResult;
        gl_FragData[1] = clResult;
    #elif GLEAM_RSM_GI > 0
        /* RENDERTARGETS: 14 */
        gl_FragData[0] = giResult;
    #elif GLEAM_VOXEL_LIGHT > 0
        /* RENDERTARGETS: 15 */
        gl_FragData[0] = clResult;
    #else
        /* RENDERTARGETS: 14 */
        gl_FragData[0] = vec4(0.0);
    #endif
}
