#include "/lib/config.glsl"

#if defined THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#endif

uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;
uniform sampler2D tex;
uniform int isEyeInWater;
uniform float nightVision;
uniform float rainStrength;
uniform float dayNightMix;
uniform float pixelSizeX;
uniform float pixelSizeY;
uniform sampler2D gaux4;

#if defined DISTANT_HORIZONS
    uniform float dhNearPlane;
    uniform float far;
#endif

#if defined GBUFFER_ENTITIES
    uniform int entityId;
    uniform vec4 entityColor;
#endif

#if defined SHADOW_CASTING
    uniform sampler2DShadow shadowtex1;
    #if defined COLORED_SHADOW
        uniform sampler2DShadow shadowtex0;
        uniform sampler2D shadowcolor0;
    #endif
#endif

uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
    uniform float darknessLightFactor;
#endif


#if (defined MATERIAL_GLOSS || defined PBR_ACTIVE) && !defined NETHER
    uniform int worldTime;
    uniform vec3 moonPosition;
    uniform vec3 sunPosition;
#endif

#ifdef PBR_ACTIVE
    #if PBR_MODE == 1
        uniform sampler2D normals;
        uniform sampler2D specular;
    #endif
    varying vec3 pbrTangent;
    varying vec3 pbrBitangent;
    varying vec3 pbrNormal;
    varying vec3 pbrViewPos;
#endif

#ifdef POM_ACTIVE
    varying vec2 pomTexMid;
    varying vec2 pomTexHalf;
#endif

#ifdef WETNESS_EFFECTS_ON
    uniform float wetness;
    varying float skyExposure;
#endif

#if SHADOW_LOCK > 0 && defined SHADOW_CASTING
    uniform vec3 cameraPosition;
    uniform mat4 shadowModelView;
    uniform mat4 shadowProjection;
    uniform vec3 shadowLightPosition;
#endif

#if defined THE_END || (SHADOW_LOCK > 0 && defined SHADOW_CASTING && !defined NETHER)
    uniform mat4 gbufferModelView;
#endif

varying vec2 texcoord;
varying vec4 tintColor;
varying float frogAdjust;
varying float fogSunScatter;
#include "/lib/fog_blend.glsl"
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
    #if defined GBUFFER_TERRAIN && YDREAM_VOXEL_LIGHT > 0
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

#if (defined SHADOW_CASTING && !defined NETHER) || defined DISTANT_HORIZONS
    #include "/lib/dither.glsl"
#endif

#if defined SHADOW_CASTING && !defined NETHER
    #include "/lib/shadow_frag.glsl"
#endif

#include "/lib/luma.glsl"

#if defined PBR_ACTIVE && PBR_MODE == 1
    #include "/lib/labpbr.glsl"
#endif

#ifdef POM_ACTIVE
    #include "/lib/parallax.glsl"
#endif


#if defined MATERIAL_GLOSS && !defined NETHER
    #include "/lib/material_gloss_fragment.glsl"
#endif

#if defined SHADOW_CASTING && SHADOW_LOCK > 0 && !defined NETHER
    #include "/lib/shadow_vertex.glsl"
#endif

void main() {
    #if (defined SHADOW_CASTING && !defined NETHER) || defined DISTANT_HORIZONS
        #if AA_TYPE > 0
            float dither = shiftedDither13(gl_FragCoord.xy);
        #else
            float dither = dither17(gl_FragCoord.xy);
        #endif
    #endif

    #if defined DISTANT_HORIZONS && !defined GBUFFER_BEACONBEAM
        float t = far - dhNearPlane;
        float sup = t * TRANSITION_DH_SUP;
        float inf = t * TRANSITION_DH_INF;
        float umbral = (gl_FogFragCoord - (dhNearPlane + inf)) / (far - sup - inf - dhNearPlane);
        if(umbral > dither) {
            discard;
            return;
        }
    #endif

    #ifdef POM_ACTIVE
        float pomDistance = length(pbrViewPos);
        float pomFadeEnd = 20.0 + 12.0 * float(POM_QUALITY);
        float pomFade = 1.0 - smoothstep(pomFadeEnd * 0.5, pomFadeEnd, pomDistance);
        vec2 pomUV = pomOffset(texcoord, pomTexMid, pomTexHalf, pbrTangent, pbrBitangent, pbrNormal, pbrViewPos, pomFade);
    #else
        vec2 pomUV = texcoord;
    #endif

    #if defined GBUFFER_ENTITIES && BLACK_ENTITY_FIX == 1
        vec4 blockColor = texture2D(tex, pomUV);
        if(blockColor.a < 0.1 && entityId != 10101) {
            discard;
        }
        blockColor *= tintColor;
    #else
        vec4 blockColor = texture2D(tex, pomUV) * tintColor;
    #endif

    #if defined GBUFFER_ENTITIES
        vec4 originalEntityColor = blockColor;
    #endif

    #ifdef FOLIAGE_V
        if(isFoliage > 0.2) {
            float foliageLuma = luma(blockColor.rgb);
            blockColor.rgb = mix(vec3(foliageLuma), blockColor.rgb, FOLIAGE_SATURATION) * FOLIAGE_BRIGHTNESS;
        }
    #endif

    float block_luma = luma(blockColor.rgb);

    #if defined GBUFFER_TERRAIN && EMISSIVE_ORES == 1
        vec3 oreAlbedo = blockColor.rgb;
        float oreMask = 0.0;
        if(isOre > 0.5) {
            float oreChroma = max(max(oreAlbedo.r, oreAlbedo.g), oreAlbedo.b) - min(min(oreAlbedo.r, oreAlbedo.g), oreAlbedo.b);
            float orePeak = max(max(oreAlbedo.r, oreAlbedo.g), oreAlbedo.b);
            float coloredMask = smoothstep(0.62, 0.80, orePeak) * smoothstep(0.18, 0.32, oreChroma);
            float brightMask = smoothstep(0.74, 0.90, block_luma);
            oreMask = mix(coloredMask, brightMask, step(1.5, isOre));
        }
    #endif

    float isEmissiveEntityLocal = 0.0;
    #if defined GBUFFER_ENTITIES
        if (isEmissiveEntity > 0.5 || entityId == 10202) {
            isEmissiveEntityLocal = 1.0;
        }
    #endif

    #if defined GBUFFER_TERRAIN || defined GBUFFER_HAND
        vec3 emitAlbedo = blockColor.rgb;
        float emitPeak = max(max(emitAlbedo.r, emitAlbedo.g), emitAlbedo.b);
        float emitMask = isEmissiveEntity * smoothstep(0.22, 0.62, emitPeak) * (0.55 + 0.45 * smoothstep(0.3, 0.9, block_luma));
    #endif

    vec3 finalCandleColor = candleColor;
    #ifdef YDREAM_LIGHT_BUFFERS
        vec3 ydreamAlbedo = vec3(0.0);
        float ydreamCandleLuma = 0.0;
    #endif
    #if defined GBUFFER_TERRAIN || defined GBUFFER_HAND || defined GBUFFER_ENTITIES
        if(isEmissiveEntityLocal > 0.5) {
            finalCandleColor *= block_luma * EMISSIVE_STRENGTH;
        }
    #endif

    #ifdef GBUFFER_WEATHER
        blockColor.a *= 0.42 * RAIN_OPACITY;
        blockColor.rgb *= vec3(0.86, 0.93, 1.0);
    #endif

    #if defined GBUFFER_ENTITIES

        if(entityId == 10101) {
            blockColor.a = 1.0;
        }
    #endif

    #if defined SHADOW_CASTING && !defined NETHER
        #if SHADOW_LOCK > 0
            vec3 offsetVector = vNormal * 0.002;
            vec3 preSnapPos = vWorldPos + offsetVector;
            float texelSize = SHADOW_LOCK;
            vec3 absPos = preSnapPos + cameraPosition;

            vec3 snappedAbsolute = floor(absPos * texelSize) / texelSize;
            snappedAbsolute += 0.5 / texelSize;
            vec3 final_world_pos = (snappedAbsolute - cameraPosition) + vBias;
            vec3 shadow_real_pos = get_shadow_pos(final_world_pos);
        #else
            vec3 shadow_real_pos = shadowPos;
        #endif

        #if defined COLORED_SHADOW
            vec3 shadowValue = get_colored_shadow(shadow_real_pos, dither);
            shadowValue = mix(shadowValue, vec3(1.0), shadowDiffuse);
        #else
            float nightShadowAmount = 1.0 - smoothstep(0.0, 0.35, dayNightMix);
            bool needShadow = directLightStrength > 0.002;
            #if NIGHT_SHADOWS == 2
                needShadow = needShadow && nightShadowAmount < 0.99;
            #endif
            #ifdef FOLIAGE_V
                needShadow = needShadow || isFoliage > 0.2;
            #endif
            float shadowValue = 1.0;
            if (needShadow) {
                shadowValue = get_shadow(shadow_real_pos, dither);
            }
            shadowValue = mix(shadowValue, 1.0, shadowDiffuse);
            shadowValue = mix(shadowValue, 1.0, nightShadowAmount * NIGHT_SHADOW_SOFTEN);
        #endif
    #else
        float shadowValue = abs((dayNightMix * 2.0) - 1.0);
    #endif

    #ifdef FOLIAGE_V
        if(isFoliage > 0.2) {
            #if defined SHADOW_CASTING && !defined NETHER && defined COLORED_SHADOW
                shadowValue = mix(shadowValue, vec3(1.0), 0.5);
            #else
                shadowValue = mix(shadowValue, 1.0, 0.5);
            #endif
        }
    #endif

    #if defined GBUFFER_BEACONBEAM
        blockColor.rgb *= 1.5;
    #elif defined GBUFFER_ENTITY_GLOW
        blockColor.rgb =
            clamp(vec3(luma(blockColor.rgb)) * vec3(0.75, 0.75, 1.5), vec3(0.3), vec3(1.0));
        vec3 realLight = omniLight +
                (shadowValue * directLightColor * directLightStrength) * (1.0 - (rainStrength * 0.55)) +
                finalCandleColor;
    #else
        #if defined PBR_ACTIVE
            #if PBR_MODE == 1
                vec4 pbrNormalSample = texture2D(normals, pomUV);
                vec4 pbrSpecSample = texture2D(specular, pomUV);
            #else
                float ipDistance = 1.0 / max(gl_FragCoord.w, 0.0001);
                #if PERFORMANCE_MODE == 3
                    float ipBumpFade = 1.0 - smoothstep(8.0, 24.0, ipDistance);
                    float ipShineFade = 1.0 - smoothstep(14.0, 36.0, ipDistance);
                    float ipFarLimit = 36.0;
                #elif PERFORMANCE_MODE == 2
                    float ipBumpFade = 1.0 - smoothstep(11.0, 34.0, ipDistance);
                    float ipShineFade = 1.0 - smoothstep(19.0, 52.0, ipDistance);
                    float ipFarLimit = 52.0;
                #else
                    float ipBumpFade = 1.0 - smoothstep(14.0, 44.0, ipDistance);
                    float ipShineFade = 1.0 - smoothstep(24.0, 72.0, ipDistance);
                    float ipFarLimit = 72.0;
                #endif
                #if defined GBUFFER_HAND
                    ipBumpFade *= 0.35;
                    ipShineFade *= 0.5;
                #endif

                vec2 ipStepU = vec2(min(max(abs(dFdx(pomUV.x)), abs(dFdy(pomUV.x))), 0.0012), 0.0);
                vec2 ipStepV = vec2(0.0, min(max(abs(dFdx(pomUV.y)), abs(dFdy(pomUV.y))), 0.0012));
                vec2 ipSlope = vec2(0.0);
                float ipSmooth = 0.10;

                if (ipDistance < ipFarLimit) {
                    vec3 ipAlbedo = texture2D(tex, pomUV).rgb;
                    float ipRight = luma(texture2D(tex, pomUV + ipStepU).rgb);
                    float ipLeft = luma(texture2D(tex, pomUV - ipStepU).rgb);
                    float ipUp = luma(texture2D(tex, pomUV - ipStepV).rgb);
                    float ipDown = luma(texture2D(tex, pomUV + ipStepV).rgb);

                    ipSlope = vec2(ipLeft - ipRight, ipDown - ipUp) * (1.1 * INT_PBR_BUMP * ipBumpFade);
                    ipSlope = clamp(ipSlope, vec2(-0.55), vec2(0.55));

                    float ipLuma = luma(ipAlbedo);
                    float ipPeak = max(ipAlbedo.r, max(ipAlbedo.g, ipAlbedo.b));
                    float ipSaturation = (ipPeak - min(ipAlbedo.r, min(ipAlbedo.g, ipAlbedo.b))) / max(ipPeak, 0.001);
                    float ipBusy = clamp((abs(ipRight - ipLeft) + abs(ipUp - ipDown)) * 2.5, 0.0, 0.6);
                    ipSmooth = (0.10 + 0.55 * smoothstep(0.40, 0.92, ipLuma) * (1.0 - ipSaturation)) * (1.0 - ipBusy);
                    ipSmooth = mix(0.10, ipSmooth, ipShineFade);
                }

                vec4 pbrNormalSample = vec4(ipSlope * 0.5 + 0.5, 1.0, 1.0);
                vec4 pbrSpecSample = vec4(clamp(ipSmooth * INT_PBR_SHINE, 0.0, 0.9), 0.04, 0.0, 1.0);
            #endif
            float pbrValid = step(0.004, pbrNormalSample.b + pbrNormalSample.a);

            vec3 pbrTangentSpace = vec3((pbrNormalSample.xy * 2.0 - 1.0) * PBR_NORMAL_STRENGTH, 0.0);
            pbrTangentSpace.z = sqrt(max(1.0 - dot(pbrTangentSpace.xy, pbrTangentSpace.xy), 0.0));
            vec3 pbrGeo = normalize(pbrNormal);
            vec3 mappedNormal = normalize(pbrTangent * pbrTangentSpace.x + pbrBitangent * pbrTangentSpace.y + pbrGeo * pbrTangentSpace.z);
            mappedNormal = mix(pbrGeo, mappedNormal, pbrValid);

            float pbrAO = mix(1.0, pbrNormalSample.b, pbrValid * 0.9);
            float pbrSmoothness = pbrSpecSample.r;
            float pbrSpecMask = smoothstep(0.02, 0.15, pbrSmoothness);
            float pbrRoughness = max((1.0 - pbrSmoothness) * (1.0 - pbrSmoothness), 0.03);
            float pbrMetal = step(229.5, pbrSpecSample.g * 255.0);
            vec3 pbrAlbedo = blockColor.rgb;
            #if PBR_MODE == 1
                vec3 pbrF0 = mix(vec3(pbrSpecSample.g), labMetalF0(pbrSpecSample.g * 255.0, pbrAlbedo), pbrMetal);
            #else
                vec3 pbrF0 = mix(vec3(pbrSpecSample.g), pbrAlbedo, pbrMetal);
            #endif
            vec3 pbrViewDir = normalize(-pbrViewPos);
            float pbrNV = max(dot(mappedNormal, pbrViewDir), 0.001);

            float pbrEmission = pbrSpecSample.a * 255.0 < 254.5 ? pbrSpecSample.a * 255.0 / 254.0 : 0.0;
            vec3 pbrAdditive = pbrAlbedo * (pbrEmission * 2.0 * PBR_EMISSION_STRENGTH);

            float pbrDirect = directLightStrength;

            #if !defined THE_END && !defined NETHER
                vec3 pbrLight = normalize(sunPosition) * mix(-1.0, 1.0, dayNightMix);
                float pbrNLGeo = clamp(dot(pbrGeo, pbrLight), 0.0, 1.0);
                float pbrNL = clamp(dot(mappedNormal, pbrLight), 0.0, 1.0);
                pbrDirect = clamp(directLightStrength * (pbrNL + 0.05) / (pbrNLGeo + 0.05), 0.0, 1.3);

                vec3 pbrHalf = normalize(pbrLight + pbrViewDir);
                float pbrNH = max(dot(mappedNormal, pbrHalf), 0.0);
                float pbrVH = max(dot(pbrViewDir, pbrHalf), 0.0);
                float pbrA2 = pbrRoughness * pbrRoughness;
                float pbrDenominator = pbrNH * pbrNH * (pbrA2 - 1.0) + 1.0;
                float pbrD = pbrA2 / (3.14159265 * pbrDenominator * pbrDenominator);
                float pbrK = (pbrRoughness + 1.0) * (pbrRoughness + 1.0) * 0.125;
                float pbrG = (pbrNL / (pbrNL * (1.0 - pbrK) + pbrK)) * (pbrNV / (pbrNV * (1.0 - pbrK) + pbrK));
                vec3 pbrFresnel = pbrF0 + (1.0 - pbrF0) * pow(1.0 - pbrVH, 5.0);
                vec3 pbrSpecular = min(pbrD * pbrG * pbrFresnel / max(4.0 * pbrNV, 0.001), vec3(12.0));

                pbrAdditive += pbrSpecular * (shadowValue * directLightColor) *
                    ((1.0 - rainStrength * 0.55) * step(0.001, directLightStrength) * pbrSpecMask * PBR_SPECULAR_STRENGTH);
            #endif

            vec3 pbrEnvFresnel = pbrF0 + (1.0 - pbrF0) * pow(1.0 - pbrNV, 5.0);
            pbrAdditive += omniLight * pbrEnvFresnel * (1.2 * (1.0 - pbrRoughness) * pbrSpecMask * PBR_SPECULAR_STRENGTH);

            blockColor.rgb *= 1.0 - 0.85 * pbrMetal * pbrSpecMask;

            vec3 realLight = omniLight * pbrAO +
                (shadowValue * directLightColor * pbrDirect) * (1.0 - (rainStrength * 0.55)) +
                finalCandleColor;
        #elif defined MATERIAL_GLOSS && !defined NETHER
            float final_gloss_power = glossPower;
            block_luma *= lumaFactor;

            if(lumaPower < 0.0) {
                final_gloss_power -= (block_luma * 73.334);
            } else {
                block_luma = pow(block_luma, lumaPower);
            }

            float material_gloss_factor = materialGloss(reflect(viewPositionNormalized, flatNormal), lmcoordAlt, final_gloss_power, flatNormal) * glossFactor;

            float material = material_gloss_factor * block_luma;
            #if defined GBUFFER_HAND
                material *= 0.35;
            #endif
            vec3 realLight = omniLight +
                (shadowValue * ((directLightColor * directLightStrength) + (directLightColor * material))) * (1.0 - (rainStrength * 0.55)) +
                finalCandleColor;
        #else
            vec3 realLight = omniLight +
                (shadowValue * directLightColor * directLightStrength) * (1.0 - (rainStrength * 0.55)) +
                finalCandleColor;
        #endif

        #if defined FOLIAGE_V && !defined NETHER && !defined THE_END
            vec3 foliageAlbedo = blockColor.rgb;
        #endif

        #ifdef YDREAM_LIGHT_BUFFERS
            ydreamAlbedo = blockColor.rgb;
            ydreamCandleLuma = luma(finalCandleColor);
        #endif

        blockColor.rgb *= mix(realLight, vec3(1.0), nightVision * 0.125);
        blockColor.rgb *= mix(vec3(1.0, 1.0, 1.0), vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B), nightVision);

        #ifdef FOLIAGE_V
            if(isFoliage > 0.2) {
                blockColor.rgb += blockColor.rgb * directLightColor * 0.18;
            }
        #endif

        #if defined FOLIAGE_V && !defined NETHER && !defined THE_END
            blockColor.rgb += foliageAlbedo * (shadowValue * directLightColor) * (foliageBackscatter * 0.55 * (1.0 - rainStrength * 0.55));
        #endif

        #ifdef WETNESS_EFFECTS_ON
            float wetnessAmount = clamp(wetness, 0.0, 1.0) * clamp(skyExposure * 1.4 - 0.4, 0.0, 1.0) * WETNESS_STRENGTH;
            blockColor.rgb *= mix(1.0, 0.88, wetnessAmount * 0.5);
            blockColor.rgb += directLightColor * (wetnessAmount * 0.04 * directLightStrength);
        #endif

        #if defined PBR_ACTIVE
            blockColor.rgb += pbrAdditive;
        #endif

    #endif

    #if defined GBUFFER_ENTITIES
        if(entityId == 10101) {
            blockColor = vec4(1.0, 1.0, 1.0, 0.5);
        } else if (entityId == 10201) {
            blockColor = originalEntityColor;
            blockColor.rgb = blockColor.rgb * blockColor.rgb;
        } else {
            float entity_poderation = luma(realLight);
            blockColor.rgb = mix(blockColor.rgb, entityColor.rgb, entityColor.a * entity_poderation * 3.0);
        }
    #endif

    #if MC_VERSION < 11300 && defined GBUFFER_TEXTURED
        blockColor.rgb *= 1.5;
    #endif

    #if defined GBUFFER_TERRAIN && EMISSIVE_ORES == 1
        float orePeakOut = max(max(oreAlbedo.r, oreAlbedo.g), oreAlbedo.b);
        vec3 oreHue = oreAlbedo / max(orePeakOut, 0.001);
        vec3 oreEmit = mix(oreAlbedo, oreHue, 0.55);
        float oreDaySoften = 1.0 - 0.35 * abs(dayNightMix * 2.0 - 1.0);
        blockColor.rgb += oreEmit * (oreMask * 1.35 * ORE_GLOW_STRENGTH * oreDaySoften * (1.0 - nightVision * 0.3));
    #endif

    #if defined GBUFFER_TERRAIN || defined GBUFFER_HAND
        vec3 emitHue = emitAlbedo / max(emitPeak, 0.001);
        vec3 emitColor = mix(emitAlbedo, emitHue * emitPeak, EMISSIVE_RICHNESS);
        float emitNight = 1.0 - smoothstep(0.0, 0.5, dayNightMix);
        float emitCore = smoothstep(0.70, 1.0, emitPeak);
        emitColor += mix(emitHue, vec3(1.0), 0.6) * (emitCore * 0.22 * EMISSIVE_HOTCORE);
        blockColor.rgb += emitColor * (emitMask * EMISSIVE_STRENGTH * 0.62 * (1.0 + 0.35 * EMISSIVE_NIGHT_BOOST * emitNight) * (1.0 - nightVision * 0.3));
    #endif

    #include "/src/finalcolor.glsl"
    #include "/src/writebuffers.glsl"
}
