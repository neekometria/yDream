#undef NO_SHADOWS
#include "/lib/config.glsl"

const bool colortex0Clear = false;
const bool colortex1Clear = false;
#ifdef YDREAM_LIGHT_BUFFERS
const bool colortex2Clear = true;
#else
const bool colortex2Clear = false;
#endif
const bool colortex3Clear = false;
const bool gaux1Clear = false;
const bool gaux2Clear = false;
const bool gaux3Clear = false;
const bool gaux4Clear = false;

// Terrain shadows (vanilla and DH) now come from the real shadow map:
//   * DH_SHADOWS=1 makes DH terrain/water read shadowtex1.
//   * dhShadow.enabled=true + world0/dh_shadow.* makes DH write into that map.
// The old screen-space raymarch (and its per-frame dithering) is intentionally
// gone; it caused halos, false shadows and whole-color darkening on DH pixels.
#if AA_TYPE > 0 || defined MOTION_BLUR
    #define YDREAM_C2_DEPTH
#endif

// Forward-Z convention used by Minecraft 1.21.1 + Iris 1.8.x:
// sky / far plane = 1.0, near plane = 0.0.
//
// Minecraft 1.21.1 does not use a reverse-Z depth buffer, and DH 3.3.3
// reports FORWARD_Z while an Iris shader pack is active (its
// IrisAccessor.isReverseZDuringShaders() is hard-coded to false). This is
// the same convention already used by deferred_fragment.glsl and
// composite1_vertex.glsl in this pack.
//
// Vanilla and DH use different far planes, so DH valid geometry can get
// closer to 1.0 than vanilla geometry can.
#define YDREAM_SKY_DEPTH 0.9999
#define YDREAM_DH_SKY_DEPTH 0.999999

uniform sampler2D colortex1;

#if AA_TYPE > 0
    uniform sampler2D colortex3;
    uniform int frameCounter;
#endif

#ifdef YDREAM_C2_DEPTH
    uniform sampler2D depthtex1;
    uniform float pixelSizeX;
    uniform float pixelSizeY;
    uniform mat4 gbufferProjection;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferPreviousProjection;
    uniform mat4 gbufferPreviousModelView;
    uniform vec3 cameraPosition;
    uniform vec3 previousCameraPosition;
    uniform vec2 taaOffset;
    uniform vec2 taaOffsetPrevious;
    uniform float frameTime;
#endif

#ifdef DISTANT_HORIZONS
    uniform sampler2D dhDepthTex1;
    uniform mat4 dhProjection;
    uniform mat4 dhProjectionInverse;
    uniform mat4 dhPreviousProjection;
#endif

varying vec2 texcoord;

#ifdef YDREAM_C2_DEPTH
    #include "/lib/projection_utils.glsl"
#endif

#ifdef MOTION_BLUR
    #include "/lib/dither.glsl"
#endif

#ifdef MOTION_BLUR
    #include "/lib/motion_blur.glsl"
#endif

#if AA_TYPE > 0
    #include "/lib/luma.glsl"
    #include "/lib/color_conversion.glsl"
    #include "/lib/fast_taa.glsl"
#endif

#ifdef YDREAM_C2_DEPTH
    vec2 c2_ndc_unjittered(vec2 uv) {
        return uv * 2.0 - 1.0 - taaOffset;
    }

    vec3 c2_view_from_depth(mat4 projInv, vec2 ndc, float depth) {
        vec4 viewPos = projInv * vec4(ndc, depth * 2.0 - 1.0, 1.0);
        return viewPos.xyz / viewPos.w;
    }

    float c2_linear_distance(vec2 uv, float depth, mat4 projInv) {
        return -c2_view_from_depth(projInv, c2_ndc_unjittered(uv), depth).z;
    }

    vec2 c2_previous_uv(vec2 ndc, float depth, float isLod, float isSky) {
        if (isSky > 0.5) {
            vec4 dirClip = gbufferProjectionInverse * vec4(ndc, 1.0, 1.0);
            vec3 viewDir = normalize(dirClip.xyz / dirClip.w);
            vec3 worldDir = mat3(gbufferModelViewInverse) * viewDir;
            vec3 prevDir = mat3(gbufferPreviousModelView) * worldDir;
            vec4 prevClip = gbufferPreviousProjection * vec4(prevDir, 0.0);
            if (abs(prevClip.w) < 1e-6) return vec2(-10.0);
            return prevClip.xy / prevClip.w * 0.5 + 0.5;
        }

        #ifdef DISTANT_HORIZONS
            if (isLod > 0.5) {
                vec3 lodView = c2_view_from_depth(dhProjectionInverse, ndc, depth);
                vec4 lodPlayerPos = gbufferModelViewInverse * vec4(lodView, 1.0);
                vec3 lodRel = lodPlayerPos.xyz / lodPlayerPos.w + cameraPosition - previousCameraPosition;
                vec4 lodPrevView = gbufferPreviousModelView * vec4(lodRel, 1.0);
                vec4 lodPrevClip = dhPreviousProjection * lodPrevView;
                if (abs(lodPrevClip.w) < 1e-6) return vec2(-10.0);
                return lodPrevClip.xy / lodPrevClip.w * 0.5 + 0.5;
            }
        #endif

        vec3 viewPos = c2_view_from_depth(gbufferProjectionInverse, ndc, depth);
        vec4 playerPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
        vec3 worldRel = playerPos.xyz / playerPos.w + cameraPosition - previousCameraPosition;
        vec4 prevViewPos = gbufferPreviousModelView * vec4(worldRel, 1.0);
        vec4 prevClip = gbufferPreviousProjection * prevViewPos;
        if (abs(prevClip.w) < 1e-6) return vec2(-10.0);
        return prevClip.xy / prevClip.w * 0.5 + 0.5;
    }
#endif

void main() {
    vec4 blockColor = texture2DLod(colortex1, texcoord, 0);

#ifdef YDREAM_C2_DEPTH
    vec2 ps = vec2(pixelSizeX, pixelSizeY);
    float vanillaDepthHere = texture2DLod(depthtex1, texcoord, 0.0).r;
#endif

#ifdef YDREAM_C2_DEPTH
    float motionDepth = vanillaDepthHere;
    float motionDistance = 1e4;
    float motionLod = 0.0;
    float isSky = 1.0;

    if (vanillaDepthHere < YDREAM_SKY_DEPTH) {
        motionDistance = c2_linear_distance(texcoord, vanillaDepthHere, gbufferProjectionInverse);
        isSky = 0.0;
    } else {
        #ifdef DISTANT_HORIZONS
            float lodDepthHere = texture2DLod(dhDepthTex1, texcoord, 0.0).r;
            if (lodDepthHere < YDREAM_DH_SKY_DEPTH) {
                motionDepth = lodDepthHere;
                motionDistance = c2_linear_distance(texcoord, lodDepthHere, dhProjectionInverse);
                motionLod = 1.0;
                isSky = 0.0;
            }
        #endif
    }

    vec2 currentUnjitteredUV = texcoord - 0.5 * taaOffset;
    vec2 currentUnjitteredNDC = c2_ndc_unjittered(texcoord);
    vec2 previousUnjitteredUV = c2_previous_uv(currentUnjitteredNDC, motionDepth, motionLod, isSky);
    vec2 motion = previousUnjitteredUV - currentUnjitteredUV;
    vec2 previousUV = previousUnjitteredUV + 0.5 * taaOffsetPrevious;

    #if AA_TYPE > 0 || defined MOTION_BLUR
        float zDepth = vanillaDepthHere;
    #endif

    #ifdef MOTION_BLUR
        #if AA_TYPE > 0
            float dither = shiftedDitherMakeup(gl_FragCoord.xy);
        #else
            float dither = ditherMakeup(gl_FragCoord.xy);
        #endif
        vec2 velocity = -motion;
        blockColor.rgb = motionBlur(blockColor.rgb, zDepth, velocity, dither, colortex1);
    #endif
#endif

#if AA_TYPE > 0
    bool previousValid = frameCounter >= 2
        && previousUV.x >= 0.0 && previousUV.y >= 0.0
        && previousUV.x <= 1.0 && previousUV.y <= 1.0;

    vec2 res = vec2(1.0 / pixelSizeX, 1.0 / pixelSizeY);
    vec2 historyTexel = (floor(previousUV * res) + 0.5) / res;
    float historyAge = texture2DLod(colortex3, historyTexel, 0.0).a * TAA_MAX_AGE;

    blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));

    vec3 outLinear;
    vec3 outHistory;
    float outAge;

    taa_resolve(blockColor.rgb, texcoord, previousUV, previousValid, historyAge, motionDistance, outLinear, outHistory, outAge);

    /* DRAWBUFFERS:13 */
    #if YDREAM_TAA_DEBUG == 0
        gl_FragData[0] = vec4(outLinear, blockColor.a);
    #else
        vec3 taaDebug;
        #if YDREAM_TAA_DEBUG == 1
            taaDebug = previousValid ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        #elif YDREAM_TAA_DEBUG == 2
            taaDebug = vec3(outAge / TAA_MAX_AGE);
        #elif YDREAM_TAA_DEBUG == 3
            taaDebug = vec3(clamp(length(motion / ps) * 0.5, 0.0, 1.0));
        #else
            taaDebug = texcoord.x < 0.5 ? blockColor.rgb : outLinear;
        #endif
        gl_FragData[0] = vec4(taaDebug, blockColor.a);
    #endif
    gl_FragData[1] = vec4(outHistory, outAge / TAA_MAX_AGE);
#else
    blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
    /* DRAWBUFFERS:1 */
    gl_FragData[0] = blockColor;
#endif
}