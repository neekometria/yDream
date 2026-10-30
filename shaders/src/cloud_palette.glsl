vec3 cloudSunLight = dayBlend(LIGHT_SUNSET_COLOR, LIGHT_DAY_COLOR, LIGHT_NIGHT_COLOR * vec3(0.7, 0.8, 1.0));
vec3 cloudZenithRgb = skyBlend(
    ZENITH_SUNSET_COLOR,
    ZENITH_DAY_COLOR,
    ZENITH_NIGHT_COLOR,
    mix(ZENITH_SUNSET_COLOR, ZENITH_DAY_COLOR, 0.5)
);
vec3 cloudHorizonRgb = skyBlend(
    HORIZON_SUNSET_COLOR,
    HORIZON_DAY_COLOR,
    HORIZON_NIGHT_COLOR,
    mix(HORIZON_SUNSET_COLOR, vec3(1.0, 0.88, 0.70), 0.32)
);
vec3 cloudSkyMix = mix(cloudZenithRgb, cloudHorizonRgb, 0.5);
float cloudSkyLuma = luma(cloudSkyMix);

float cloudTwilight = 1.0 - smoothstep(0.0, 0.45, abs(sunElevation + 0.03));

vec3 cloudNeutralLight = mix(cloudSunLight, vec3(luma(cloudSunLight)), 0.38 * (1.0 - cloudTwilight));
vec3 cloudTwilightLight = mix(cloudNeutralLight, HORIZON_SUNSET_COLOR * vec3(1.06, 0.94, 1.02), 0.45 * cloudTwilight);
vec3 cloudLitBase = cloudTwilightLight * mix(0.85, 1.12, cloudTwilight) + vec3(cloudSkyLuma * mix(0.42, 0.10, cloudTwilight));
vec3 cloudShadeSky = mix(cloudSkyMix, cloudZenithRgb, cloudTwilight * 0.55);
vec3 cloudShadeBase = mix(vec3(cloudSkyLuma), cloudShadeSky, mix(0.30, 0.75, cloudTwilight)) * mix(0.93, 0.92, cloudTwilight) + cloudSunLight * 0.10;

float cloudRain = clamp(rainStrength * RAIN_ATMOSPHERE_STRENGTH, 0.0, 1.0);
vec3 cloudRainLit = vec3(0.62, 0.65, 0.70) * (luma(cloudSunLight) * 0.8 + cloudSkyLuma * 0.45);
vec3 cloudRainShade = cloudRainLit * 0.62;

cloudColor = mix(cloudLitBase, cloudRainLit, cloudRain * 0.9);
darkCloudColor = mix(cloudShadeBase, cloudRainShade, cloudRain * 0.9);

float cloudNightAmount = (1.0 - smoothstep(-0.18, 0.02, sunElevation)) * (1.0 - cloudRain);
cloudColor = mix(cloudColor, vec3(0.50, 0.60, 0.84) * 0.30, cloudNightAmount * 0.80);
darkCloudColor = mix(darkCloudColor, vec3(0.024, 0.036, 0.090), cloudNightAmount * 0.85);

#if YDREAM_COLOR_STYLE == 3
    darkCloudColor *= 0.90;
#endif
