// ============================================================================
// Atmosfera física do céu (Rayleigh + Mie). Funções puras de direção, sem uniforms.
// Compartilhadas por lib/sky.glsl (céu renderizado).
// ============================================================================
#ifndef YDREAM_SKY_ATMOSPHERE_INCLUDED
#define YDREAM_SKY_ATMOSPHERE_INCLUDED

float hgPhase(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (12.566370614359172 * pow(max(1.0 + g2 - 2.0 * g * cosTheta, 0.0001), 1.5));
}

vec3 atmosphericSky(float viewElevation, float cosSun, float sunAltitude, float turbidity) {
    float viewCos = clamp(viewElevation, 0.0, 1.0);
    float viewZenith = degrees(acos(viewCos));
    float airmassView = 1.0 / (viewCos + 0.50572 * pow(max(96.07995 - viewZenith, 0.5), -1.6364));

    float sunCos = clamp(sunAltitude, 0.0, 1.0);
    float sunZenith = degrees(acos(sunCos));
    float airmassSun = 1.0 / (sunCos + 0.50572 * pow(max(96.07995 - sunZenith, 0.5), -1.6364));

    vec3 tauRayleigh = vec3(0.0464, 0.108, 0.265);
    float tauMie = 0.006 * turbidity;
    vec3 tauTotal = tauRayleigh + vec3(tauMie);

    float lowAir = mix(0.28, 1.0, exp(-viewCos * 3.0));
    vec3 sunTransmission = exp(-tauTotal * airmassSun * lowAir);

    float phaseRayleigh = 0.05968310365946075 * (1.0 + cosSun * cosSun);
    float phaseMie = hgPhase(cosSun, 0.78);

    vec3 scatter = tauRayleigh * (phaseRayleigh + 0.09) + vec3(tauMie * phaseMie * 0.55);
    vec3 inscatter = (1.0 - exp(-tauTotal * airmassView)) / tauTotal;

    return sunTransmission * scatter * inscatter;
}

#endif
