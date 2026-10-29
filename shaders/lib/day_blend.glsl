uniform float sunElevation;
uniform float auroraBiomeFade;
uniform float nightSelect;

vec3 dayBlend(vec3 sunset, vec3 day, vec3 night) {

    vec3 dayColor = mix(sunset, day, dayMixer);
    vec3 nightColor = mix(sunset, night, nightMixer);

    return mix(dayColor, nightColor, nightSelect);
}

float dayBlendFloat(float sunset, float day, float night) {

    float dayValue = mix(sunset, day, dayMixer);
    float nightValue = mix(sunset, night, nightMixer);

    return mix(dayValue, nightValue, nightSelect);
}

vec3 dayBlendVoxy(vec3 sunset, vec3 day, vec3 night, float dayMixerV, float nightMixerV, float dayMomentV) {

    vec3 dayColor = mix(sunset, day, dayMixerV);
    vec3 nightColor = mix(sunset, night, nightMixerV);

    return mix(dayColor, nightColor, step(0.5, dayMomentV));
}

float dayBlendFloatVoxy(float sunset, float day, float night, float dayMixerV, float nightMixerV, float dayMomentV) {

    float dayValue = mix(sunset, day, dayMixer);
    float nightValue = mix(sunset, night, nightMixer);

    return mix(dayValue, nightValue, step(0.5, dayMoment));
}

float skyDayAmount() {
    return smoothstep(0.03, 0.42, sunElevation);
}

float skyNightAmount() {
    return (1.0 - smoothstep(-0.30, 0.03, sunElevation));
}

vec3 skyBlend(vec3 sunset, vec3 day, vec3 night, vec3 control) {
    float t = skyDayAmount();
    float oneMinus = 1.0 - t;
    vec3 dayColor = sunset * (oneMinus * oneMinus) + control * (2.0 * t * oneMinus) + day * (t * t);
    vec3 nightColor = mix(sunset, night, skyNightAmount());

    return mix(dayColor, nightColor, step(sunElevation, 0.03));
}

vec3 skyBlendVoxy(vec3 sunset, vec3 day, vec3 night, vec3 control, float elevation) {
    float t = smoothstep(0.03, 0.42, elevation);
    float oneMinus = 1.0 - t;
    vec3 dayColor = sunset * (oneMinus * oneMinus) + control * (2.0 * t * oneMinus) + day * (t * t);
    vec3 nightColor = mix(sunset, night, (1.0 - smoothstep(-0.30, 0.03, elevation)));

    return mix(dayColor, nightColor, step(elevation, 0.03));
}
