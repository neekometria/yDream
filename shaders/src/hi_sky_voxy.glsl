#ifdef UNKNOWN_DIM
    vec3 ZenithSkyColorRGB = skyColor;
    vec3 zenithSkyColor = rgbToXyz(ZenithSkyColorRGB);
#else
    vec3 ZenithSkyColorRGB = skyBlendVoxy(
        ZENITH_SUNSET_COLOR,
        ZENITH_DAY_COLOR,
        ZENITH_NIGHT_COLOR,
        mix(ZENITH_SUNSET_COLOR, ZENITH_DAY_COLOR, 0.5),
        sunElevationV
    );

    ZenithSkyColorRGB = mix(
        ZenithSkyColorRGB,
        ZENITH_SKY_RAIN_COLOR * luma(ZenithSkyColorRGB),
        clamp(rainStrength * RAIN_ATMOSPHERE_STRENGTH, 0.0, 1.0)
    );

    vec3 zenithSkyColor = rgbToXyz(ZenithSkyColorRGB);
#endif
