// The wrappers define NO_SHADOWS, but the Distant Horizons shadow range needs
// shadowDistance from the config. This pass declares no shadow samplers, so
// enabling the shadow constants here is safe.
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
/*
const int colortex3Format = RGBA16F;
*/
const bool gaux1Clear = false;
const bool gaux2Clear = false;
const bool gaux3Clear = false;
const bool gaux4Clear = false;

// Distant Horizons shadows: the LOD terrain is not in the shadow map beyond the
// shadow map range, so its sunlight beyond that range is traced in screen space.
#if defined DISTANT_HORIZONS && DH_SHADOWS == 1 && !defined NETHER
    #define YDREAM_C2_DH_SHADOWS
#endif

// Any pass that needs the depth buffer and the matrices of this frame and the
// previous one.
#if AA_TYPE > 0 || defined MOTION_BLUR || defined YDREAM_C2_DH_SHADOWS
    #define YDREAM_C2_DEPTH
#endif

// Number of screen-space steps taken towards the sun for each LOD pixel.
#define YDREAM_DH_SS_STEPS 16
// Share of a LOD pixel's colour that comes from direct sunlight. Only this share
// is darkened by the traced shadow, the rest is sky and block light.
#define YDREAM_DH_SS_DIRECT_SHARE 0.6

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
    uniform mat4 dhModelViewInverse;
    uniform mat4 dhPreviousModelView;
    uniform mat4 dhPreviousProjection;
#endif

#ifdef YDREAM_C2_DH_SHADOWS
    uniform vec3 sunPosition;
#endif

varying vec2 texcoord;

#ifdef YDREAM_C2_DEPTH
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

#ifdef YDREAM_C2_DEPTH
    // Unjittered NDC of a screen position. The vertex stage added taaOffset in NDC,
    // so the offset is removed here before any reconstruction.
    vec2 c2_ndc_unjittered(vec2 uv) {
        return uv * 2.0 - 1.0 - taaOffset;
    }

    // View-space position of a depth sample, given its unjittered NDC.
    vec3 c2_view_from_depth(mat4 projInv, vec2 ndc, float depth) {
        vec4 viewPos = projInv * vec4(ndc, depth * 2.0 - 1.0, 1.0);
        return viewPos.xyz / viewPos.w;
    }

    // Distance along the view axis of the vanilla or LOD depth at uv.
    float c2_linear_distance(vec2 uv, float depth, mat4 projInv) {
        return -c2_view_from_depth(projInv, c2_ndc_unjittered(uv), depth).z;
    }

    // Closest sample search. Vanilla geometry always wins over LOD, which only
    // fills the pixels where the vanilla depth buffer has no geometry.
    void c2_consider(
        vec2 uv,
        inout float bestScore,
        inout vec2 bestUV,
        inout float bestDist,
        inout float bestDepth,
        inout float bestLod
    ) {
        float vanillaDepth = texture2DLod(depthtex1, uv, 0.0).r;
        float score;
        float dist;
        float depth;
        float lod;

        if (vanillaDepth < 0.9999) {
            depth = vanillaDepth;
            dist = c2_linear_distance(uv, vanillaDepth, gbufferProjectionInverse);
            score = dist;
            lod = 0.0;
        } else {
            #ifdef DISTANT_HORIZONS
                float lodDepth = texture2DLod(dhDepthTex1, uv, 0.0).r;
                if (lodDepth >= 0.999999) {
                    return;
                }
                depth = lodDepth;
                dist = c2_linear_distance(uv, lodDepth, dhProjectionInverse);
                score = 1e6 + dist;
                lod = 1.0;
            #else
                return;
            #endif
        }

        if (score < bestScore) {
            bestScore = score;
            bestUV = uv;
            bestDist = dist;
            bestDepth = depth;
            bestLod = lod;
        }
    }

    // Unjittered screen position, in the previous frame, of a point seen at the
    // given unjittered NDC. isSky selects a rotation-only reprojection, because a
    // point at infinity does not move with the camera translation.
    vec2 c2_previous_uv(vec2 ndc, float depth, float isLod, float isSky) {
        if (isSky > 0.5) {
            vec4 dirClip = gbufferProjectionInverse * vec4(ndc, 1.0, 1.0);
            vec3 viewDir = normalize(dirClip.xyz / dirClip.w);
            vec3 worldDir = mat3(gbufferModelViewInverse) * viewDir;
            vec3 prevDir = mat3(gbufferPreviousModelView) * worldDir;
            vec4 prevClip = gbufferPreviousProjection * vec4(prevDir, 0.0);
            if (abs(prevClip.w) < 1e-6) {
                return vec2(-10.0);
            }
            return prevClip.xy / prevClip.w * 0.5 + 0.5;
        }

        #ifdef DISTANT_HORIZONS
            if (isLod > 0.5) {
                vec3 lodView = c2_view_from_depth(dhProjectionInverse, ndc, depth);
                // The 3x3 part of the inverse model-view is a pure rotation, so
                // this stays valid whatever translation the engine uses.
                vec3 lodRel = mat3(dhModelViewInverse) * lodView + cameraPosition - previousCameraPosition;
                vec3 lodPrevView = mat3(dhPreviousModelView) * lodRel;
                vec4 lodPrevClip = dhPreviousProjection * vec4(lodPrevView, 1.0);
                if (abs(lodPrevClip.w) < 1e-6) {
                    return vec2(-10.0);
                }
                return lodPrevClip.xy / lodPrevClip.w * 0.5 + 0.5;
            }
        #endif

        vec3 viewPos = c2_view_from_depth(gbufferProjectionInverse, ndc, depth);
        vec3 worldRel = mat3(gbufferModelViewInverse) * viewPos + cameraPosition - previousCameraPosition;
        vec3 prevViewPos = mat3(gbufferPreviousModelView) * worldRel;
        vec4 prevClip = gbufferPreviousProjection * vec4(prevViewPos, 1.0);
        if (abs(prevClip.w) < 1e-6) {
            return vec2(-10.0);
        }
        return prevClip.xy / prevClip.w * 0.5 + 0.5;
    }
#endif

#ifdef YDREAM_C2_DH_SHADOWS
    // Distance of the nearest occluder at uv (vanilla first, then LOD), or -1.
    float c2_occluder_distance(vec2 uv) {
        float vanillaDepth = texture2DLod(depthtex1, uv, 0.0).r;
        if (vanillaDepth < 0.9999) {
            return c2_linear_distance(uv, vanillaDepth, gbufferProjectionInverse);
        }
        float lodDepth = texture2DLod(dhDepthTex1, uv, 0.0).r;
        if (lodDepth < 0.999999) {
            return c2_linear_distance(uv, lodDepth, dhProjectionInverse);
        }
        return -1.0;
    }

    // Screen-space shadow ray towards the sun. Steps grow geometrically, so the
    // trace covers the full DH_SHADOW_DISTANCE with a fixed step count.
    float c2_dh_sun_visibility(vec3 pos, vec3 normal, vec3 lightDir, float dist) {
        vec3 origin = pos + normal * (0.05 + dist * 0.005);
        float tStart = max(1.0, dist * 0.02);
        float tEnd = max(float(DH_SHADOW_DISTANCE), tStart * 2.0);
        float ratio = tEnd / tStart;

        float visible = 1.0;
        for (int i = 0; i < YDREAM_DH_SS_STEPS; ++i) {
            float t = tStart * pow(ratio, float(i) / float(YDREAM_DH_SS_STEPS - 1));
            vec3 p = origin + lightDir * t;
            if (p.z > -0.05) {
                break; // behind the camera
            }

            vec4 clip = dhProjection * vec4(p, 1.0);
            vec2 uvS = clip.xy / clip.w * 0.5 + 0.5;
            if (any(lessThan(uvS, vec2(0.0))) || any(greaterThan(uvS, vec2(1.0)))) {
                break;
            }

            float occluder = c2_occluder_distance(uvS);
            float rayDist = -p.z;
            // The occluder must be in front of the ray, within a thickness that
            // grows with distance (LOD cells are coarse at range).
            if (occluder > 0.0 && occluder < rayDist - 0.05
                && rayDist - occluder < rayDist * 0.15 + 3.0) {
                visible = 0.0;
                break;
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
    // Sunlight on LOD terrain beyond the shadow map. The gbuffer already applies
    // the shadow map inside its range; this pass continues it outwards.
    float dhRawDepth = texture2DLod(dhDepthTex1, texcoord, 0.0).r;
    vec3 dhViewPos = c2_view_from_depth(dhProjectionInverse, c2_ndc_unjittered(texcoord), dhRawDepth);

    // Derivatives are taken before the branch below, so every lane of the quad
    // takes part in them.
    vec3 dhDx = dFdx(dhViewPos);
    vec3 dhDy = dFdy(dhViewPos);
    vec3 dhNormal = cross(dhDx, dhDy);
    float dhNormalLength = length(dhNormal);
    dhNormal = dhNormalLength > 1e-8 ? dhNormal / dhNormalLength : vec3(0.0, 0.0, 1.0);
    if (dot(dhNormal, dhViewPos) > 0.0) {
        dhNormal = -dhNormal;
    }

    if (vanillaDepthHere >= 0.9999 && dhRawDepth < 0.999999) {
        float dhDistance = length(dhViewPos);
        float gbufferRange = min(float(DH_SHADOW_DISTANCE), shadowDistance);
        float dhFarRange = float(DH_SHADOW_DISTANCE);

        // Fades in where the gbuffer shadow map ends, and out at the chosen range.
        float rangeWeight = smoothstep(gbufferRange, gbufferRange + max(gbufferRange * 0.1, 8.0), dhDistance)
            * (1.0 - smoothstep(dhFarRange * 0.85, dhFarRange, dhDistance));

        vec3 sunDir = normalize(sunPosition);
        float facing = clamp(dot(dhNormal, sunDir), 0.0, 1.0);
        float weight = rangeWeight * facing * YDREAM_DH_SS_DIRECT_SHARE;

        if (weight > 0.001) {
            float visibility = c2_dh_sun_visibility(dhViewPos, dhNormal, sunDir, dhDistance);
            blockColor.rgb *= mix(1.0, visibility, weight);
        }
    }
#endif

#ifdef YDREAM_C2_DEPTH
    // Closest fragment in a 5-sample cross. Its motion is used for the whole pixel,
    // so thin geometry does not smear into the sky around it.
    float bestScore = 1e9;
    vec2 bestUV = texcoord;
    float bestDist = 1e4;
    float bestDepth = 1.0;
    float bestLod = 0.0;

    c2_consider(texcoord, bestScore, bestUV, bestDist, bestDepth, bestLod);
    c2_consider(texcoord + vec2(-2.0, -2.0) * ps, bestScore, bestUV, bestDist, bestDepth, bestLod);
    c2_consider(texcoord + vec2(2.0, -2.0) * ps, bestScore, bestUV, bestDist, bestDepth, bestLod);
    c2_consider(texcoord + vec2(-2.0, 2.0) * ps, bestScore, bestUV, bestDist, bestDepth, bestLod);
    c2_consider(texcoord + vec2(2.0, 2.0) * ps, bestScore, bestUV, bestDist, bestDepth, bestLod);

    float isSky = bestScore > 1e8 ? 1.0 : 0.0;

    // Previous unjittered position of the closest sample, and its motion.
    vec2 previousClosest = c2_previous_uv(c2_ndc_unjittered(bestUV), bestDepth, bestLod, isSky);
    vec2 motion = previousClosest - (bestUV - 0.5 * taaOffset);

    // Previous position of this pixel, including the jitter of both frames.
    vec2 previousUV = texcoord + motion + 0.5 * (taaOffsetPrevious - taaOffset);

    #if AA_TYPE > 0 || defined MOTION_BLUR
        float zDepth = vanillaDepthHere;
    #endif

    #ifdef MOTION_BLUR
        #if AA_TYPE > 0
            float dither = shiftedDitherMakeup(gl_FragCoord.xy);
        #else
            float dither = ditherMakeup(gl_FragCoord.xy);
        #endif

        // The motion vector is unjittered: current position minus previous position.
        vec2 velocity = -motion;
        blockColor.rgb = motionBlur(blockColor.rgb, zDepth, velocity, dither, colortex1);
    #endif
#endif

#if AA_TYPE > 0
    bool previousValid = frameCounter >= 2
        && previousUV.x >= 0.0 && previousUV.y >= 0.0
        && previousUV.x <= 1.0 && previousUV.y <= 1.0;

    // The age is read at the texel that holds the reprojected pixel, so the
    // history is never blended with the age of a neighbouring pixel.
    vec2 res = vec2(1.0 / pixelSizeX, 1.0 / pixelSizeY);
    vec2 historyTexel = (floor(previousUV * res) + 0.5) / res;
    float historyAge = texture2DLod(colortex3, historyTexel, 0.0).a * TAA_MAX_AGE;

    blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));

    vec3 outLinear;
    vec3 outHistory;
    float outAge;
    taa_resolve(blockColor.rgb, texcoord, previousUV, previousValid, historyAge, bestDist,
        outLinear, outHistory, outAge);

    /* DRAWBUFFERS:13 */
    #if YDREAM_TAA_DEBUG == 0
        gl_FragData[0] = vec4(outLinear, blockColor.a);
    #else
        // Debug view: what is shown on screen. The history is still written
        // unchanged, so the accumulation itself is not affected.
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
