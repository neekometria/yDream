tintColor = gl_Color;

vec2 illumination = lmcoord;
illumination.y = max(illumination.y - 0.065, 0.0) * 1.06951871657754;
visibleSky = clamp(illumination.y, 0.0, 1.0);

if (isEyeInWater == 1) {
    visibleSky = (visibleSky * .95) + .05;
}

#if defined UNKNOWN_DIM
    visibleSky = (visibleSky * 0.99) + 0.01;
#endif

float blockLightLevel = clamp(illumination.x, 0.0, 1.0);
float blockLightCurve = blockLightLevel * sqrt(blockLightLevel) + sixthPow(blockLightLevel * 1.17);
blockLightCurve += 0.45 * blockLightLevel * blockLightLevel * blockLightLevel * blockLightLevel;
vec3 blockLightShift = mix(vec3(1.06, 0.92, 0.70), vec3(1.0, 1.04, 1.10), smoothstep(0.55, 1.0, blockLightLevel));
#if BLOCKLIGHT_TEMP == 4
    blockLightShift = vec3(1.0);
#endif
candleColor = CANDLE_BASELIGHT * blockLightShift * blockLightCurve;

#ifdef DYN_HAND_LIGHT
    if (heldItemId == 11001 || heldItemId2 == 11001 || heldItemId == 11002 || heldItemId2 == 11002) {
        float distanceOffset = (heldItemId == 11001 || heldItemId2 == 11001) ? 0.0 : 0.5;
        float handDistance = (1.0 - clamp((gl_FogFragCoord * 0.06666666666666667) + distanceOffset, 0.0, 1.0));
        vec3 handLight = CANDLE_BASELIGHT * (handDistance * sqrt(handDistance) + sixthPow(handDistance * 1.17));
        candleColor = max(candleColor, handLight);
    }
#endif

#ifdef NETHER
    candleColor *= 1.4;
#endif

candleColor = clamp(candleColor, vec3(0.0), vec3(4.0));

#if defined THE_END || defined NETHER
    vec3 astroVector = normalize(gbufferModelView * vec4(0.0, 0.89442719, 0.4472136, 0.0)).xyz;
#else
    vec3 astroVector = normalize(sunPosition);
#endif

vec3 normal = gl_NormalMatrix * gl_Normal;
float astroLightStrength;
if (dot(normal, normal) > 0.0001) {
    normal = normalize(normal);
    astroLightStrength = dot(normal, astroVector);
} else {
    normal = vec3(0.0, 1.0, 0.0);
    astroLightStrength = 1.0;
}

#if defined THE_END || defined NETHER
    directLightStrength = astroLightStrength;
#else
    directLightStrength = mix(-astroLightStrength, astroLightStrength, dayNightMix);
#endif

#ifdef UNKNOWN_DIM
    directLightColor = texture2D(lightmap, vec2(0.0, lmcoord.y)).rgb;
#else
    directLightColor = dayBlend(LIGHT_SUNSET_COLOR, LIGHT_DAY_COLOR, LIGHT_NIGHT_COLOR);
    #if defined NORTHSTAR_MOON
        // Airless Moon: hard, neutral sunlight instead of Earth-tinted daylight.
        directLightColor = vec3(1.0, 0.97, 0.92) * NORTHSTAR_MOON_SUN_LIGHT;
    #endif
    #if defined NORTHSTAR_VENUS
        // Venus: sunlight reaches the ground through the cloud deck as warm, diffuse light.
        directLightColor = vec3(0.80, 0.56, 0.30) * NORTHSTAR_VENUS_LIGHT;
    #elif defined NORTHSTAR_MARS
        // Mars: dusty but clear-enough daylight, slightly pale and neutral.
        directLightColor = vec3(1.0, 0.92, 0.84) * NORTHSTAR_MARS_LIGHT;
    #endif
    #if defined NORTHSTAR_MERCURY
        // Mercury surface: no air, so the direct sunlight matches the Mercury orbit.
        directLightColor = vec3(1.0, 0.97, 0.92) * NORTHSTAR_MERCURY_IRR_VIEW * NORTHSTAR_LIGHT_STRENGTH;
    #endif
    #if defined IS_IRIS && defined THE_END && MC_VERSION >= 12109
        directLightColor += (endFlashIntensity * endFlashIntensity * 0.1);
    #endif
#endif

float omniStrength = ((directLightStrength + 1.0) * 0.25) + 0.75;

#ifdef FOLIAGE_V

    float farDirectLightStrength = clamp(directLightStrength, 0.0, 1.0);
    if (mc_Entity.x != ENTITY_LEAVES) {
        farDirectLightStrength = farDirectLightStrength * 0.75 + 0.25;
    }

    if (isFoliage > .2) {
        #ifdef SHADOW_CASTING
            directLightStrength = sqrt(abs(directLightStrength));
        #else
            directLightStrength = (clamp(directLightStrength, 0.0, 1.0) * 0.5 + 0.5) * 0.75;
        #endif
        omniStrength = 1.0;
    } else {
        directLightStrength = clamp(directLightStrength, 0.0, 1.0);
    }
#else
    directLightStrength = clamp(directLightStrength, 0.0, 1.0);
#endif

#if defined THE_END || defined NETHER
    omniLight = LIGHT_DAY_COLOR * omniStrength;

    #ifdef NETHER
        float netherHemisphere = dot(normal, normalize(gbufferModelView[1].xyz)) * 0.5 + 0.5;
        omniLight = (LIGHT_DAY_COLOR * omniStrength + ZENITH_DAY_COLOR * 0.6) * mix(1.15, 0.85, netherHemisphere);
        omniLight += netherLightHue(fogColor) * (NETHER_FILL * (1.0 - netherHemisphere));
    #endif
#else
    directLightColor = mix(directLightColor, ZENITH_SKY_RAIN_COLOR * luma(directLightColor) * 0.4, rainStrength * 0.72);

    vec3 omniColor = mix(ZenithSkyColorRGB, directLightColor * 0.45, OMNI_TINT);
    float omniColorLuma = colorAverage(omniColor);

    float lumaRatio = AVOID_DARK_LEVEL / max(omniColorLuma, 0.0001);
    vec3 omniColorMin = omniColor * lumaRatio;
    omniColor = max(omniColor, omniColorMin);

    float hemisphere = dot(normal, normalize(gbufferModelView[1].xyz)) * 0.5 + 0.5;
    omniLight = mix(omniColorMin, omniColor, visibleSky) * omniStrength * mix(0.86, 1.05, hemisphere) * (AMBIENT_STRENGTH * STYLE_AMBIENT_MULT);
    #if defined NORTHSTAR_MOON
        // No air scatters light into shadow on the Moon: keep only a small floor.
        omniLight = max(omniLight, vec3(NORTHSTAR_MOON_AMBIENT));
    #endif

    #if YDREAM_AURORA == 1 && !defined UNKNOWN_DIM
        float auroraNightAmount = skyNightAmount() * (1.0 - rainStrength) * (AURORA_BIOME == 0 ? smoothstep(0.0, 1.0, auroraBiomeFade) : 1.0);
        vec3 auroraDirection = normalize((gbufferModelView * vec4(-0.726, 0.30, -0.687, 0.0)).xyz);
        float auroraFacing = dot(normal, auroraDirection) * 0.5 + 0.5;
        omniLight += AURORA_LIGHT_COLOR * (0.045 * AURORA_LIGHT * auroraNightAmount * visibleSky * mix(0.45, 1.0, auroraFacing));
    #endif
#endif

#ifdef FOLIAGE_V
    omniLight *= mix(1.0, 1.14, isFoliage);
#endif

#ifdef CAVEENTITY_V
    float candleCaveStrength = (directLightStrength * .5) + .5;
    candleCaveStrength = mix(candleCaveStrength, 1.0, visibleSky);
    candleColor *= candleCaveStrength;
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

#ifdef EMMISIVE_V
    if (isFakeEmmisor > 0.5) {
        omniLight = vec3(0.45);
    }
#endif

#ifdef FOLIAGE_V
    #if !defined THE_END && !defined NETHER
        foliageBackscatter = pow(clamp(dot(normalize(viewPosition.xyz), astroVector * mix(-1.0, 1.0, dayNightMix)), 0.0, 1.0), 3.0) * isFoliage;
    #else
        foliageBackscatter = 0.0;
    #endif
#endif

#if defined CLOUD_SHADOWS_ON && defined CLOUD_SHADOW_APPLY
    #include "/src/cloud_shadow_vertex.glsl"
#endif
