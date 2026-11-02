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

// Screen-space shadow trace for the LOD terrain. The steps grow geometrically
// (see c2_dh_sun_visibility) so the whole DH_SHADOW_REACH is covered with a
// small number of taps, and the whole ray is dithered per pixel and per frame so
// the bands average out instead of forming fixed screen-space stripes.
#define YDREAM_DH_SS_STEPS 24
// Share of a LOD pixel's colour that comes from direct sunlight. Only this share
// is darkened by the traced shadow, the rest is sky and block light.
#define YDREAM_DH_SS_DIRECT_SHARE 0.6

uniform sampler2D colortex1;

#if AA_TYPE > 0
    uniform sampler2D colortex3;
#endif

#if AA_TYPE > 0 || defined YDREAM_C2_DH_SHADOWS
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

// The projection matrices are unjittered: jitter is applied manually in the
// vertex shaders. Reprojection therefore removes the current jitter before
// reconstructing the surface, then restores the previous jitter only when
// looking up the previous frame's raster-space history.

#ifdef DISTANT_HORIZONS
    uniform sampler2D dhDepthTex1;
    uniform mat4 dhProjection;
    uniform mat4 dhProjectionInverse;
    uniform mat4 dhPreviousProjection;
#endif

#ifdef YDREAM_C2_DH_SHADOWS
    uniform vec3 sunPosition;
#endif

varying vec2 texcoord;

#ifdef YDREAM_C2_DEPTH
    #include "/lib/projection_utils.glsl"
#endif

#if defined MOTION_BLUR || defined YDREAM_C2_DH_SHADOWS
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

    // Same, for a uv that is already unjittered (the screen-space shadow trace
    // projects the ray with the unjittered dhProjection).
    float c2_linear_distance_raw(vec2 uv, float depth, mat4 projInv) {
        return -c2_view_from_depth(projInv, uv * 2.0 - 1.0, depth).z;
    }

    // Previous unjittered screen position of a point seen at the given current
    // unjittered NDC. The caller adds taaOffsetPrevious only when sampling the
    // previous frame's jittered history buffer. isSky selects a rotation-only
    // reprojection, because a point at infinity does not move with camera translation.
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
                // DH vertices use gbufferModelView for view/player conversion
                // and dhProjection only for projection (see position_vertex_dh.glsl).
                // Reconstruct with the matching inverse and use the previous
                // gbuffer model-view plus DH's previous projection.
                vec4 lodPlayerPos = gbufferModelViewInverse * vec4(lodView, 1.0);
                vec3 lodRel = lodPlayerPos.xyz / lodPlayerPos.w
                    + cameraPosition - previousCameraPosition;
                vec4 lodPrevView = gbufferPreviousModelView * vec4(lodRel, 1.0);
                vec4 lodPrevClip = dhPreviousProjection * lodPrevView;
                if (abs(lodPrevClip.w) < 1e-6) {
                    return vec2(-10.0);
                }
                return lodPrevClip.xy / lodPrevClip.w * 0.5 + 0.5;
            }
        #endif

        vec3 viewPos = c2_view_from_depth(gbufferProjectionInverse, ndc, depth);

        // Convert the point (not a direction) through the complete matrices.
        // mat3() discards the eye/player-space translations in both matrices,
        // so current and previous transforms no longer cancel when the camera
        // is stationary. That creates a false motion vector on static terrain.
        vec4 playerPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
        vec3 worldRel = playerPos.xyz / playerPos.w
            + cameraPosition - previousCameraPosition;
        vec4 prevViewPos = gbufferPreviousModelView * vec4(worldRel, 1.0);
        vec4 prevClip = gbufferPreviousProjection * prevViewPos;
        if (abs(prevClip.w) < 1e-6) {
            return vec2(-10.0);
        }
        return prevClip.xy / prevClip.w * 0.5 + 0.5;
    }
#endif

#ifdef YDREAM_C2_DH_SHADOWS
    // Distance of the nearest occluder at an unjittered uv (vanilla first, then
    // LOD), or -1.
    float c2_occluder_distance(vec2 uv) {
        float vanillaDepth = texture2DLod(depthtex1, uv, 0.0).r;
        if (vanillaDepth < 0.9999) {
            return c2_linear_distance_raw(uv, vanillaDepth, gbufferProjectionInverse);
        }
        float lodDepth = texture2DLod(dhDepthTex1, uv, 0.0).r;
        if (lodDepth < 0.999999) {
            return c2_linear_distance_raw(uv, lodDepth, dhProjectionInverse);
        }
        return -1.0;
    }

    // Screen-space shadow ray towards the sun, in DH view space. The steps grow
    // geometrically so the near cells are sampled finely while the ray still
    // reaches DH_SHADOW_REACH, which is what lets a whole mountain block the sun
    // instead of only the few blocks covered by the old fixed 60-block slab.
    float c2_dh_sun_visibility(vec3 pos, vec3 normal, vec3 lightDir, float dither) {
        float reach = float(DH_SHADOW_REACH);
        float growth = 1.14;
        // Normalise the progression so the last sample lands exactly on reach.
        float unit = reach * (growth - 1.0) / max(pow(growth, float(YDREAM_DH_SS_STEPS)) - 1.0, 0.001);

        vec3 stepDir = normalize(lightDir);
        // Dithered start: a per-pixel offset hides the step bands, and the
        // golden-ratio frame term lets the temporal filter average them out.
        float startPhase = fract(dither + float(frameCounter) * 0.61803398875);
        vec3 p = pos + normal * 0.05 + stepDir * (unit * startPhase);
        float travelled = unit * startPhase;

        float visible = 1.0;
        for (int i = 0; i < YDREAM_DH_SS_STEPS; ++i) {
            float stepLen = unit * pow(growth, float(i));
            p += stepDir * stepLen;
            travelled += stepLen;
            if (travelled > reach) {
                break;
            }

            vec4 clip = dhProjection * vec4(p, 1.0);
            if (clip.w <= 0.0) {
                break; // behind the camera
            }

            vec2 uvS = clip.xy / clip.w * 0.5 + 0.5;
            if (uvS.x < 0.0 || uvS.x > 1.0 || uvS.y < 0.0 || uvS.y > 1.0) {
                break;
            }

            float occluder = c2_occluder_distance(uvS);
            if (occluder > 0.0) {
                float rayDist = -p.z;
                float zDelta = rayDist - occluder;
                float bias = 0.15 + rayDist * 0.004;
                float softWidth = max(0.35, 1.5 * DH_SHADOW_SOFTNESS + rayDist * 0.01);
                // The ray can step over the point where it enters an occluder, so
                // a surface up to ~1.5 steps in front of the current sample has
                // to count. The old window was a fixed 4 blocks: far away a
                // 20-40 block step jumped deep inside a mountain and the hit was
                // rejected, which is why mountains never cast a shadow. The
                // window still grows with the step, so unrelated foreground
                // geometry remains rejected.
                float maxFront = stepLen * 1.5 + bias + 0.5;
                float blocked = smoothstep(bias, bias + softWidth, zDelta) *
                    (1.0 - smoothstep(maxFront, maxFront + max(softWidth, stepLen * 0.5), zDelta));
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
        // The shadow map stops at gbufferRange and solid_dh_blocks_fragment fades
        // its contribution out over the last quarter of that range. Fade this
        // trace in over the same interval so the two do not double-darken the
        // LOD pixels that both can reach. Past that point the trace stays at full
        // strength: its reach is measured along the ray towards the light, not
        // away from the camera, so a distant LOD fragment can still be shadowed
        // by a mountain that is closer to the camera than it is.
        float gbufferRange = min(float(DH_SHADOW_DISTANCE), shadowDistance);
        float rangeWeight = smoothstep(gbufferRange * 0.72, gbufferRange * 0.94, dhDistance);

        vec3 sunDir = normalize(sunPosition);
        float facing = clamp(dot(dhNormal, sunDir), 0.0, 1.0);
        float weight = rangeWeight * facing * YDREAM_DH_SS_DIRECT_SHARE;

        if (weight > 0.001) {
            float dither = shiftedRDither(gl_FragCoord.xy);
            float visibility = c2_dh_sun_visibility(dhViewPos, dhNormal, sunDir, dither);
            blockColor.rgb *= mix(1.0, visibility, weight);
        }
    }
#endif

#ifdef YDREAM_C2_DEPTH
    // Reproject the depth belonging to this exact output pixel. Do not select a
    // nearer depth from neighbouring pixels: that gives this pixel another
    // surface's motion and can make the history lookup jump by several texels.
    float motionDepth = vanillaDepthHere;
    float motionDistance = 1e4;
    float motionLod = 0.0;
    float isSky = 1.0;

    if (vanillaDepthHere < 0.9999) {
        motionDistance = c2_linear_distance(
            texcoord, vanillaDepthHere, gbufferProjectionInverse);
        isSky = 0.0;
    } else {
        #ifdef DISTANT_HORIZONS
            float lodDepthHere = texture2DLod(dhDepthTex1, texcoord, 0.0).r;
            if (lodDepthHere < 0.999999) {
                motionDepth = lodDepthHere;
                motionDistance = c2_linear_distance(
                    texcoord, lodDepthHere, dhProjectionInverse);
                motionLod = 1.0;
                isSky = 0.0;
            }
        #endif
    }

    // The depth sample is from the jittered raster position. Undo this frame's
    // jitter before reconstructing the 3D point and projecting it into the past.
    vec2 currentUnjitteredUV = texcoord - 0.5 * taaOffset;
    vec2 currentUnjitteredNDC = c2_ndc_unjittered(texcoord);
    vec2 previousUnjitteredUV = c2_previous_uv(
        currentUnjitteredNDC, motionDepth, motionLod, isSky);

    // Physical motion excludes the temporal sample pattern.
    vec2 motion = previousUnjitteredUV - currentUnjitteredUV;

    // History is stored at the previous frame's raster position, so restore
    // that frame's jitter only for the history lookup.
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
    taa_resolve(blockColor.rgb, texcoord, previousUV, previousValid, historyAge, motionDistance,
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
