#if MC_VERSION < 12106
    float cloudFogDistance = far * 1.66 * VANILLA_CLOUD_FADE;
#else
    float cloudFogDistance = 2000.0 * VANILLA_CLOUD_FADE;
#endif

float cloudFogAmount = clamp(pow(gl_FogFragCoord / cloudFogDistance, 1.5), 0.0, 1.0);

blockColor.rgb = mix(
    blockColor.rgb,
    texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY), 0.0).rgb,
    cloudFogAmount
);

blockColor.a *= 1.0 - smoothstep(0.72, 1.0, cloudFogAmount);
