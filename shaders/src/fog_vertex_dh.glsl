#if !defined THE_END && !defined NETHER
    float fogIntensityCoeff = max(eyeBrightSmoothFloat.y * 0.004166666666666667, visibleSky);
    frogAdjust = pow(
        clamp(gl_FogFragCoord / dhRenderDistance, 0.0, 1.0) * fogIntensityCoeff,
        mix(fogDensityCoeff * 0.15, 0.5, rainStrength)
    );

    #ifdef GROUND_FOG_ON
        // DH geometry is camera relative, so the world height of the vertex is
        // just the varying plus the camera height. Everything else is identical
        // to the vanilla path, which keeps the fog bed continuous across the
        // border between the vanilla and DH render distances.
        float groundFogY = position.y + cameraPosition.y;
        float groundFogHeight = exp(-max(groundFogY - float(GROUND_FOG_HEIGHT), 0.0) * 0.055);
        float groundFogTwilight = 1.0 + 1.1 * (1.0 - smoothstep(0.0, 0.45, abs(sunElevation)));
        float groundFogDensity = GROUND_FOG_DENSITY * STYLE_FOG_MULT * groundFogTwilight * (1.0 + rainStrength * 1.4) * 0.0032;
        float groundFogAmount = (1.0 - exp(-gl_FogFragCoord * groundFogDensity * groundFogHeight)) * 0.62;
        frogAdjust = 1.0 - (1.0 - frogAdjust) * (1.0 - groundFogAmount * fogIntensityCoeff);
    #endif

    // Same sun-scatter term the vanilla terrain uses, so the fog colour matches
    // exactly at the boundary between the vanilla and DH render distances.
    vec3 fogViewVec = normalize((mat3(gbufferModelView) * position.xyz) + vec3(0.0001));
    vec3 fogLightVec = normalize(sunPosition) * mix(1.0, -1.0, step(0.5, 1.0 - dayNightMix));
    float fogLightCos = clamp(dot(fogViewVec, fogLightVec), 0.0, 1.0);
    fogSunScatter = fogLightCos * fogLightCos * (0.35 + 0.65 * fogLightCos * fogLightCos);
#else
    // Nether and End use the same distance curve as the vanilla path (which
    // switches to the DH render distance when Distant Horizons is active), so
    // the fog ramp does not jump at the DH seam.
    fogSunScatter = 0.0;
    frogAdjust = pow(clamp(gl_FogFragCoord / dhRenderDistance, 0.0, 1.0), 1.6);
#endif
