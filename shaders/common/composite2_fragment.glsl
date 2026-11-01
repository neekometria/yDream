#include "/lib/config.glsl"

const bool colortex0Clear = false;
const bool colortex1Clear = false;
#ifdef YDREAM_LIGHT_BUFFERS
const bool colortex2Clear = true;
#else
const bool colortex2Clear = false;
#endif
const bool colortex3Clear = false;
/*
const int colortex3Format = RGBA16F;
*/
const bool gaux1Clear = false;
const bool gaux2Clear = false;
const bool gaux3Clear = false;
const bool gaux4Clear = false;

uniform sampler2D colortex1;

#if AA_TYPE > 0 || defined MOTION_BLUR
    uniform sampler2D colortex3;
    uniform float pixelSizeX;
    uniform float pixelSizeY;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferProjection;
    uniform mat4 gbufferModelViewInverse;
    uniform vec3 cameraPosition;
    uniform vec3 previousCameraPosition;
    uniform mat4 gbufferPreviousProjection;
    uniform mat4 gbufferPreviousModelView;
    uniform sampler2D depthtex1;
    uniform float frameTime;
    uniform float near;
    uniform float far;
    uniform vec2 taaOffset;
    uniform vec2 taaOffsetPrevious;
#endif

#if AA_TYPE > 0
    #ifdef DISTANT_HORIZONS
        uniform sampler2D dhDepthTex1;
        uniform mat4 dhProjectionInverse;
        uniform mat4 dhModelViewInverse;
        uniform mat4 dhPreviousModelView;
        uniform mat4 dhPreviousProjection;
    #endif
    uniform int frameCounter;
#endif

varying vec2 texcoord;

#if AA_TYPE > 0 || defined MOTION_BLUR
    #include "/lib/projection_utils.glsl"
#endif

#ifdef MOTION_BLUR
    #include "/lib/dither.glsl"
    #include "/lib/motion_blur.glsl"
#endif

#if AA_TYPE > 0
    #include "/lib/luma.glsl"
    #include "/lib/color_conversion.glsl"
    #include "/lib/fast_taa.glsl"
#endif

#if AA_TYPE > 0 || defined MOTION_BLUR
    // Where this pixel was in the previous frame, in UV space. The current
    // frame was rendered with taaOffset and the history with taaOffsetPrevious,
    // so the jitter is removed before projecting and re-applied afterwards.
    vec2 taaReproject(float depthValue) {
        vec2 ndc = texcoord * 2.0 - 1.0 - taaOffset;

        #ifdef DISTANT_HORIZONS
            float dhDepth = texture2DLod(dhDepthTex1, texcoord, 0.0).r;

            // DH terrain lives behind the vanilla far plane. Iris exposes a
            // separate depth buffer and a separate set of matrices for it.
            if (dhDepth < 0.999999 && (depthValue >= 0.9999 || dhDepth < depthValue)) {
                vec4 dhView = dhProjectionInverse * vec4(ndc, dhDepth * 2.0 - 1.0, 1.0);
                dhView /= dhView.w;

                // Work in camera-relative space. The 3x3 part of the inverse
                // model-view matrices is a pure rotation, so this stays valid
                // regardless of how the engine fills in the translation.
                vec3 dhWorldRel = mat3(dhModelViewInverse) * dhView.xyz;
                vec3 dhPreviousWorldRel = dhWorldRel + cameraPosition - previousCameraPosition;
                vec3 dhPreviousView = mat3(dhPreviousModelView) * dhPreviousWorldRel;
                vec4 dhPreviousClip = dhPreviousProjection * vec4(dhPreviousView, 1.0);

                if (abs(dhPreviousClip.w) < 0.000001) {
                    return vec2(-1.0);
                }

                return dhPreviousClip.xy / dhPreviousClip.w * 0.5 + 0.5 + taaOffsetPrevious * 0.5;
            }
        #endif

        if (depthValue >= 0.9999) {
            // Sky: reproject the view direction only. Translating an infinite
            // point by the camera delta would be wrong.
            vec4 directionClip = gbufferProjectionInverse * vec4(ndc, 1.0, 1.0);
            vec3 viewDirection = normalize(directionClip.xyz / directionClip.w);
            vec3 worldDirection = mat3(gbufferModelViewInverse) * viewDirection;
            vec3 previousViewDirection = mat3(gbufferPreviousModelView) * worldDirection;
            vec4 previousClip = gbufferPreviousProjection * vec4(previousViewDirection, 0.0);

            if (abs(previousClip.w) < 0.000001) {
                return vec2(-1.0);
            }

            return previousClip.xy / previousClip.w * 0.5 + 0.5 + taaOffsetPrevious * 0.5;
        }

        vec4 viewClip = vec4(ndc, depthValue * 2.0 - 1.0, 1.0);
        vec4 viewPos = gbufferProjectionInverse * viewClip;
        viewPos /= viewPos.w;

        vec3 worldRel = mat3(gbufferModelViewInverse) * viewPos.xyz;
        vec3 previousWorldRel = worldRel + cameraPosition - previousCameraPosition;
        vec3 previousViewPos = mat3(gbufferPreviousModelView) * previousWorldRel;
        vec4 previousClip = gbufferPreviousProjection * vec4(previousViewPos, 1.0);

        if (abs(previousClip.w) < 0.000001) {
            return vec2(-1.0);
        }

        return previousClip.xy / previousClip.w * 0.5 + 0.5 + taaOffsetPrevious * 0.5;
    }
#endif

void main() {
    vec4 blockColor = texture2DLod(colortex1, texcoord, 0);

    #if AA_TYPE > 0 || defined MOTION_BLUR

        float z_depth = texture2DLod(depthtex1, texcoord, 0).r;
        vec2 texcoordPast = taaReproject(z_depth);

    #endif

    #ifdef MOTION_BLUR
        #if AA_TYPE > 0
           float dither = shiftedDitherMakeup(gl_FragCoord.xy);
        #else
           float dither = ditherMakeup(gl_FragCoord.xy);
        #endif

        // The scene was rendered at taaOffset and the history was rendered at
        // taaOffsetPrevious. Motion blur needs the unjittered motion vector.
        #if AA_TYPE > 0
            vec2 velocity = texcoord - texcoordPast + (taaOffsetPrevious - taaOffset) * 0.5;
        #else
            vec2 velocity = texcoord - texcoordPast;
        #endif

        blockColor.rgb = motionBlur(blockColor.rgb, z_depth, velocity, dither, colortex1);
    #endif

    #if AA_TYPE > 0
        float usedHistory;

        #ifdef DOF
            blockColor = fastTaaDepth(blockColor, texcoordPast, z_depth, usedHistory);
        #else
            blockColor = fastTaa(blockColor, texcoordPast, z_depth, usedHistory);
        #endif

        blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
        /* DRAWBUFFERS:13 */
        gl_FragData[0] = blockColor;
        gl_FragData[1] = blockColor;
    #else
        blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
        /* DRAWBUFFERS:1 */
        gl_FragData[0] = blockColor;
    #endif
}
