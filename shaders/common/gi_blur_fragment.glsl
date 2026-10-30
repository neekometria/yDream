#include "/lib/config.glsl"
#include "/lib/luma.glsl"

#define GI_PASS_BLUR

uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform float pixelSizeX;
uniform float pixelSizeY;

#if YDREAM_RSM_GI > 0
    uniform sampler2D colortex9;
    uniform sampler2D colortex14;
#endif

#if YDREAM_VOXEL_LIGHT > 0
    uniform sampler2D colortex15;
#endif

varying vec2 texcoord;

#include "/lib/gi_light.glsl"

void main() {
    vec4 blockColor = texture2DLod(colortex1, texcoord, 0.0);
    float depth = texture2DLod(depthtex0, texcoord, 0.0).r;

    #if YDREAM_RSM_GI > 0
        vec4 giHistory = texture2DLod(colortex14, texcoord, 0.0);

        if (depth < 0.99999 && depth > 0.56 && luma(blockColor.rgb) < 1.5) {
            vec3 albedo = texture2DLod(colortex9, texcoord, 0.0).rgb;

            if (albedo.r + albedo.g + albedo.b > 0.01) {
                vec3 indirect = giBlur(texcoord);
                indirect = mix(vec3(luma(indirect)), indirect, 0.9);
                albedo = mix(vec3(luma(albedo)), albedo, 0.92);
                float shadowFill = 1.0 - smoothstep(0.45, 1.30, luma(blockColor.rgb));

                vec3 giAdded = albedo * min(indirect, vec3(1.5)) * (0.95 * GI_STRENGTH * (0.35 + 0.65 * shadowFill));
                #if SS_DEBUG == 1
                    blockColor.rgb = vec3(luma(giAdded) * 10.0);
                #else
                    blockColor.rgb += giAdded;
                #endif
            }
        }
    #endif

    #if YDREAM_VOXEL_LIGHT > 0
        vec4 clHistory = texture2DLod(colortex15, texcoord, 0.0);

        if (depth > 0.56) {
            blockColor.rgb = max(blockColor.rgb + clHistory.rgb, vec3(0.0));
        }
    #endif

    blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 50.0));

    #if YDREAM_RSM_GI > 0 && YDREAM_VOXEL_LIGHT > 0
        /* RENDERTARGETS: 1,4,10,13 */
        gl_FragData[0] = blockColor;
        gl_FragData[1] = vec4(blockColor.rgb, 1.0);
        gl_FragData[2] = giHistory;
        gl_FragData[3] = clHistory;
    #elif YDREAM_RSM_GI > 0
        /* RENDERTARGETS: 1,4,10 */
        gl_FragData[0] = blockColor;
        gl_FragData[1] = vec4(blockColor.rgb, 1.0);
        gl_FragData[2] = giHistory;
    #elif YDREAM_VOXEL_LIGHT > 0
        /* RENDERTARGETS: 1,4,13 */
        gl_FragData[0] = blockColor;
        gl_FragData[1] = vec4(blockColor.rgb, 1.0);
        gl_FragData[2] = clHistory;
    #else
        /* RENDERTARGETS: 1 */
        gl_FragData[0] = blockColor;
    #endif
}
