// Cloud shadows received by the terrain.
//
// Shared by the real chunks (applied to directLightStrength in the vertex
// stage) and by the Distant Horizons LOD terrain (applied per fragment), so
// both use the same cloud field projected along the same sun/moon direction.
// worldPos is the absolute world position of the shaded surface and lightDir the
// direction of the active light (sun by day, the opposite direction by night).
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
    float detailValue = texture2DLod(gaux2, pos * 0.0016 - (frameTimeCounter * CLOUD_HI_FACTOR * 1.6), 0.0).r;
    float noiseValue = mix(fieldValue, detailValue, CLOUD_DETAIL_WEIGHT);

    float umbral = clamp(CLOUD_BASE_UMBRAL + (1.0 - smoothstep(0.0, 1.0, rainStrength)) * 0.3, 0.0, 0.99);
    umbral /= CLOUD_DENSITY;

    float coverage = smoothstep(umbral, umbral + 0.14, noiseValue);
    float amount = coverage * (float(CLOUD_GROUND_SHADOWS) * 0.01) * smoothstep(0.08, 0.30, lightDir.y);

    return clamp(amount, 0.0, 1.0);
}
#endif

#endif
