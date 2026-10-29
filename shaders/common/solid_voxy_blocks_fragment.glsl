#include "/lib/config.glsl"
#include "/lib/basic_utils.glsl"
#include "/lib/luma.glsl"
#include "/lib/dither.glsl"

#if defined THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

#if defined MATERIAL_GLOSS && !defined NETHER
    #include "/lib/material_gloss_fragment_voxy.glsl"
#endif

layout(location = 0) out vec4 gbufferData0;
layout(location = 1) out vec4 gbufferData1;

void voxy_emitFragment(VoxyFragmentParameters parameters) {

    #include "/src/voxy_uniforms_replace.glsl"
    #include "/src/hi_sky_voxy.glsl"

    bool isFoliageEntity = (
        customId == ENTITY_LOWERGRASS ||
        customId == ENTITY_UPPERGRASS ||
        customId == ENTITY_SMALLGRASS ||
        customId == ENTITY_SMALLENTS ||
        customId == ENTITY_LEAVES ||
        customId == ENTITY_SMALLENTS_NW
    );

    #include "/src/voxy_position_light.glsl"

    float farDirectLightStrength = clamp(directLightStrength, 0.0, 1.0);
    if (isFoliageEntity) {
        if (customId != ENTITY_LEAVES) {
            farDirectLightStrength = farDirectLightStrength * 0.75 + 0.25;
        }

        #ifdef SHADOW_CASTING
            directLightStrength = sqrt(abs(directLightStrength));
        #else
            directLightStrength = (clamp(directLightStrength, 0.0, 1.0) * 0.5 + 0.5) * 0.75;
        #endif
        omniStrength = 1.0;
    } else {
        directLightStrength = clamp(directLightStrength, 0.0, 1.0);
    }

    #if defined THE_END || defined NETHER
        vec3 omniLight = LIGHT_DAY_COLOR * omniStrength;
    #else
        directLightColor = mix(directLightColor, ZENITH_SKY_RAIN_COLOR * luma(directLightColor) * 0.4, rainStrength);

        vec3 omniColor = mix(ZenithSkyColorRGB, directLightColor * 0.45, OMNI_TINT);
        float omniColorLuma = colorAverage(omniColor);

        float lumaRatio = AVOID_DARK_LEVEL / max(omniColorLuma, 0.0001);
        vec3 omniColorMin = omniColor * lumaRatio;
        omniColor = max(omniColor, omniColorMin);

        vec3 omniLight = mix(omniColorMin, omniColor, visibleSky) * omniStrength * (AMBIENT_STRENGTH * STYLE_AMBIENT_MULT);
    #endif

    #if !defined THE_END && !defined NETHER
        #ifndef SHADOW_CASTING

            if (isEyeInWater == 0) {

                float visSky2 = visibleSky * visibleSky;
                float visSky4 = visSky2 * visSky2;
                float visSky8 = visSky4 * visSky4;
                directLightStrength = mix(0.0, directLightStrength, visSky8 * visSky2);
            } else {
                directLightStrength = mix(0.0, directLightStrength, visibleSky);
            }
        #else
            directLightStrength = mix(0.0, directLightStrength, visibleSky);
        #endif
    #endif

    vec2 ndc = (gl_FragCoord.xy / vec2(viewWidth, viewHeight)) * 2.0 - 1.0;
    float depth = gl_FragCoord.z * 2.0 - 1.0;
    vec4 clipPos = vec4(ndc, depth, 1.0);

    vec4 worldPos = vxViewProjInv * clipPos;
    worldPos /= worldPos.w;

    float fogFragCoord = length(worldPos.xyz);

    vec2 eyeBrightSmoothFloat = vec2(eyeBrightnessSmooth);

    #if !defined THE_END && !defined NETHER
        float fogIntensityCoeff = max(eyeBrightSmoothFloat.y * 0.004166666666666667, visibleSky);
        float frogAdjust = pow(
            clamp(fogFragCoord / float(vxRenderDistance * 16), 0.0, 1.0) * fogIntensityCoeff,
            mix(fogDensityCoeff * 0.15, 0.5, rainStrength)
        );
    #else
        float frogAdjust = sqrt(clamp(fogFragCoord / float(vxRenderDistance * 16), 0.0, 1.0));
    #endif

    #if !defined NETHER
        #ifdef SHADOW_CASTING
            if (isFoliageEntity) {
                directLightStrength = farDirectLightStrength;
            }
        #endif
    #endif

    #if defined MATERIAL_GLOSS && !defined NETHER
        float lumaFactor = 1.0;
        float lumaPower = 2.0;
        float glossPower = 6.0;
        float glossFactor = 1.05;

        if(customId == ENTITY_SAND) {
            lumaPower = 4.0;
        } else if(customId == ENTITY_METAL) {
            lumaFactor = 1.35;
            lumaPower = -1.0;
            glossPower = 100.0;
        } else if(customId == ENTITY_FABRIC) {
            glossPower = 3.0;
            glossFactor = 0.1;
        }

        vec4 viewPosition = vxProjInv * clipPos;
        viewPosition /= viewPosition.w;
        vec3 viewPositionNormalized = normalize(viewPosition.xyz);
    #endif

    #if AA_TYPE > 0
        float dither = shiftedRDither(gl_FragCoord.xy);
    #else
        float dither = rDither(gl_FragCoord.xy);
    #endif

    vec4 blockColor = parameters.sampledColour * tintColor;

    float block_luma = luma(blockColor.rgb);

    vec3 finalCandleColor = candleColor;
    if (customId == ENTITY_EMMISIVE) {
        finalCandleColor *= block_luma * EMISSIVE_STRENGTH;
    }

    float shadowValue = abs((dayNightMix * 2.0) - 1.0);

    #if defined MATERIAL_GLOSS && !defined NETHER
        block_luma *= lumaFactor;

        if(lumaPower < 0.0) {
            glossPower -= (block_luma * 73.334);
        } else {
            block_luma = pow(block_luma, lumaPower);
        }

        float material_gloss_factor = materialGloss(reflect(viewPositionNormalized, normal), lmcoord, glossPower, normal) * glossFactor;

        float material = material_gloss_factor * block_luma;
        vec3 realLight = omniLight +
            (shadowValue * ((directLightColor * directLightStrength) + (directLightColor * material))) * (1.0 - (rainStrength * 0.55)) +
            finalCandleColor;
    #else
        vec3 realLight = omniLight +
            (shadowValue * directLightColor * directLightStrength) * (1.0 - (rainStrength * 0.55)) +
            finalCandleColor;
    #endif

    blockColor.rgb *= mix(realLight, vec3(1.0), nightVision * 0.125);
    blockColor.rgb *= mix(vec3(1.0, 1.0, 1.0), vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B), nightVision);

    blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));

    #include "/src/finalcolor_voxy.glsl"

    if (blindness > .01) {
        blockColor.rgb = vec3(0.0);
    }

    gbufferData0 = blockColor;
    gbufferData1 = blockColor;
}
