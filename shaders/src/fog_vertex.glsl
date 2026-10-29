#if !defined THE_END && !defined NETHER

    #if (VOL_LIGHT == 1 && !defined NETHER) || (VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER) || defined UNKNOWN_DIM
        float fogDensityCoeff = FOG_DENSITY * FOG_ADJUST;
    #else
        float fogDensityCoeff = dayBlendFloat(
            FOG_SUNSET,
            FOG_DAY,
            FOG_NIGHT
        ) * FOG_ADJUST;
    #endif

    float fogIntensityCoeff = max(eyeBrightSmoothFloat.y * 0.004166666666666667, visibleSky);

    #ifdef DISTANT_HORIZONS
        frogAdjust = pow(
            clamp(gl_FogFragCoord / dhRenderDistance, 0.0, 1.0) * fogIntensityCoeff,
            mix(fogDensityCoeff * 0.15, 0.5, rainStrength)
        );
    #elif defined VOXY
        frogAdjust = pow(
            clamp(gl_FogFragCoord / (vxRenderDistance * 16), 0.0, 1.0) * fogIntensityCoeff,
            mix(fogDensityCoeff * 0.15, 0.5, rainStrength)
        );
    #else
        frogAdjust = pow(
            clamp(gl_FogFragCoord / far, 0.0, 1.0) * fogIntensityCoeff,
            mix(fogDensityCoeff, 1.0, rainStrength)
        );
    #endif

    vec3 fogViewVec = normalize((gl_ModelViewMatrix * gl_Vertex).xyz);
    vec3 fogLightVec = normalize(sunPosition) * mix(1.0, -1.0, step(0.5, nightSelect));
    float fogLightCos = clamp(dot(fogViewVec, fogLightVec), 0.0, 1.0);
    fogSunScatter = fogLightCos * fogLightCos * (0.35 + 0.65 * fogLightCos * fogLightCos);

    #ifdef GROUND_FOG_ON
        vec4 groundFogView = gl_ModelViewMatrix * gl_Vertex;
        float groundFogY = (gbufferModelViewInverse * groundFogView).y + cameraPosition.y;
        float groundFogHeight = exp(-max(groundFogY - float(GROUND_FOG_HEIGHT), 0.0) * 0.055);
        float groundFogTwilight = 1.0 + 1.1 * (1.0 - smoothstep(0.0, 0.45, abs(sunElevation)));
        float groundFogDensity = GROUND_FOG_DENSITY * STYLE_FOG_MULT * groundFogTwilight * (1.0 + rainStrength * 1.4) * 0.0032;
        float groundFogAmount = (1.0 - exp(-gl_FogFragCoord * groundFogDensity * groundFogHeight)) * 0.62;
        frogAdjust = 1.0 - (1.0 - frogAdjust) * (1.0 - groundFogAmount * fogIntensityCoeff);
    #endif

#else
    fogSunScatter = 0.0;
    #if defined NETHER
        #if NETHER_FOG_DISTANCE == 1
            float sight = NETHER_SIGHT;
        #else
        #if defined DISTANT_HORIZONS
            float sight = dhRenderDistance;
        #elif defined VOXY
            float sight = (vxRenderDistance * 16);
        #else
            float sight = NETHER_SIGHT;
        #endif
        #endif
    #else
        #if defined DISTANT_HORIZONS
            float sight = dhRenderDistance;
        #elif defined VOXY
            float sight = (vxRenderDistance * 16);
        #else
            float sight = far;
        #endif
    #endif
    float netherDistance = clamp(gl_FogFragCoord / sight, 0.0, 1.0);
    frogAdjust = pow(netherDistance, 1.6);

    #ifdef NETHER_HEIGHT_FOG
        vec4 netherFogView = gl_ModelViewMatrix * gl_Vertex;
        float netherFogY = (gbufferModelViewInverse * netherFogView).y + cameraPosition.y;
        float netherMist = exp(-max(netherFogY - 30.0, 0.0) * 0.045) * smoothstep(0.02, 0.35, netherDistance);
        frogAdjust = 1.0 - (1.0 - frogAdjust) * (1.0 - netherMist * 0.5);
    #endif
#endif
