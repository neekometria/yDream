vec3 ydreamFogColor(vec3 fogTex, float sunScatter, float golden, float rain, float dayAmount) {
    float scatter = sunScatter * dayAmount * (1.0 - rain);
    vec3 warm = mix(vec3(1.06, 1.0, 0.94), vec3(1.18, 0.97, 0.78), golden);
    vec3 cool = vec3(0.93, 0.98, 1.07);
    vec3 tinted = fogTex * mix(mix(vec3(1.0), cool, dayAmount * (1.0 - rain) * 0.7), warm, smoothstep(0.0, 0.55, scatter * 1.6));
    return tinted * (1.0 + scatter * 0.20 * FOG_SUN_SCATTER);
}
