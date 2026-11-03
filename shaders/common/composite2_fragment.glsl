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

#if defined DISTANT_HORIZONS && DH_SHADOWS == 1 && !defined NETHER
    #define YDREAM_C2_DH_SHADOWS
#endif

#if defined SUN_OCCLUSION_ACTIVE && defined DISTANT_HORIZONS
    #define YDREAM_C2_SUN_OCCLUSION
#endif

#if AA_TYPE > 0 || defined MOTION_BLUR || defined YDREAM_C2_DH_SHADOWS || defined YDREAM_C2_SUN_OCCLUSION
    #define YDREAM_C2_DEPTH
#endif

#define YDREAM_DH_SS_STEPS 24
#define YDREAM_DH_SS_DIRECT_SHARE 0.6

uniform sampler2D colortex1;

#ifdef YDREAM_C2_SUN_OCCLUSION
    uniform sampler2D colortex5;
#endif

#if AA_TYPE > 0
    uniform sampler2D colortex3;
#endif

#if AA_TYPE > 0 || defined YDREAM_C2_DH_SHADOWS || defined YDREAM_C2_SUN_OCCLUSION
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

#if defined YDREAM_C2_DH_SHADOWS || defined YDREAM_C2_SUN_OCCLUSION
    uniform vec3 sunPosition;
#endif

varying vec2 texcoord;

#ifdef YDREAM_C2_DEPTH
    #include "/lib/projection_utils.glsl"
#endif

#if defined MOTION_BLUR || defined YDREAM_C2_DH_SHADOWS || defined YDREAM_C2_SUN_OCCLUSION
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

    float c2_linear_distance_raw(vec2 uv, float depth, mat4 projInv) {
        return -c2_view_from_depth(projInv, uv * 2.0 - 1.0, depth).z;
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

#if defined YDREAM_C2_DH_SHADOWS || defined YDREAM_C2_SUN_OCCLUSION
    vec2 c2_occluder_info(vec2 uv) {
        float vanillaDepth = texture2DLod(depthtex1, uv, 0.0).r;
        if (vanillaDepth < 0.9999) {
            return vec2(c2_linear_distance_raw(uv, vanillaDepth, gbufferProjectionInverse), 1.0);
        }
        #ifdef DISTANT_HORIZONS
            float lodDepth = texture2DLod(dhDepthTex1, uv, 0.0).r;
            if (lodDepth < 0.999999) {
                return vec2(c2_linear_distance_raw(uv, lodDepth, dhProjectionInverse), 2.0);
            }
        #endif
        return vec2(-1.0, 0.0);
    }

    float c2_sun_visibility(vec3 pos, vec3 normal, vec3 lightDir, float dither, mat4 projMatrix, float vanillaWeight, float lodWeight) {
        float reach = float(SUN_OCCLUSION_REACH);
        float growth = 1.14;
        float unit = reach * (growth - 1.0) / max(pow(growth, float(SUN_OCCLUSION_STEPS)) - 1.0, 0.001);

        vec3 stepDir = normalize(lightDir);
        float startPhase = fract(dither + float(frameCounter) * 0.61803398875);
        vec3 p = pos + normal * SUN_OCCLUSION_BIAS + stepDir * (unit * startPhase);
        float travelled = unit * startPhase;

        float visible = 1.0;
        for (int i = 0; i < SUN_OCCLUSION_STEPS; ++i) {
            float stepLen = unit * pow(growth, float(i));
            p += stepDir * stepLen;
            travelled += stepLen;
            if (travelled > reach) break;

            vec4 clip = projMatrix * vec4(p, 1.0);
            if (clip.w <= 0.0) break;

            vec2 uvS = clip.xy / clip.w * 0.5 + 0.5;
            if (uvS.x < 0.0 || uvS.x > 1.0 || uvS.y < 0.0 || uvS.y > 1.0) break;

            vec2 occluderInfo = c2_occluder_info(uvS);
            float occluder = occluderInfo.x;
            if (occluder > 0.0) {
                float typeWeight = occluderInfo.y < 1.5 ? vanillaWeight : lodWeight;
                float rayDist = -p.z;
                float zDelta = rayDist - occluder;
                float bias = SUN_OCCLUSION_BIAS + rayDist * 0.004;
                float softWidth = max(0.35, 1.5 * SUN_OCCLUSION_SOFTNESS + rayDist * 0.01);
                float maxFront = stepLen * 1.5 + bias + 0.5;
                float blocked = smoothstep(bias, bias + softWidth, zDelta) *
                    (1.0 - smoothstep(maxFront, maxFront + max(softWidth, stepLen * 0.5), zDelta)) *
                    typeWeight;
                visible *= 1.0 - blocked;
            }
        }
        return visible;
    }
#endif

void main() {
    vec4 blockColor = texture2DLod(colortex1, texcoord, 0);

#ifdef YDREAM_C2_DEPTH
    vec2 ps = vec2(pixelSizeX, pixelSizeY);
    float vanillaDepthHere = texture2DLod(depthtex1, texcoord, 0.0).r;
#endif

#ifdef YDREAM_C2_DH_SHADOWS
    float dhRawDepth = texture2DLod(dhDepthTex1, texcoord, 0.0).r;
    vec3 dhViewPos = c2_view_from_depth(dhProjectionInverse, c2_ndc_unjittered(texcoord), dhRawDepth);

    vec3 dhDx = dFdx(dhViewPos);
    vec3 dhDy = dFdy(dhViewPos);
    vec3 dhNormal = cross(dhDx, dhDy);
    float dhNormalLength = length(dhNormal);
    dhNormal = dhNormalLength > 1e-8 ? dhNormal / dhNormalLength : vec3(0.0, 0.0, 1.0);
    if (dot(dhNormal, dhViewPos) > 0.0) dhNormal = -dhNormal;

    if (vanillaDepthHere >= 0.9999 && dhRawDepth < 0.999999) {
        float dhDistance = length(dhViewPos);
        float gbufferRange = min(float(DH_SHADOW_DISTANCE), shadowDistance);
        float rangeWeight = smoothstep(gbufferRange * 0.72, gbufferRange * 0.94, dhDistance);

        vec3 sunDir = normalize(sunPosition);
        float facing = clamp(dot(dhNormal, sunDir), 0.0, 1.0);
        float weight = rangeWeight * facing * YDREAM_DH_SS_DIRECT_SHARE;

        if (weight > 0.001) {
            float dither = shiftedRDither(gl_FragCoord.xy);
            float visibility = c2_sun_visibility(dhViewPos, dhNormal, sunDir, dither, dhProjection, float(SUN_OCCLUSION_VANILLA_BLOCKS_LOD), float(SUN_OCCLUSION_LOD_BLOCKS_LOD));
            blockColor.rgb *= mix(1.0, visibility, weight);
        }
    }
#endif

#ifdef YDREAM_C2_SUN_OCCLUSION
    vec3 vanillaViewPos = c2_view_from_depth(gbufferProjectionInverse, c2_ndc_unjittered(texcoord), vanillaDepthHere);
    vec3 vDx = dFdx(vanillaViewPos);
    vec3 vDy = dFdy(vanillaViewPos);
    vec3 vanillaNormal = cross(vDx, vDy);
    float vnLen = length(vanillaNormal);
    vanillaNormal = vnLen > 1e-8 ? vanillaNormal / vnLen : vec3(0.0, 0.0, 1.0);
    if (dot(vanillaNormal, vanillaViewPos) > 0.0) vanillaNormal = -vanillaNormal;

    vec4 sunData = texture2DLod(colortex5, texcoord, 0.0);

    if (vanillaDepthHere < 0.9999 && sunData.a > 0.5) {
        vec3 sunDir = normalize(sunPosition);
        float facingDot = dot(vanillaNormal, sunDir);

        if (facingDot >= SUN_OCCLUSION_ANGULAR_GATE) {
            float vanillaDistance = length(vanillaViewPos);
            float fadeStart = shadowDistance * SUN_OCCLUSION_FADE_START;
            float fadeEnd = shadowDistance * SUN_OCCLUSION_FADE_END;
            float rangeWeight = smoothstep(fadeStart, fadeEnd, vanillaDistance);

            if (rangeWeight > 0.001) {
                float dither = shiftedRDither(gl_FragCoord.xy);
                float visibility = c2_sun_visibility(vanillaViewPos, vanillaNormal, sunDir, dither, gbufferProjection, float(SUN_OCCLUSION_VANILLA_BLOCKS_VANILLA), float(SUN_OCCLUSION_LOD_BLOCKS_VANILLA));
                vec3 removed = sunData.rgb * ((1.0 - visibility) * rangeWeight);
                blockColor.rgb = max(blockColor.rgb - removed, vec3(0.0));
            }
        }
    }
#endif

#ifdef YDREAM_C2_DEPTH
    float motionDepth = vanillaDepthHere;
    float motionDistance = 1e4;
    float motionLod = 0.0;
    float isSky = 1.0;

    if (vanillaDepthHere < 0.9999) {
        motionDistance = c2_linear_distance(texcoord, vanillaDepthHere, gbufferProjectionInverse);
        isSky = 0.0;
    } else {
        #ifdef DISTANT_HORIZONS
            float lodDepthHere = texture2DLod(dhDepthTex1, texcoord, 0.0).r;
            if (lodDepthHere < 0.999999) {
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