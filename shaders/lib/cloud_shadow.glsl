#ifndef YDREAM_CLOUD_SHADOW_INCLUDED
#define YDREAM_CLOUD_SHADOW_INCLUDED

#include "/lib/cloud_noise.glsl"

#if defined CLOUD_SHADOWS_ON
float cloud_shadow_amount(vec3 worldPos, vec3 lightDir) {
    if (lightDir.y < 0.02) {
        return 0.0;
    }

    float t = (CLOUD_SHADOW_PLANE_CENTER - worldPos.y) / max(lightDir.y, 0.15);
    vec2 pos = worldPos.xz + lightDir.xz * t;

    float fieldValue = cloud_field(pos);
    float detailValue = texture2DLod(YDREAM_CLOUD_NOISE_TEX, pos * 0.0016 - (frameTimeCounter * CLOUD_HI_FACTOR * 1.6), 0.0).r;
    float noiseValue = mix(fieldValue, detailValue, CLOUD_DETAIL_WEIGHT);

    // Mantém a mesma lógica do volumetric_clouds_vertex para alinhar as aberturas
    float umbral = CLOUD_BASE_UMBRAL;
    umbral /= CLOUD_DENSITY;

    float coverage = smoothstep(umbral, umbral + 0.14, noiseValue);
    float amount = coverage * (float(CLOUD_GROUND_SHADOWS) * 0.01) * smoothstep(0.08, 0.30, lightDir.y);

    return clamp(amount, 0.0, 1.0);
}
#endif

#endif