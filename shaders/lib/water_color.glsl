// Unified water fog/inscatter color helpers.
// Depends on config uniforms/macros (WATER_COLOR, UNDERWATER_BRIGHTNESS, ...).
#ifndef YDREAM_WATER_COLOR_INCLUDED
#define YDREAM_WATER_COLOR_INCLUDED

vec3 underwaterFogColor(vec3 lightColor, float skyBrightness) {
    float lightLuma = dot(lightColor, vec3(0.2126, 0.7152, 0.0722));
    float dayFactor = clamp(lightLuma * 1.18, 0.0, 1.0);
    float lightLevel = mix(0.10, 1.0, dayFactor);
    float skyLevel = mix(0.45, 1.0, clamp(skyBrightness, 0.0, 1.0));

    vec3 tint = WATER_COLOR * (lightLevel * skyLevel * UNDERWATER_BRIGHTNESS);
    // Olhando para cima o inscatter e a luz do ceu espalhada em poucos metros,
    // nao a cor do volume: sem dessaturar, a superficie vista de baixo saia
    // azul-marinho chapada em vez do ciano luminoso de agua rasa.
    float tintLuma = dot(tint, vec3(0.2126, 0.7152, 0.0722));
    return mix(tint, (tint + vec3(tintLuma)) * 1.6 + vec3(0.02, 0.06, 0.07), 0.75);
}

// Legacy tint used by simplified/fallback underwater paths.
vec3 underwaterTransmission(float absorbAmount) {
    return mix(vec3(1.0), vec3(0.30, 0.70, 1.0), clamp(absorbAmount, 0.0, 1.0));
}

// Base inscatter/fog radiance for a submerged camera, before per-path
// darkening (vertical depth / view distance) is applied by the caller.
vec3 ydr_water_underwater_fog_radiance(vec3 lightColor, float skyBrightness, float cameraPosY) {
    vec3 fog = underwaterFogColor(lightColor, skyBrightness);
    // Shallow water picks up a brighter greenish tint; deep/constrained water
    // returns toward the base fog color.
    fog = mix(fog * vec3(0.85, 1.35, 1.20), fog, clamp((63.0 - cameraPosY) * 0.07, 0.0, 1.0));
    return fog;
}

#endif
