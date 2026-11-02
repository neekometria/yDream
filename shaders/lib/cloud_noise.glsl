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

// Shaped 0..1 cloud field at a horizontal world position. Requires the gaux2
// sampler and frameTimeCounter to be in scope.
float cloud_field(vec2 posXZ) {
    float value = texture2DLod(gaux2, posXZ * CLOUD_NOISE_SCALE + (frameTimeCounter * CLOUD_HI_FACTOR), 0.0).r;
    value += texture2DLod(gaux2, cloud_noise_uv(posXZ) * (CLOUD_NOISE_SCALE * 1.37) + (frameTimeCounter * CLOUD_LOW_FACTOR), 0.0).r;
    return smoothstep(0.05, 0.95, value * 0.5);
}

#endif
