#include "/lib/config.glsl"

#if defined THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

uniform float viewWidth;
uniform float viewHeight;
uniform vec3 sunPosition;
uniform int isEyeInWater;
uniform float dayNightMix;
uniform float far;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;
uniform mat4 gbufferProjectionInverse;

#ifdef DISTANT_HORIZONS
    uniform int dhRenderDistance;
#endif

#ifdef VOXY
    uniform int vxRenderDistance;
#endif

#ifdef DYN_HAND_LIGHT
    uniform int heldItemId;
    uniform int heldItemId2;
#endif

#ifdef UNKNOWN_DIM
    uniform sampler2D lightmap;
#endif

uniform mat4 gbufferModelView;

#ifdef CLOUD_SHADOWS_ON
    #define CLOUD_SHADOW_APPLY
    uniform sampler2D gaux2;
#endif

#if defined FOLIAGE_V || defined SHADOW_CASTING || (defined MATERIAL_GLOSS && !defined NETHER) || defined GROUND_FOG_ON || defined NETHER_HEIGHT_FOG || defined CLOUD_SHADOWS_ON || defined WETNESS_EFFECTS_ON
    uniform mat4 gbufferModelViewInverse;
#endif

#if defined MATERIAL_GLOSS && !defined NETHER
    uniform int worldTime;
    uniform vec3 moonPosition;
#endif

#if defined SHADOW_CASTING && !defined NETHER
    uniform mat4 shadowModelView;
    uniform mat4 shadowProjection;
    uniform vec3 shadowLightPosition;
#endif

#if WAVING == 1 || defined GROUND_FOG_ON || defined NETHER_HEIGHT_FOG || defined CLOUD_SHADOWS_ON || defined WETNESS_EFFECTS_ON
    uniform vec3 cameraPosition;
#endif

#if WAVING == 1 || defined CLOUD_SHADOWS_ON
    uniform float frameTimeCounter;
#endif

#if defined IS_IRIS && defined THE_END && MC_VERSION >= 12109
    uniform float endFlashIntensity;
#endif

#if defined GBUFFER_ENTITIES
    uniform int entityId;
#endif

varying vec2 texcoord;
varying vec4 tintColor;
varying float frogAdjust;
varying float fogSunScatter;
varying vec3 directLightColor;
varying vec3 candleColor;
varying float directLightStrength;
varying vec3 omniLight;

#if defined SHADOW_CASTING && SHADOW_LOCK > 0 && !defined NETHER
    varying vec3 vWorldPos;
    varying vec3 vNormal;
    varying vec3 vBias;
#endif

#if defined GBUFFER_TERRAIN || defined GBUFFER_HAND || defined GBUFFER_ENTITIES
    varying float isEmissiveEntity;
    #if defined GBUFFER_TERRAIN && GLEAM_VOXEL_LIGHT > 0
        varying vec3 emitterTint;
    #endif
#endif

#ifdef FOLIAGE_V
    varying float isFoliage;
    varying float foliageBackscatter;
#endif

#if defined GBUFFER_TERRAIN && EMISSIVE_ORES == 1
    varying float isOre;
#endif

#if defined SHADOW_CASTING && !defined NETHER
    varying vec3 shadowPos;
    varying float shadowDiffuse;
#endif

#if defined MATERIAL_GLOSS && !defined NETHER
    varying vec3 flatNormal;
    varying vec3 viewPositionNormalized;
    varying vec2 lmcoordAlt;
    varying float glossFactor;
    varying float glossPower;
    varying float lumaFactor;
    varying float lumaPower;
#endif

attribute vec4 mc_Entity;

#ifdef PBR_ACTIVE
    attribute vec4 at_tangent;
    varying vec3 pbrTangent;
    varying vec3 pbrBitangent;
    varying vec3 pbrNormal;
    varying vec3 pbrViewPos;
#endif

#if WAVING == 1 || defined POM_ACTIVE
    attribute vec2 mc_midTexCoord;
#endif

#ifdef POM_ACTIVE
    varying vec2 pomTexMid;
    varying vec2 pomTexHalf;
#endif

#ifdef WETNESS_EFFECTS_ON
    varying float skyExposure;
#endif

#if AA_TYPE > 0
    #include "/src/taa_offset.glsl"
#endif

#include "/lib/basic_utils.glsl"

#if defined SHADOW_CASTING && !defined NETHER
    #include "/lib/shadow_vertex.glsl"
#endif

#if WAVING == 1
    #include "/lib/vector_utils.glsl"
#endif

#include "/lib/luma.glsl"

void main() {
    vec2 eyeBrightSmoothFloat = vec2(eyeBrightnessSmooth);
    vec3 zenithSkyColor;
    float visibleSky;

    #include "/src/basiccoords_vertex.glsl"
    #include "/src/position_vertex.glsl"
    #include "/src/hi_sky.glsl"
    #include "/src/light_vertex.glsl"
    #include "/src/fog_vertex.glsl"

    #ifdef PBR_ACTIVE
        vec3 pbrGeoNormal = gl_NormalMatrix * gl_Normal;
        float pbrNormalLength = dot(pbrGeoNormal, pbrGeoNormal);
        pbrGeoNormal = pbrNormalLength > 0.0001 ? pbrGeoNormal * inversesqrt(pbrNormalLength) : vec3(0.0, 1.0, 0.0);
        vec3 pbrFallbackAxis = abs(pbrGeoNormal.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        vec3 pbrTangentDir = normalize(cross(pbrGeoNormal, pbrFallbackAxis));
        float pbrHandedness = 1.0;

        #if defined GBUFFER_TERRAIN
            vec3 pbrRawTangent = gl_NormalMatrix * at_tangent.xyz;
            float pbrTangentLength = dot(pbrRawTangent, pbrRawTangent);
            if (pbrTangentLength > 0.0001) {
                pbrTangentDir = pbrRawTangent * inversesqrt(pbrTangentLength);
                pbrHandedness = at_tangent.w < 0.0 ? -1.0 : 1.0;
            }
        #endif

        pbrTangent = pbrTangentDir;
        pbrBitangent = cross(pbrTangentDir, pbrGeoNormal) * pbrHandedness;
        pbrNormal = pbrGeoNormal;
        pbrViewPos = viewPosition.xyz;
    #endif

    #ifdef POM_ACTIVE
        pomTexMid = (gl_TextureMatrix[0] * vec4(mc_midTexCoord, 0.0, 1.0)).xy;
        pomTexHalf = abs(texcoord - pomTexMid);
    #endif

    #ifdef WETNESS_EFFECTS_ON
        skyExposure = visibleSky;
    #endif

    #if defined GBUFFER_TERRAIN || defined GBUFFER_HAND || defined GBUFFER_ENTITIES
        isEmissiveEntity = 0.0;
        if(mc_Entity.x == ENTITY_NO_SHADOW_FIRE || mc_Entity.x == ENTITY_EMMISIVE || mc_Entity.x == ENTITY_S_EMMISIVE || (mc_Entity.x >= ENTITY_E_SOUL && mc_Entity.x <= ENTITY_E_VOID)) {
            isEmissiveEntity = 1.0;
        }
    #endif

    #if defined GBUFFER_TERRAIN && GLEAM_VOXEL_LIGHT > 0
        emitterTint = vec3(0.0);
        if (mc_Entity.x == ENTITY_EMMISIVE || mc_Entity.x == ENTITY_S_EMMISIVE || mc_Entity.x == ENTITY_NO_SHADOW_FIRE) {
            emitterTint = vec3(1.0, 0.60, 0.26);
        } else if (mc_Entity.x == ENTITY_E_SOUL || mc_Entity.x == ENTITY_F_EMMISIVE) {
            emitterTint = vec3(0.22, 0.70, 1.0);
        } else if (mc_Entity.x == ENTITY_E_REDSTONE) {
            emitterTint = vec3(1.0, 0.16, 0.08);
        } else if (mc_Entity.x == ENTITY_E_SEA) {
            emitterTint = vec3(0.55, 0.95, 1.0);
        } else if (mc_Entity.x == ENTITY_E_OCHRE) {
            emitterTint = vec3(1.0, 0.78, 0.28);
        } else if (mc_Entity.x == ENTITY_E_VERDANT) {
            emitterTint = vec3(0.45, 1.0, 0.38);
        } else if (mc_Entity.x == ENTITY_E_PEARL) {
            emitterTint = vec3(1.0, 0.52, 0.88);
        } else if (mc_Entity.x == ENTITY_E_VOID) {
            emitterTint = vec3(0.62, 0.38, 1.0);
        }
    #endif

    #if defined GBUFFER_TERRAIN && EMISSIVE_ORES == 1
        isOre = 0.0;
        if(mc_Entity.x == ENTITY_ORE) {
            isOre = 1.0;
        } else if(mc_Entity.x == ENTITY_ORE_BRIGHT) {
            isOre = 2.0;
        }
    #endif

    #if defined SHADOW_CASTING && !defined NETHER
        #include "/src/shadow_src_vertex.glsl"
    #endif

    #if defined FOLIAGE_V && !defined NETHER
        #ifdef SHADOW_CASTING
            if (isFoliage > .2) {
                directLightStrength =
                    mix(
                        directLightStrength,
                        farDirectLightStrength,
                        clamp((gl_Position.z / SHADOW_LIMIT) * 2.0 - 0.5, 0.0, 1.0)
                    );
            }
        #endif
    #endif

    #if defined MATERIAL_GLOSS && !defined NETHER
        lumaFactor = 1.0;
        lumaPower = 2.0;
        glossPower = 6.0;
        glossFactor = 1.05;

        if(mc_Entity.x == ENTITY_SAND) {
            lumaPower = 4.0;
        } else if(mc_Entity.x == ENTITY_METAL) {
            lumaFactor = 1.35;
            lumaPower = -1.0;
            glossPower = 100.0;
        } else if(mc_Entity.x == ENTITY_FABRIC) {
            glossPower = 3.0;
            glossFactor = 0.1;
        }

        flatNormal = normal;
        viewPositionNormalized = normalize(viewPosition.xyz);

        lmcoordAlt = lmcoord;
    #endif

    #if defined GBUFFER_ENTITY_GLOW
        gl_Position.z *= 0.01;
    #endif

    #if defined SHADOW_CASTING && SHADOW_LOCK > 0 && !defined NETHER
        vNormal = shadowWorldNormal;
        vBias = bias;
    #endif
}
