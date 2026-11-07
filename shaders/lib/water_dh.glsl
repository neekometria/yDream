#if SUN_REFLECTION == 1
    #if !defined NETHER && !defined THE_END
        float sun_reflection(vec3 fragpos) {
            vec3 astroLightPos = worldTime > 12900 ? moonPosition : sunPosition;
            float astroAlignment = clamp(dot(normalize(fragpos), normalize(astroLightPos)), 0.0, 1.0);
            return (pow(astroAlignment, 700.0) * 2.4 + pow(astroAlignment, 70.0) * 0.28) *
                SUN_GLINT_STRENGTH * (1.0 - rainStrength);
        }
    #endif
#endif

vec3 normal_waves_dh(vec3 pos) {
    vec2 wave_2 = texture2D(noisetex, ((pos.xy - pos.z * 0.2) * 0.03125) - (frameTimeCounter * .025)).rg - .5;
    vec3 finalWave = vec3(wave_2, WATER_TURBULENCE);
    return normalize(finalWave);
}

vec3 refraction(vec3 fragpos, vec3 color, vec3 refraction) {
    vec2 pos = gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY);
    #if REFRACTION == 1
        pos += refraction.xy * (0.075 / (1.0 + length(fragpos) * 0.4));
    #endif

    float water_absortion = 0.0;
    if (isEyeInWater == 0) {
        float water_distance = 2.0 * dhNearPlane * dhFarPlane / (dhFarPlane + dhNearPlane - (2.0 * gl_FragCoord.z - 1.0) * (dhFarPlane - dhNearPlane));
        float earth_distance = texture2D(dhDepthTex1, pos.xy).r;
        earth_distance = 2.0 * dhNearPlane * dhFarPlane / (dhFarPlane + dhNearPlane - (2.0 * earth_distance - 1.0) * (dhFarPlane - dhNearPlane));
        water_absortion = (earth_distance - water_distance) * 0.5;
        water_absortion *= water_absortion;
        water_absortion = (1.0 / -((water_absortion * WATER_ABSORPTION) + 1.125)) + 1.0;
    }
    return mix(texture2D(gaux1, pos.xy).rgb, color, water_absortion);
}

vec3 get_normals(vec3 bump, vec3 fragpos) {
    float NdotE = abs(dot(waterNormal, normalize(fragpos)));
    bump *= vec3(NdotE) + vec3(0.0, 0.0, 1.0 - NdotE);

    mat3 tbn_matrix = mat3(
        tangent.x, binormal.x, waterNormal.x,
        tangent.y, binormal.y, waterNormal.y,
        tangent.z, binormal.z, waterNormal.z
    );
    return normalize(bump * tbn_matrix);
}

vec3 water_shader_dh(
    vec3 fragpos,
    vec3 normal,
    vec3 color,
    vec3 sky_reflect,
    vec3 reflected,
    float fresnel,
    float visibleSky,
    float dither,
    vec3 lightColor
) {
    vec3 result = color;

    #if WATER_REFLECT_FAST == 1
        vec3 skyReflect = sky_reflect * visibleSky;
        if (isEyeInWater == 0) {
            vec3 screen = camera_to_screen(fragpos + reflected * 768.0);
            vec2 uv = clamp(screen.xy, 0.001, 0.999);
            float d = texture2D(dhDepthTex1, uv).r;
            float infinite = step(0.999999, d);
            vec3 reflectColor = texture2D(gaux1, uv).rgb;
            reflectColor = mix(reflectColor, skyReflect, infinite);

            #if WATER_REFLECTION_RESOLUTION < 100
                vec2 blurOffset = vec2(pixelSizeX, pixelSizeY) * WATER_REFLECT_BLUR;
                vec3 blurred = texture2D(gaux1, clamp(uv + blurOffset, 0.001, 0.999)).rgb;
                blurred = mix(blurred, skyReflect, infinite);
                reflectColor = mix(reflectColor, blurred, 0.5);
            #endif

            #ifdef VANILLA_WATER
                fresnel *= 0.8;
            #endif
            result = mix(color, reflectColor, fresnel * REFLEX_INDEX);
        } else {
            // Debaixo d'água não há superfície acima da câmera para o tap
            // screen-space acertar: mantém o reflexo do céu como antes.
            result = mix(color, skyReflect, 0.75);
        }
    #endif

    // modos 2/3: o SSR roda no composite6 (ver common/reflection_fragment.glsl).

    #if SUN_REFLECTION == 1 && !defined NETHER && !defined THE_END
        result += vec3(sun_reflection(reflect(normalize(fragpos), normal))) *
            lightColor * visibleSky * (1.0 - 0.9 * float(WATER_REFLECT_BUFFER));
    #endif

    return result;
}