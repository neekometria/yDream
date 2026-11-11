// Water surface motion derived ONLY from the pack's own noise texture.
//
// An earlier experiment sampled the vanilla animated strips (water_still /
// water_flow) as low-frequency height fields. That path is impossible on this
// Iris build: bindings with arbitrary sampler names are not applied (empirical:
// cloudNoise never bound while gaux2 works), so those samplers returned
// whatever texture was left on the unit -- garbage that flickered in several
// colours and produced blocky patches that swam with the camera. The classic
// noisetex octaves give the same look with a sampler that is always bound
// (texture.noise reaches every program, including the DH ones).
#ifndef YDREAM_WATER_MOTION_INCLUDED
#define YDREAM_WATER_MOTION_INCLUDED

// pos is (x, z, y): .xy is the horizontal plane, .z the height. The classic
// "- pos.z * 0.2" offsets the pattern with altitude so vertical faces do not
// smear the surface waves.
vec3 ydr_water_texture_normal(vec3 pos, vec2 flowDirection, float flowAmount, float visibleSky) {
    float speed = frameTimeCounter * .025;
    vec2 basePos = pos.xy - pos.z * 0.2;
    vec2 wave_1 = texture2D(noisetex, (basePos * 0.05) + vec2(speed, speed)).rg - .5;
    vec2 wave_2 = texture2D(noisetex, (basePos * 0.03125) - speed).rg - .5;
    vec2 wave_3 = texture2D(noisetex, (basePos * 0.125) + vec2(speed, -speed)).rg - .5;
    wave_3 *= 0.66 * (1.0 - smoothstep(18.0, 95.0, gl_FogFragCoord));

    vec2 partialWave = wave_1 + wave_2 + wave_3;

    #ifndef VANILLA_WATER
        vec2 wave_4 = texture2D(noisetex, (basePos * 0.34) + vec2(-speed * 2.3, speed * 1.7)).rg - .5;
        wave_4 *= 0.35 * (1.0 - smoothstep(24.0, 110.0, gl_FogFragCoord));
        partialWave += wave_4;
    #endif

    partialWave *= mix(1.0, 0.22, smoothstep(28.0, 170.0, gl_FogFragCoord));

    float flowMix = clamp(flowAmount * WATER_FLOW_STRENGTH, 0.0, 1.0);
    if (flowMix > 0.001) {
        vec2 flowPos = vec2(dot(basePos, flowDirection), dot(basePos, vec2(-flowDirection.y, flowDirection.x)));
        float meander = texture2D(noisetex, vec2(flowPos.x * 0.004, 0.37) + vec2(frameTimeCounter * 0.004, 0.0)).r - 0.5;
        flowPos.y += meander * 2.2;
        float flowSpeed = frameTimeCounter * 0.10;
        vec2 flowWave1 = texture2D(noisetex, flowPos * vec2(0.012, 0.06) - vec2(flowSpeed * 1.7, flowSpeed * 0.22)).rg - 0.5;
        vec2 flowWave2 = texture2D(noisetex, flowPos * vec2(0.025, 0.10) - vec2(flowSpeed * 2.9, flowSpeed * 0.12)).rg - 0.5;
        vec2 directionalWave = (flowWave1 + flowWave2 * 0.65) * 1.15;
        directionalWave *= mix(1.0, 0.30, smoothstep(28.0, 170.0, gl_FogFragCoord));
        partialWave = mix(partialWave, directionalWave + partialWave * 0.40, flowMix * 0.80);
    }

    return normalize(vec3(partialWave,
        WATER_TURBULENCE - (rainStrength * 0.6 * WATER_TURBULENCE * visibleSky)));
}

#endif
