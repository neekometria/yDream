uniform int frameMod;

#if MC_VERSION >= 11300
    uniform float ditherShift;
#else
    float ditherShift = frameMod * 0.1875;
#endif

float hash12(vec2 point)
{
    point = 0.0002314814814814815 * point + vec2(0.25, 0.0);
    float state = fract(dot(point * point, vec2(3571.0)));
    return fract(state * state * 7142.0);
}

float hash13(vec3 point)
{
    point = fract(point * .1031);
    point += dot(point, point.zyx + 31.32);
    return fract((point.x + point.y) * point.z);
}

float rDither(vec2 point) {
    return fract(dot(point, vec2(0.75487766624669276, 0.569840290998)));
}

float dither13(vec2 point) {
    return fract(dot(point, vec2(0.3076923076923077, 0.5384615384615384)));
}

float dither17(vec2 point) {
  return fract(dot(point, vec2(0.11764705882352941, 0.4117647058823529)));
}

float semiblue(vec2 point) {
    vec2 tile = floor(point * 0.25);
    float flip = mod(tile.x + tile.y, 2.0);
    point = mix(point, point.yx, flip);

    return fract(dot(vec2(0.75487766624669276, 0.569840290998), point) + hash12(tile));
}

float ditherMakeup(vec2 point) {
    vec2 tile = floor(point * 0.125);
    float flip = mod(tile.x + tile.y, 2.0);
    vec2 rPoint = mix(point, point.yx, flip);

    return fract(
        dot(vec2(0.24512233375330728, 0.4301597090019468), rPoint) +
        dot(vec2(0.735151469707489, 0.737424373626709), tile)
    );
}

float shiftedRDither(vec2 point) {
    return fract(ditherShift + dot(point, vec2(0.75487766624669276, 0.569840290998)));
}

float shiftedDither13(vec2 point)
{
    return fract(ditherShift + dot(point, vec2(0.3076923076923077, 0.5384615384615384)));
}

float shiftedDither17(vec2 point) {
    return fract(ditherShift + dot(point, vec2(0.11764705882352941, 0.4117647058823529)));
}

float shiftedSemiblue(vec2 point) {
    point = point + vec2(frameMod * 5.0, frameMod * 15.0);
    vec2 tile = floor(point * 0.25);
    float flip = mod(tile.x + tile.y, 2.0);
    point = mix(point, point.yx, flip);

    return fract(ditherShift + dot(vec2(0.75487766624669276, 0.569840290998), point) + hash12(tile));
}

float shiftedDitherMakeup(vec2 point) {
    point = point + vec2(frameMod * 9.0, frameMod * 15.0);
    vec2 tile = floor(point * 0.125);
    float flip = mod(tile.x + tile.y, 2.0);
    vec2 zw = mix(point, point.yx, flip);

    return fract(
        ditherShift +
        dot(vec2(0.24512233375330728, 0.4301597090019468), zw) +
        dot(vec2(0.9996657054871321, 0.9998746076598763), tile)
    );
}
