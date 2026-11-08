// Shared cloud noise helpers.
//
// The two base octaves used to be the same texture sampled at posXZ and at
// posXZ.yx. Swapping the axes mirrors the field about the x = z diagonal, so
// the whole sky (and the cloud shadows on the ground) showed the same diagonal
// pattern repeating. Rotating the second octave by ~37 degrees and giving it a
// different scale removes that symmetry, which is what makes the default cloud
// layout read as separate banks instead of a regular grid.
#ifndef YDREAM_CLOUD_NOISE_INCLUDED
#define YDREAM_CLOUD_NOISE_INCLUDED

vec2 cloud_noise_uv(vec2 p) {
    return vec2(p.x * 0.8 - p.y * 0.6, p.x * 0.6 + p.y * 0.8);
}

// Bounded per-bank variation. This is a displacement of the noise coordinates,
// not a speed: it does not get multiplied by time, so it never accumulates and
// the layer keeps advecting as one coherent field. Each bank is nudged a little
// differently and wobbles slowly around its path. The previous version scaled
// the drift by a spatially varying wind, which stretched and sheared the noise
// over time and produced the odd shapes and the broken horizon.
// Depends only on posXZ, so every ray, shadow sample and light sample agrees.
vec2 cloud_warp(vec2 posXZ) {
    vec2 q = posXZ * CLOUD_WIND_SCALE;
    float a = texture2DLod(gaux2, q + vec2(0.37, 0.71), 0.0).r - 0.5;
    float b = texture2DLod(gaux2, q + vec2(0.83, 0.19), 0.0).r - 0.5;
    float phase = frameTimeCounter * CLOUD_WIND_TIME + a * 6.2831853;
    vec2 wobble = vec2(sin(phase), cos(phase * 0.73 + b * 6.2831853));
    return (vec2(a, b) * 2.0 + wobble * 0.5) * CLOUD_WIND_AMP;
}

// Shaped 0..1 cloud field at a horizontal world position. Requires the gaux2
// sampler and frameTimeCounter to be in scope.
float cloud_field(vec2 posXZ) {
    float time = frameTimeCounter;
    vec2 warp = cloud_warp(posXZ);
    vec2 p1 = posXZ * CLOUD_NOISE_SCALE + time * CLOUD_HI_FACTOR + warp;
    vec2 p2 = cloud_noise_uv(posXZ) * (CLOUD_NOISE_SCALE * 1.7) + time * CLOUD_LOW_FACTOR * 1.2 + warp;

    float base = texture2DLod(gaux2, p1, 0.0).r;
    float detail = texture2DLod(gaux2, p2, 0.0).r;

    // Combine them smoothly
    float value = mix(base, detail, CLOUD_DETAIL_WEIGHT);

    // Sharpen the contrast for distinct cloud shapes
    float rainAmount = clamp(rainStrength, 0.0, 1.0);
    float low = mix(0.45, 0.15, rainAmount);
    float high = mix(0.85, 0.65, rainAmount);

    return smoothstep(low, high, value);
}

#endif
