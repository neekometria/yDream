#ifdef UNKNOWN_DIM
    vec3 horizonSkyColorRGB = fogColor;
    vec3 horizonSkyColor = rgbToXyz(horizonSkyColorRGB);
#else
    vec3 horizonSkyColorRGB = skyBlendVoxy(
        HORIZON_SUNSET_COLOR,
        HORIZON_DAY_COLOR,
        HORIZON_NIGHT_COLOR,
        mix(HORIZON_SUNSET_COLOR, vec3(1.0, 0.88, 0.70), 0.32),
        sunElevationV
    );

    horizonSkyColorRGB = mix(
        horizonSkyColorRGB,
        HORIZON_SKY_RAIN_COLOR * luma(horizonSkyColorRGB),
        clamp(rainStrength * RAIN_ATMOSPHERE_STRENGTH, 0.0, 1.0)
    );

    vec3 horizonSkyColor = rgbToXyz(horizonSkyColorRGB);
#endif
