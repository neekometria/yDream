uniform mat4 gbufferModelViewInverse;

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

// Height gradient of the river bed in world space, sampled around the current
// pixel at a given screen-space radius. Returns a confidence in 0..1 instead of
// an all-or-nothing flag: the gradient near a bank, a sky tap or a grazing angle
// is unreliable, and hard accept/reject decisions used to make adjacent pixels
// flip between two different flow directions. That flip is visible as straight
// lines running across the current.
float bed_height_gradient(vec2 uv, float radiusPixels, float surfaceDepth, out vec2 gradient) {
    gradient = vec2(0.0);

    vec2 stepUV = vec2(pixelSizeX, pixelSizeY) * radiusPixels;
    float depthW = texture2D(depthtex0, uv - vec2(stepUV.x, 0.0)).r;
    float depthE = texture2D(depthtex0, uv + vec2(stepUV.x, 0.0)).r;
    float depthS = texture2D(depthtex0, uv - vec2(0.0, stepUV.y)).r;
    float depthN = texture2D(depthtex0, uv + vec2(0.0, stepUV.y)).r;
    float maxDepth = max(max(depthW, depthE), max(depthS, depthN));
    float minDepth = min(min(depthW, depthE), min(depthS, depthN));

    // Sky tap: the gradient cannot be measured across the far plane.
    if (maxDepth > 0.99999) {
        return 0.0;
    }

    // Anything closer than the water surface is a bank, a lily pad or an object
    // sitting on the water. Fade instead of rejecting, so a shoreline does not
    // draw a hard line where the flow suddenly stops.
    float confidence = smoothstep(surfaceDepth - 0.0002, surfaceDepth, minDepth);

    vec3 posW = bedWorldPosition(uv - vec2(stepUV.x, 0.0), depthW);
    vec3 posE = bedWorldPosition(uv + vec2(stepUV.x, 0.0), depthE);
    vec3 posS = bedWorldPosition(uv - vec2(0.0, stepUV.y), depthS);
    vec3 posN = bedWorldPosition(uv + vec2(0.0, stepUV.y), depthN);

    // Horizontal displacement of both tap pairs, and the height difference
    // measured along them.
    vec2 u = posE.xz - posW.xz;
    vec2 v = posN.xz - posS.xz;
    float heightU = posE.y - posW.y;
    float heightV = posN.y - posS.y;

    float det = u.x * v.y - u.y * v.x;
    float uLen2 = dot(u, u);
    float vLen2 = dot(v, v);

    // Grazing angles collapse the screen axes onto almost the same world
    // direction, so the 2x2 system becomes singular. Fade the confidence as the
    // basis becomes thin rather than switching off, and bail out before the
    // division can produce an unbounded gradient.
    confidence *= smoothstep(1e-4, 1e-3, abs(det));
    confidence *= smoothstep(0.0025, 0.01, min(uLen2, vLen2));

    if (confidence < 0.001 || abs(det) < 1e-4) {
        return 0.0;
    }

    gradient = vec2(
        (heightU * v.y - heightV * u.y) / det,
        (heightV * u.x - heightU * v.x) / det
    );

    return confidence;
}

// StreamsReflowing carves a downhill channel, but it still renders as vanilla
// water. Estimate the downhill direction from the opaque river bed instead of
// relying on a block id, so the effect also works in unmodified rivers.
void detect_river_flow(vec3 surfacePos, out vec2 flowDirection, out float flowAmount) {
    flowDirection = vec2(1.0, 0.0);
    flowAmount = 0.0;

    vec2 uv = gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY);
    float surfaceDepth = gl_FragCoord.z;

    // Water is drawn in the translucent pass, so depthtex1 already contains the
    // surface we are shading. The bed is what the opaque buffer holds.
    float bedDepth = texture2D(depthtex0, uv).r;
    if (bedDepth > 0.99999 || bedDepth < surfaceDepth) {
        return;
    }

    // bedWorldPosition() returns camera-relative coordinates while surfacePos
    // is absolute world space, so lift the bed into world space before
    // measuring the depth below the surface.
    vec3 bedPos = bedWorldPosition(uv, bedDepth) + cameraPosition;
    float waterDepth = surfacePos.y - bedPos.y;
    if (waterDepth < 0.04 || waterDepth > 6.0) {
        return;
    }

    // Several radii: a single block step dominates one tap, and nearby pixels
    // must agree so the direction does not flicker between frames. The widest
    // radius dominates because a river channel is much larger than one pixel;
    // the small radii only refine a direction that is already stable.
    vec2 gradientSum = vec2(0.0);
    float weightSum = 0.0;
    float magnitudeSum = 0.0;

    for (int i = 0; i < 3; i++) {
        float radius = 3.0;
        float tapWeight = 0.3;
        if (i == 1) {
            radius = 10.0;
            tapWeight = 0.6;
        } else if (i == 2) {
            radius = 26.0;
            tapWeight = 1.0;
        }

        vec2 gradient;
        float confidence = bed_height_gradient(uv, radius, surfaceDepth, gradient);
        float tap = tapWeight * confidence;
        gradientSum += gradient * tap;
        magnitudeSum += length(gradient) * tap;
        weightSum += tap;
    }

    if (weightSum < 0.001) {
        return;
    }

    vec2 gradient = gradientSum / weightSum;
    float slope = length(gradient);
    if (!(slope >= 0.003 && slope <= 1.5)) {
        return;
    }

    // How much the three radii agree on the direction. If one tap says a
    // different downstream than the others, the slope is ambiguous and the flow
    // is faded out instead of picking one of the two and drawing a seam.
    float coherence = clamp(length(gradientSum) / max(magnitudeSum, 1e-5), 0.0, 1.0);

    // The gradient points uphill, so the water flows the other way.
    flowDirection = normalize(-gradient);

    flowAmount = smoothstep(0.004, 0.08, slope) *
        smoothstep(0.05, 0.20, waterDepth) *
        (1.0 - smoothstep(3.0, 6.0, waterDepth)) *
        smoothstep(0.15, 0.55, coherence) *
        clamp(weightSum / 1.9, 0.0, 1.0);
}

vec3 fastRaymarch(vec3 direction, vec3 hitPoint, inout float infinite, float dither) {
    vec3 pathIncrement;
    vec3 currentMarchPoint = hitPoint;
    vec3 oldMarchPoint;
    float screenDepth;
    float depthDifference = 1.0;
    vec3 screenMarchPos = camera_to_screen(hitPoint);
    float prevScreenDepth = screenMarchPos.z;
    float hitPointDepth = screenMarchPos.z;
    bool searchFlag = false;
    bool hiddenFlag = false;
    bool firstHidden = true;
    bool outOfEyeFlag = false;
    bool toFar = false;
    vec3 lastScreenMarchPos;

    int no_hidden_steps = 0;
    bool hiddens = false;

    float currentStep = 0.1; 

    for (int i = 0; i < RAYMARCH_STEPS; i++) {
        if (searchFlag) {
            pathIncrement *= 0.5;
            currentMarchPoint += pathIncrement * sign(depthDifference);
        } else {
            oldMarchPoint = currentMarchPoint;
            float stepSize = mix(currentStep, exp2(i * 0.5 + dither) * 0.5, float(i) / 8.0);
            currentMarchPoint = hitPoint + direction * stepSize;
            pathIncrement = currentMarchPoint - oldMarchPoint;
        }

        lastScreenMarchPos = screenMarchPos;
        screenMarchPos = camera_to_screen(currentMarchPoint);

        // Aumentado de -0.1 para -0.5 para permitir que o raio saia mais da tela antes de falhar
        if (
            screenMarchPos.x < -0.5 ||
            screenMarchPos.x > 1.5 ||
            screenMarchPos.y < -0.5 ||
            screenMarchPos.y > 1.5 ||
            screenMarchPos.z < 0.0
        ) {
            outOfEyeFlag = true;
        }

        if (screenMarchPos.z > 0.9999) {
            toFar = true;
        }

        vec2 clampedUV = clamp(screenMarchPos.xy, vec2(0.001), vec2(0.999));
        screenDepth = texture2D(depthtex1, clampedUV).x;
        depthDifference = screenDepth - screenMarchPos.z;

        if (depthDifference < 0.0 && abs(screenDepth - prevScreenDepth) > abs(screenMarchPos.z - lastScreenMarchPos.z)) {
            hiddenFlag = true;
            hiddens = true;
            if (firstHidden) {
                firstHidden = false;
            }
        } else if (depthDifference > 0.0) {
            hiddenFlag = false;
            if (!hiddens) {
                no_hidden_steps++;
            }
        }

        if (searchFlag == false && depthDifference < 0.0 && hiddenFlag == false) {
            searchFlag = true;
        }

        prevScreenDepth = screenDepth;
    }

    infinite = float(screenDepth > 0.9999);

    if (outOfEyeFlag) {
        infinite = 1.0;
        return screenMarchPos; 
    } else if (toFar) {
        if (screenDepth > 0.9999) {
            infinite = 1.0;
            return screenMarchPos;
        } else if (no_hidden_steps < 3 || screenDepth > hitPointDepth) {
            return screenMarchPos;
        } else {
            infinite = 1.0;
            return vec3(1.0);
        }
    } else {
        return screenMarchPos;
    }
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
    vec2 wave_1 =
        texture2D(noisetex, ((pos.xy - pos.z * 0.2) * 0.05) + vec2(speed, speed)).rg;
    wave_1 = wave_1 - .5;
    vec2 wave_2 =
        texture2D(noisetex, ((pos.xy - pos.z * 0.2) * 0.03125) - speed).rg;
    wave_2 = wave_2 - .5;
    vec2 wave_3 =
        texture2D(noisetex, ((pos.xy - pos.z * 0.2) * 0.125) + vec2(speed, -speed)).rg;
    wave_3 = wave_3 - .5;
    wave_3 *= 0.66 * (1.0 - smoothstep(18.0, 95.0, gl_FogFragCoord));

    vec2 partialWave = wave_1 + wave_2 + wave_3;

    #ifndef VANILLA_WATER
        vec2 wave_4 =
            texture2D(noisetex, ((pos.xy - pos.z * 0.2) * 0.34) + vec2(-speed * 2.3, speed * 1.7)).rg;
        wave_4 = (wave_4 - .5) * 0.35 * (1.0 - smoothstep(24.0, 110.0, gl_FogFragCoord));
        partialWave += wave_4;
    #endif

    partialWave *= mix(1.0, 0.22, smoothstep(28.0, 170.0, gl_FogFragCoord));

    float flowMix = clamp(flowAmount * WATER_FLOW_STRENGTH, 0.0, 1.0);
    if (flowMix > 0.001) {
        // Stretch the noise along the downhill axis and scroll it downstream.
        // The base pattern above is retained so unmodified water still looks
        // like yDream water.
        vec2 basePos = pos.xy - pos.z * 0.2;
        vec2 flowPos = vec2(dot(basePos, flowDirection),
            dot(basePos, vec2(-flowDirection.y, flowDirection.x)));

        // Slow lateral meander. Without it a stretched noise is a perfectly
        // straight band along the flow axis, which reads as a drawn line rather
        // than as water. Two blocks of wobble is enough to break the ruler edge.
        float meander = texture2D(noisetex,
            vec2(flowPos.x * 0.004, 0.37) + vec2(frameTimeCounter * 0.004, 0.0)).r - 0.5;
        flowPos.y += meander * 2.2;

        float flowSpeed = frameTimeCounter * 0.10;

        // Two stretched layers at different speeds: the faster one carries the
        // motion, the slower one keeps the surface from looking like a
        // scrolling texture. The frequencies are deliberately low: a strongly
        // stretched, high-frequency noise repeats across the current and shows
        // up as thin regular bands on flowing water.
        vec2 flowWave1 = texture2D(noisetex,
            flowPos * vec2(0.012, 0.06) - vec2(flowSpeed * 1.7, flowSpeed * 0.22)).rg - 0.5;
        vec2 flowWave2 = texture2D(noisetex,
            flowPos * vec2(0.025, 0.10) - vec2(flowSpeed * 2.9, flowSpeed * 0.12)).rg - 0.5;

        vec2 directionalWave = (flowWave1 + flowWave2 * 0.65) * 1.15;
        // Same distance damping as the base waves, otherwise distant rivers
        // alias badly and turn into noise.
        directionalWave *= mix(1.0, 0.30, smoothstep(28.0, 170.0, gl_FogFragCoord));
        // Keep more of the organic base pattern: replacing it almost entirely
        // with the stretched layer is what made the current read as regular lines.
        partialWave = mix(partialWave, directionalWave + partialWave * 0.40, flowMix * 0.80);
    }

    vec3 finalWave = vec3(partialWave, WATER_TURBULENCE - (rainStrength * 0.6 * WATER_TURBULENCE * visibleSky));

    return normalize(finalWave);
}

vec3 refraction(vec3 fragpos, vec3 color, vec3 refraction) {
    vec2 pos = gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY);

    #if REFRACTION == 1
        pos = pos + refraction.xy * (0.075 / (1.0 + length(fragpos) * 0.4));
    #endif

    float water_absortion;
    float waterThickness = 0.0;

    #if YDREAM_FOAM == 1
        float foam = 0.0;
    #endif

    if (isEyeInWater == 0) {
        float water_distance = linearizeDepth(gl_FragCoord.z);
        float earth_depth = texture2D(depthtex1, pos.xy).r;
        float earth_distance = linearizeDepth(earth_depth);

        #if defined DISTANT_HORIZONS
            float earth_distance_dh = texture2D(dhDepthTex1, pos.xy).r;
            earth_distance_dh =
                2.0 * dhNearPlane * dhFarPlane / (dhFarPlane + dhNearPlane - (2.0 * earth_distance_dh - 1.0) * (dhFarPlane - dhNearPlane));
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
                vec2 flowFoamPos = vec2(dot(foamPos, waterFlowDirection),
                    dot(foamPos, vec2(-waterFlowDirection.y, waterFlowDirection.x)));
                float foamMeander = texture2D(noisetex,
                    vec2(flowFoamPos.x * 0.004, 0.61) + vec2(frameTimeCounter * 0.004, 0.0)).r - 0.5;
                flowFoamPos.y += foamMeander * 2.2;
                // Two stretched streak layers scrolling downstream at different
                // speeds, so the current reads as moving water rather than a
                // static foam texture. Keep the cross-flow frequency low so
                // the streaks merge into long ripples instead of thin bands.
                float flowStreak = texture2D(noisetex,
                    flowFoamPos * vec2(0.05, 0.10) - vec2(frameTimeCounter * 0.18, 0.0)).r;
                flowStreak = max(flowStreak, texture2D(noisetex,
                    flowFoamPos * vec2(0.09, 0.18) - vec2(frameTimeCounter * 0.31, 0.0)).g * 0.85);
                flowStreak = smoothstep(0.55, 0.92, flowStreak);
                float flowStrength = clamp(waterFlowAmount * WATER_FLOW_STRENGTH, 0.0, 1.0);
                float flowFoam = flowStreak * flowStrength * (1.0 - smoothstep(0.10, 0.48, shoreDistance));
                foam = max(foam, flowFoam * 0.45);
            }
        #endif
    } else {
        water_absortion = 0.0;
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

vec4 reflection_calc(vec3 fragpos, vec3 normal, vec3 reflected, inout float infinite, vec3 sky_reflect, float dither) {
    vec3 pos;
    #if SSR_TYPE == 0
        #if defined DISTANT_HORIZONS || defined VOXY
            pos = camera_to_screen(fragpos + reflected * 768.0);
        #else
            pos = camera_to_screen(fragpos + reflected * 76.0);
        #endif
        infinite = step(texture2D(depthtex1, clamp(pos.xy, vec2(0.0), vec2(1.0))).r, 0.9999);
    #else
        pos = fastRaymarch(reflected, fragpos, infinite, dither);
    #endif

    // Suaviza o infinite em vez de usar binário (0.0 ou 1.0)
    float border = clamp((1.0 - (max(0.0, abs(pos.y - 0.5)) * 1.5)) * 10.0, 0.0, 1.0);
    border = clamp(border - pow(pos.y, 20.0), 0.0, 1.0);

    pos.x = abs(pos.x);
    if (pos.x > 1.0) {
        pos.x = 1.0 - (pos.x - 1.0);
    }

    float skyTest = step(0.9999, texture2D(depthtex1, clamp(pos.xy, vec2(0.001), vec2(0.999))).r);
    skyTest = max(skyTest, step(0.5, infinite));
    
    // Mistura suave entre o reflexo da tela e o céu
    vec3 reflectColor = mix(texture2D(gaux1, pos.xy).rgb, sky_reflect, skyTest);
    
    // Retorna o infinite suavizado para o fresnel
    infinite = smoothstep(0.0, 1.0, skyTest);

    return vec4(reflectColor, border);
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
    vec4 reflection = vec4(0.0);
    float infinite = 1.0;

    #if REFLECTION == 1
        if (isEyeInWater == 0) {
            reflection = reflection_calc(fragpos, normal, reflected, infinite, sky_reflect, dither);
        }
    #endif

    reflection.rgb = mix(
        sky_reflect * visibleSky,
        reflection.rgb,
        reflection.a
    );

    #ifdef VANILLA_WATER
        fresnel *= 0.8;
    #endif

    // AQUI ESTÁ A MÁGICA: Suaviza o reflexo em vez de usar um hard step
    float final_fresnel = fresnel * REFLEX_INDEX;
    
    // Aumenta o fresnel suavemente quando bate no céu (em vez de forçar 0.75 de uma vez)
    final_fresnel = mix(final_fresnel, 0.75, infinite);
    
    // Garante que não fique abaixo de 0.75 se for céu
    final_fresnel = max(final_fresnel, 0.75 * infinite);

    #if SUN_REFLECTION == 1
        #ifndef NETHER
            #ifndef THE_END
                return mix(color, reflection.rgb, final_fresnel) +
                    vec3(sun_reflection(reflect(normalize(fragpos), normal))) * lightColor * infinite * visibleSky * float(isEyeInWater == 0);
            #else
                return mix(color, reflection.rgb, final_fresnel);
            #endif
        #else
            return mix(color, reflection.rgb, final_fresnel);
        #endif
    #else
        return mix(color, reflection.rgb, final_fresnel);
    #endif
}

vec4 cristal_reflection_calc(vec3 fragpos, vec3 normal, inout float infinite, float dither) {
    #if SSR_TYPE == 0
        #if defined DISTANT_HORIZONS || defined VOXY
            vec3 reflectedVector = reflect(normalize(fragpos), normal) * 768.0;
        #else
            vec3 reflectedVector = reflect(normalize(fragpos), normal) * 76.0;
        #endif
        vec3 pos = camera_to_screen(fragpos + reflectedVector);
    #else
        vec3 reflectedVector = reflect(normalize(fragpos), normal);
        vec3 pos = fastRaymarch(reflectedVector, fragpos, infinite, dither);

        if (pos.x > 99.0) {
            #if defined DISTANT_HORIZONS
                pos = camera_to_screen(fragpos + reflectedVector * 768.0);
            #else
                pos = camera_to_screen(fragpos + reflectedVector * 76.0);
            #endif
        }
    #endif

    float border_x = max(-fourthPow(abs(2.0 * pos.x - 1.0)) + 1.0, 0.0);
    float border_y = max(-fourthPow(abs(2.0 * pos.y - 1.0)) + 1.0, 0.0);
    float border = min(border_x, border_y);

    return vec4(texture2D(gaux1, pos.xy, 0.0).rgb, border);
}

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
    vec4 reflection = vec4(0.0);
    float infinite = 0.0;

    #if REFLECTION == 1
        reflection = cristal_reflection_calc(fragpos, normal, infinite, dither);
    #endif

    skyReflectionColor = mix(color.rgb, skyReflectionColor, visibleSky * visibleSky);

    reflection.rgb = mix(
        skyReflectionColor,
        reflection.rgb,
        reflection.a
    );

    color.rgb = mix(color.rgb, skyReflectionColor, fresnel);
    color.rgb = mix(color.rgb, reflection.rgb, fresnel);

    color.a = mix(color.a, 1.0, fresnel * .9);

    #if SUN_REFLECTION == 1
        #ifndef NETHER
        #ifndef THE_END
            return color + vec4(
                mix(
                    vec3(sun_reflection(reflect(normalize(fragpos), normal)) * lightColor * infinite * visibleSky),
                    vec3(0.0),
                    reflection.a
                ),
                0.0
            );
        #else
            return color;
        #endif
        #else
            return color;
        #endif
    #else
        return color;
    #endif
}
