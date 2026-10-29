vec3 underwaterFogColor(vec3 lightColor, float skyBrightness) {
    float lightLuma = dot(lightColor, vec3(0.2126, 0.7152, 0.0722));
    float dayFactor = clamp(lightLuma * 1.18, 0.0, 1.0);
    float lightLevel = mix(0.10, 1.0, dayFactor);
    float skyLevel = mix(0.45, 1.0, clamp(skyBrightness, 0.0, 1.0));

    return WATER_COLOR * (lightLevel * skyLevel * UNDERWATER_BRIGHTNESS);
}

vec3 underwaterTransmission(float absorbAmount) {
    return mix(vec3(1.0), vec3(0.30, 0.70, 1.0), clamp(absorbAmount, 0.0, 1.0));
}
