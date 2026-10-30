vec3 csWorld = (gbufferModelViewInverse * viewPosition).xyz + cameraPosition;
vec3 csLight = normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz) * mix(-1.0, 1.0, step(0.5, dayNightMix));
float csT = (CLOUD_SHADOW_PLANE_CENTER - csWorld.y) / max(csLight.y, 0.15);
vec2 csPos = csWorld.xz + csLight.xz * csT;

float csNoise = texture2DLod(gaux2, csPos * CLOUD_NOISE_SCALE + (frameTimeCounter * CLOUD_HI_FACTOR), 0.0).r;

#if V_CLOUDS == 2 && CLOUD_VOL_STYLE == 0
    csNoise += texture2DLod(gaux2, csPos.yx * CLOUD_NOISE_SCALE + (frameTimeCounter * CLOUD_LOW_FACTOR), 0.0).r;
    float csDetail = texture2DLod(gaux2, csPos * 0.0016 - (frameTimeCounter * CLOUD_HI_FACTOR * 1.6), 0.0).r;
    csNoise = smoothstep(0.05, 0.95, csNoise * 0.5) * 0.82 + csDetail * 0.18;
#endif

float csUmbral = clamp((((1.0 - smoothstep(0.0, 1.0, rainStrength)) * 0.3) + 0.22) / CLOUD_DENSITY, 0.0, 0.99);
float csCoverage = smoothstep(csUmbral, csUmbral + 0.14, csNoise);
float csAmount = csCoverage * (float(CLOUD_GROUND_SHADOWS) * 0.01) * smoothstep(0.08, 0.30, csLight.y);

directLightStrength *= 1.0 - csAmount;
