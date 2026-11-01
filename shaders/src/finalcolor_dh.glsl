#if defined THE_END
    if(isEyeInWater == 0 && FOG_ADJUST < 15.0) {
        blockColor.rgb = mix(blockColor.rgb, ZENITH_DAY_COLOR, frogAdjust);
    }
#elif defined NETHER
    if(isEyeInWater == 0 && FOG_ADJUST < 15.0) {
        #if NETHER_FOG_DISTANCE == 1
            blockColor.rgb = mix(fogColor * 0.1, vec3(1.0), 0.04);
        #else
            blockColor.rgb = mix(blockColor.rgb, mix(fogColor * 0.1, vec3(1.0), 0.04), frogAdjust);
        #endif
    }
#else
    #ifdef FOG_ACTIVE
        #if MC_VERSION >= 11900
            vec3 fog_texture;
            if(darknessFactor > .01) {
                fog_texture = vec3(0.0);
            } else {
                fog_texture = texture2D(colortex7, gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY)).rgb;
            }
        #else
            vec3 fog_texture = texture2D(colortex7, gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY)).rgb;
        #endif

        // Identical colour grade to the vanilla terrain pass, so the DH distance
        // does not show a different fog colour than the near render distance.
        float fogGoldenHour = 1.0 - abs(dayNightMix * 2.0 - 1.0);
        fog_texture = mix(fog_texture, fog_texture * vec3(1.18, 0.90, 0.74) + vec3(0.025, 0.012, 0.0), clamp(fogGoldenHour * (0.55 * FOG_GOLDEN_TINT), 0.0, 1.0));
        fog_texture = ydreamFogColor(fog_texture, fogSunScatter, fogGoldenHour, rainStrength, abs(dayNightMix * 2.0 - 1.0));
        fog_texture = mix(vec3(dot(fog_texture, vec3(0.2126, 0.7152, 0.0722))), fog_texture, FOG_SATURATION) * FOG_BRIGHTNESS;

        if(isEyeInWater == 0) {
            blockColor.rgb = mix(blockColor.rgb, fog_texture, frogAdjust);

            #ifdef AERIAL_PERSPECTIVE_ON
                float aerialAmount = (1.0 - exp(-gl_FogFragCoord * (0.0026 * AERIAL_PERSPECTIVE_DISTANCE))) *
                    (AERIAL_PERSPECTIVE_STRENGTH * 0.36) * (1.0 + 0.55 * fogSunScatter * FOG_SUN_SCATTER) * (1.0 - frogAdjust);
                blockColor.rgb = mix(blockColor.rgb, fog_texture, aerialAmount);
            #endif
        }
    #endif
#endif

#if MC_VERSION >= 11900
    if(blindness > .01 || darknessFactor > .01) {
        blockColor.rgb = mix(blockColor.rgb, vec3(0.0), max(blindness, darknessLightFactor) * gl_FogFragCoord * 0.24);
    }
#else
    if(blindness > .01) {
        blockColor.rgb = mix(blockColor.rgb, vec3(0.0), blindness * gl_FogFragCoord * 0.24);
    }
#endif
