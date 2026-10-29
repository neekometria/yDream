// Venus and Mars skies, built from NASA atmospheric data.
//
// Venus: about 96.5 % CO2 and 3.5 % N2; surface pressure about 92 times Earth's.
// The sulfuric-acid clouds (about 45 to 70 km up) are opaque and reflect roughly 75 %
// of the sunlight. At ground level the sky is a diffuse, dim, yellow-orange glow and
// the sun is a faint disk, so there are no hard shadows and no visible stars.
//
// Mars: about 95 % CO2, 3 % N2, 1.6 % Ar; mean surface pressure about 600 Pa (0.6 % of
// Earth's); scale height about 11 km. Suspended iron-rich dust (about 1.5 um across)
// makes the daytime sky tawny. Near the sun the sky glows blue, and sunsets are blue.

vec3 venusSkyColor(vec3 worldDir, float skyElev, vec3 sunDir, float daylight,
                   vec3 zenith, vec3 horizon, float haze) {
    float up = clamp(skyElev, 0.0, 1.0);

    // Light crosses more of the haze toward the horizon.
    float path = 1.0 - exp(-haze * 2.2 * pow(1.0 - up, 1.4));
    vec3 sky = mix(zenith, horizon, clamp(path, 0.0, 1.0));

    // Thick, cloud-filtered air is strongly desaturated.
    sky = mix(vec3(luma(sky)), sky, 0.60);

    // Wide forward-scatter glow toward the sun, through the aerosol.
    float cosSun = clamp(dot(worldDir, sunDir), -1.0, 1.0);
    float sunAngle = acos(cosSun);
    float glow = hgPhase(cosSun, 0.80) * 0.10 + exp(-sunAngle * 2.6) * 0.16;
    sky += vec3(1.0, 0.80, 0.46) * (glow * (0.55 + 0.45 * daylight));

    // Diffuse light changes little from day to night on Venus; the air stays bright.
    return sky * mix(0.70, 1.0, daylight);
}

float venusSunTransmittance(float sunElev, float opacity) {
    // Sunlight passes through the cloud deck along a path that lengthens toward the horizon.
    return exp(-opacity * 1.1 / max(sunElev, 0.12));
}

vec3 marsSkyColor(vec3 worldDir, float skyElev, vec3 sunDir, float daylight,
                  vec3 zenith, vec3 horizon, float dustTau, float haze) {
    float up = clamp(skyElev, 0.0, 1.0);

    // Dust builds up toward the horizon, where the air path is longest.
    float path = pow(1.0 - up, 1.7);
    float dust = 1.0 - exp(-dustTau * haze * (0.6 + 1.6 * path));
    vec3 sky = mix(zenith, horizon, clamp(dust, 0.0, 1.0));

    // Fine dust scatters blue forward: a blue aureole around the sun, strongest at sunset.
    float cosSun = clamp(dot(worldDir, sunDir), -1.0, 1.0);
    float sunAngle = acos(cosSun);
    float aureole = exp(-sunAngle * 7.0) * 0.75 + hgPhase(cosSun, 0.75) * 0.10;
    aureole *= 0.55 + 0.45 * (1.0 - daylight);
    return mix(sky, vec3(0.50, 0.60, 0.82), clamp(aureole, 0.0, 0.85));
}
