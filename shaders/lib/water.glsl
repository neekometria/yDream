uniform mat4 gbufferModelViewInverse;

// NÃO redeclare dhDepthTex1 / dhNearPlane / dhFarPlane aqui:
// eles já são declarados em water_blocks_fragment.glsl (pai deste include).
// Em GLSL 120 uma uniform não pode ser redeclarada.

float linearizeDepth(float depth) {
    return gbufferProjection[3][2] / (gbufferProjection[2][2] + 2.0 * depth - 1.0);
}

vec2 waterFlowDirection = vec2(1.0, 0.0);
float waterFlowAmount = 0.0;

vec3 bedWorldPosition(vec2 sampleUV, float depthValue) {
    vec4 clip = vec4(sampleUV * 2.0 - 1.0, depthValue * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * clip;
    viewPos /= viewPos.w;
    return (gbufferModelViewInverse * vec4(viewPos.xyz, 1.0)).xyz;
}

float bed_height_gradient(vec2 uv, float radiusPixels, float surfaceDepth, out vec2 gradient) {
    gradient = vec2(0.0);

    vec2 stepUV = vec2(pixelSizeX, pixelSizeY) * radiusPixels;
    float depthW = texture2D(depthtex0, uv - vec2(stepUV.x, 0.0)).r;
    float depthE = texture2D(depthtex0, uv + vec2(stepUV.x, 0.0)).r;
    float depthS = texture2D(depthtex0, uv - vec2(0.0, stepUV.y)).r;
    float depthN = texture2D(depthtex0, uv + vec2(0.0, stepUV.y)).r;
    float maxDepth = max(max(depthW, depthE), max(depthS, depthN));
    float minDepth = min(min(depthW, depthE), min(depthS, depthN));
    if (maxDepth > 0.99999) return 0.0;

    float confidence = smoothstep(surfaceDepth - 0.0002, surfaceDepth, minDepth);

    vec3 posW = bedWorldPosition(uv - vec2(stepUV.x, 0.0), depthW);
    vec3 posE = bedWorldPosition(uv + vec2(stepUV.x, 0.0), depthE);
    vec3 posS = bedWorldPosition(uv - vec2(0.0, stepUV.y), depthS);
    vec3 posN = bedWorldPosition(uv + vec2(0.0, stepUV.y), depthN);

    vec2 u = posE.xz - posW.xz;
    vec2 v = posN.xz - posS.xz;
    float heightU = posE.y - posW.y;
    float heightV = posN.y - posS.y;

    float det = u.x * v.y - u.y * v.x;
    float uLen2 = dot(u, u);
    float vLen2 = dot(v, v);

    confidence *= smoothstep(1e-4, 1e-3, abs(det));
    confidence *= smoothstep(0.0025, 0.01, min(uLen2, vLen2));
    if (confidence < 0.001 || abs(det) < 1e-4) return 0.0;

    gradient = vec2(
        (heightU * v.y - heightV * u.y) / det,
        (heightV * u.x - heightU * v.x) / det
    );
    return confidence;
}

void detect_river_flow(vec3 surfacePos, out vec2 flowDirection, out float flowAmount) {
    flowDirection = vec2(1.0, 0.0);
    flowAmount = 0.0;

    vec2 uv = gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY);
    float surfaceDepth = gl_FragCoord.z;

    float bedDepth = texture2D(depthtex0, uv).r;
    if (bedDepth > 0.99999 || bedDepth < surfaceDepth) return;

    vec3 bedPos = bedWorldPosition(uv, bedDepth) + cameraPosition;
    float waterDepth = surfacePos.y - bedPos.y;
    if (waterDepth < 0.04 || waterDepth > 6.0) return;

    vec2 gradientSum = vec2(0.0);
    float weightSum = 0.0;
    float magnitudeSum = 0.0;

    for (int i = 0; i < 3; i++) {
        float radius = 3.0;
        float tapWeight = 0.3;
        if (i == 1) { radius = 10.0; tapWeight = 0.6; }
        else if (i == 2) { radius = 26.0; tapWeight = 1.0; }

        vec2 gradient;
        float confidence = bed_height_gradient(uv, radius, surfaceDepth, gradient);
        float tap = tapWeight * confidence;
        gradientSum += gradient * tap;
        magnitudeSum += length(gradient) * tap;
        weightSum += tap;
    }

    if (weightSum < 0.001) return;
    vec2 gradient = gradientSum / weightSum;
    float slope = length(gradient);
    if (!(slope >= 0.003 && slope <= 1.5)) return;

    float coherence = clamp(length(gradientSum) / max(magnitudeSum, 1e-5), 0.0, 1.0);
    flowDirection = normalize(-gradient);
    flowAmount = smoothstep(0.004, 0.08, slope) *
        smoothstep(0.05, 0.20, waterDepth) *
        (1.0 - smoothstep(3.0, 6.0, waterDepth)) *
        smoothstep(0.15, 0.55, coherence) *
        clamp(weightSum / 1.9, 0.0, 1.0);
}

float scene_depth_sky(vec2 uv) {
    float d = texture2D(depthtex1, uv).r;
    #ifdef DISTANT_HORIZONS
        float dd = texture2D(dhDepthTex1, uv).r;
        if (dd < 0.999999) return dd;
    #endif
    return d;
}

#if SUN_REFLECTION == 1
    #if !defined NETHER && !defined THE_END
        float sun_reflection(vec3 reflectedDir) {
            vec3 astroDir = normalize(mix(moonPosition, sunPosition, step(0.5, dayNightMix)));
            float alignment = clamp(dot(normalize(reflectedDir), astroDir), 0.0, 1.0);
            float astroElevation = dot(astroDir, upVector);
            float astroFade = smoothstep(-0.02, 0.10, astroElevation);
            float lowAstro = 1.0 - smoothstep(0.05, 0.40, astroElevation);

            float core = pow(alignment, 700.0);
            float body = pow(alignment, 70.0);
            float sheen = pow(alignment, 14.0);
            float glint = core * 2.4 * (1.0 - 0.45 * lowAstro) + body * 0.28 * (1.0 + 0.5 * lowAstro) + sheen * 0.05 * lowAstro;

            #if YDREAM_GLITTER == 1
                vec2 glitterPos = worldposition.xz * 1.7 + vec2(frameTimeCounter * 0.11, frameTimeCounter * -0.07);
                vec2 noiseA = texture2D(noisetex, glitterPos * 0.21).rg;
                vec2 noiseB = texture2D(noisetex, glitterPos.yx * 0.33 - frameTimeCounter * 0.02).rg;
                float sparkle = smoothstep(0.62, 0.95, noiseA.r * noiseB.g * 1.9);
                glint *= 0.55 + sparkle * 1.6;
            #endif

            return glint * SUN_GLINT_STRENGTH * astroFade * (1.0 - rainStrength);
        }
    #endif
#endif

vec3 normal_waves(vec3 pos, vec2 flowDirection, float flowAmount) {
    float speed = frameTimeCounter * .025;
    vec2 wave_1 = texture2D(noisetex, ((pos.xy - pos.z * 0.2) * 0.05) + vec2(speed, speed)).rg - .5;
    vec2 wave_2 = texture2D(noisetex, ((pos.xy - pos.z * 0.2) * 0.03125) - speed).rg - .5;
    vec2 wave_3 = texture2D(noisetex, ((pos.xy - pos.z * 0.2) * 0.125) + vec2(speed, -speed)).rg - .5;
    wave_3 *= 0.66 * (1.0 - smoothstep(18.0, 95.0, gl_FogFragCoord));

    vec2 partialWave = wave_1 + wave_2 + wave_3;

    #ifndef VANILLA_WATER
        vec2 wave_4 = texture2D(noisetex, ((pos.xy - pos.z * 0.2) * 0.34) + vec2(-speed * 2.3, speed * 1.7)).rg - .5;
        wave_4 *= 0.35 * (1.0 - smoothstep(24.0, 110.0, gl_FogFragCoord));
        partialWave += wave_4;
    #endif

    partialWave *= mix(1.0, 0.22, smoothstep(28.0, 170.0, gl_FogFragCoord));

    float flowMix = clamp(flowAmount * WATER_FLOW_STRENGTH, 0.0, 1.0);
    if (flowMix > 0.001) {
        vec2 basePos = pos.xy - pos.z * 0.2;
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

    return normalize(vec3(partialWave, WATER_TURBULENCE - (rainStrength * 0.6 * WATER_TURBULENCE * visibleSky)));
}

vec3 refraction(vec3 fragpos, vec3 color, vec3 refraction) {
    vec2 pos = gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY);
    #if REFRACTION == 1
        pos += refraction.xy * (0.075 / (1.0 + length(fragpos) * 0.4));
    #endif

    float water_absortion = 0.0;
    float waterThickness = 0.0;

    #if YDREAM_FOAM == 1
        float foam = 0.0;
    #endif

    if (isEyeInWater == 0) {
        float water_distance = linearizeDepth(gl_FragCoord.z);
        float earth_distance = linearizeDepth(texture2D(depthtex1, pos.xy).r);
        #if defined DISTANT_HORIZONS
            float earth_distance_dh = texture2D(dhDepthTex1, pos.xy).r;
            earth_distance_dh = 2.0 * dhNearPlane * dhFarPlane / (dhFarPlane + dhNearPlane - (2.0 * earth_distance_dh - 1.0) * (dhFarPlane - dhNearPlane));
            earth_distance = min(earth_distance, earth_distance_dh);
        #endif
        waterThickness = max(earth_distance - water_distance, 0.0);
        water_absortion = waterThickness * waterThickness;
        water_absortion = (1.0 / -((water_absortion * WATER_ABSORPTION) + 1.125)) + 1.0;

        #if YDREAM_FOAM == 1
            vec2 foamPos = worldposition.xz * 0.9 + vec2(frameTimeCounter * 0.06, frameTimeCounter * -0.04);
            float foamBase = texture2D(noisetex, foamPos * 0.11).r * 0.6 + texture2D(noisetex, foamPos.yx * 0.23).g * 0.4;
            float foamStreak = texture2D(noisetex, foamPos * 0.25 + vec2(frameTimeCounter * 0.12, 0.0)).r * 0.6 +
                texture2D(noisetex, foamPos.yx * 0.40 - vec2(0.0, frameTimeCounter * 0.09)).g * 0.4;
            float shoreDistance = waterThickness + (foamBase - 0.5) * 0.7;
            float foamShape = (1.0 - smoothstep(0.05, 0.42, shoreDistance));
            float foamDetail = smoothstep(0.32, 0.82, foamStreak);
            foam = foamShape * mix(0.35, 1.0, foamDetail) * (0.55 + 0.45 * foamBase);
            foam *= 1.0 - smoothstep(0.0, 0.02, 0.0 - waterThickness);

            if (waterFlowAmount * WATER_FLOW_STRENGTH > 0.001) {
                vec2 flowFoamPos = vec2(dot(foamPos, waterFlowDirection), dot(foamPos, vec2(-waterFlowDirection.y, waterFlowDirection.x)));
                float foamMeander = texture2D(noisetex, vec2(flowFoamPos.x * 0.004, 0.61) + vec2(frameTimeCounter * 0.004, 0.0)).r - 0.5;
                flowFoamPos.y += foamMeander * 2.2;
                float flowStreak = texture2D(noisetex, flowFoamPos * vec2(0.05, 0.10) - vec2(frameTimeCounter * 0.18, 0.0)).r;
                flowStreak = max(flowStreak, texture2D(noisetex, flowFoamPos * vec2(0.09, 0.18) - vec2(frameTimeCounter * 0.31, 0.0)).g * 0.85);
                flowStreak = smoothstep(0.55, 0.92, flowStreak);
                float flowStrength = clamp(waterFlowAmount * WATER_FLOW_STRENGTH, 0.0, 1.0);
                float flowFoam = flowStreak * flowStrength * (1.0 - smoothstep(0.10, 0.48, shoreDistance));
                foam = max(foam, flowFoam * 0.45);
            }
        #endif
    }

    float depthBlend = 1.0 - exp(-waterThickness * 0.12);
    vec3 shallowColor = color * vec3(0.95, 1.50, 1.32);
    vec3 bodyColor = mix(color, mix(shallowColor, color, depthBlend), clamp(YDREAM_WATER_DEPTH_TINT, 0.0, 1.5));

    vec3 floorColor = texture2D(gaux1, pos.xy).rgb * underwaterTransmission(water_absortion * 0.85);
    vec3 refractedColor = mix(floorColor, bodyColor, water_absortion);

    #if YDREAM_FOAM == 1
        vec3 foamLight = omniLight + directLightColor * (visibleSky * 0.6) + candleColor * 0.5;
        vec3 foamColor = vec3(0.92, 0.96, 1.0) * clamp(foamLight, vec3(0.05), vec3(1.4));
        refractedColor = mix(refractedColor, foamColor, clamp(foam, 0.0, 1.0) * 0.85);
    #endif

    return refractedColor;
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

vec3 water_shader(
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

    #if WATER_REFLECTIONS == 0
        // off
    #elif WATER_REFLECT_FAST == 1
        vec3 skyReflect = sky_reflect * visibleSky;
        if (isEyeInWater == 0) {
            #if defined DISTANT_HORIZONS
                vec3 target = fragpos + reflected * 768.0;
            #else
                vec3 target = fragpos + reflected * 76.0;
            #endif
            vec3 screen = camera_to_screen(target);
            vec2 uv = clamp(screen.xy, 0.001, 0.999);
            float d = scene_depth_sky(uv);
            float infinite = step(0.9999, d);
            vec3 reflectColor = texture2D(gaux1, uv).rgb;
            reflectColor = mix(reflectColor, skyReflect, infinite);

            // Resolução interna do modo rápido: um segundo tap suave simula um
            // buffer de reflexo menor sem custo de raymarch.
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
            // Debaixo d'água o tap screen-space não tem uma superfície acima da
            // câmera para acertar: mantém o reflexo do céu como antes.
            result = mix(color, skyReflect, 0.75);
        }
    #else
        // modos 2/3: o SSR roda no composite6 (ver common/reflection_fragment.glsl).
    #endif

    #if SUN_REFLECTION == 1 && !defined NETHER && !defined THE_END
        result += vec3(sun_reflection(reflect(normalize(fragpos), normal))) *
            lightColor * visibleSky * float(isEyeInWater == 0);
    #endif

    return result;
}

// CORREÇÃO: assinatura volta a ser vec4 — o corpo retorna `color`, que é vec4.
// (Era vec3 na entrega anterior, causando o cast implícito vec4→vec3.)
vec4 cristal_shader(
    vec3 fragpos,
    vec3 normal,
    vec4 color,
    vec3 skyReflectionColor,
    float fresnel,
    float visibleSky,
    float dither,
    vec3 lightColor
) {
    vec3 normalReflect = reflect(normalize(fragpos), normal);

    #if WATER_REFLECTIONS == 0
        color.rgb = mix(color.rgb, skyReflectionColor * visibleSky * visibleSky, fresnel);
        color.a = mix(color.a, 1.0, fresnel * .9);
        return color;
    #else
        #if defined DISTANT_HORIZONS
            vec3 target = fragpos + normalReflect * 768.0;
        #else
            vec3 target = fragpos + normalReflect * 76.0;
        #endif
        vec3 screen = camera_to_screen(target);
        vec2 uv = clamp(screen.xy, 0.001, 0.999);
        float d = scene_depth_sky(uv);
        float infinite = step(0.9999, d);
        vec3 reflectColor = texture2D(gaux1, uv).rgb;
        reflectColor = mix(reflectColor, skyReflectionColor * visibleSky * visibleSky, infinite);

        color.rgb = mix(color.rgb, reflectColor, fresnel);
        color.a = mix(color.a, 1.0, fresnel * .9);

        #if SUN_REFLECTION == 1 && !defined NETHER && !defined THE_END
            color.rgb += vec3(sun_reflection(normalReflect) * lightColor * visibleSky * (1.0 - infinite));
        #endif
        return color;
    #endif
}