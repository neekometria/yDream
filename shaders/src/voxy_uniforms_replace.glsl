    float hour_world = worldTime * 0.001;
    float dayMomentV = hour_world * 0.04166666666666667;

    float moment_aux = dayMomentV - 0.25;
    float moment_aux_2 = moment_aux * moment_aux;
    float dayMixerV = clamp(-moment_aux_2 * 20.0 + 1.25, 0.0, 1.0);

    float moment_aux_3 = dayMomentV - 0.75;
    float moment_aux_4 = moment_aux_3 * moment_aux_3;
    float nightMixerV = clamp(-moment_aux_4 * 50.0 + 3.125, 0.0, 1.0);

    float sky_day_frac = fract(float(worldTime) / 24000.0 - 0.25);
    float sky_angle = (sky_day_frac * 2.0 + 0.5 - cos(sky_day_frac * 3.141592653589793) * 0.5) / 3.0;
    float sunElevationV = sin(6.283185307179586 * (sky_angle + 0.25));

    uint face = parameters.face;
    uint customId = parameters.customId;
    vec4 tintColor = parameters.tinting;
    vec2 lmcoord = parameters.lightMap;
