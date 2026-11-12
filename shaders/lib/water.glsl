#include "/lib/water_body.glsl"

// Parent water TU already declares gbufferProjection[Inverse], depthtex1,
// gaux1 and worldTime; repeating them here is a GLSL duplicate declaration.
#if YDREAM_WATER_SSR_STEPS > 0
    #include "/lib/water_ssr.glsl"
#endif

// Declarado ANTES dos includes: water_compose referencia o uniform dentro
// de funcao, e GLSL exige declaracao anterior ao uso em ordem de texto.
uniform mat4 gbufferModelViewInverse;

#include "/lib/water_motion.glsl"
#include "/lib/water_compose.glsl"
#if AA_TYPE > 0 && MC_VERSION >= 11300
    uniform vec2 taaOffset;
#endif

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
    // depthtex1 (apenas opacos): o leito é sempre geometria sólida. Amostrar
    // depthtex0 aqui pegava a própria água já desenhada no passe translúcido e
    // produzia padrões em blocos que se deslocavam com a câmera.
    float depthW = texture2D(depthtex1, uv - vec2(stepUV.x, 0.0)).r;
    float depthE = texture2D(depthtex1, uv + vec2(stepUV.x, 0.0)).r;
    float depthS = texture2D(depthtex1, uv - vec2(0.0, stepUV.y)).r;
    float depthN = texture2D(depthtex1, uv + vec2(0.0, stepUV.y)).r;
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
    float bedDepth = texture2D(depthtex1, uv).r;
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

            // A textura animada não faz anti-aliasing: ela só modula o brilho e
            // cria cintilação temporal. Use uma lobe mais larga e energia limitada.
            float core = pow(alignment, 16.0);
            float body = pow(alignment, 4.0);
            float glint = core * 0.035 + body * 0.012;

            #if YDREAM_GLITTER == 1
                vec2 glitterPos = worldposition.xz * 1.7 + vec2(frameTimeCounter * 0.11, frameTimeCounter * -0.07);
                vec2 noiseA = texture2D(noisetex, glitterPos * 0.21).rg;
                vec2 noiseB = texture2D(noisetex, glitterPos.yx * 0.33 - frameTimeCounter * 0.02).rg;
                float sparkle = smoothstep(0.62, 0.95, noiseA.r * noiseB.g * 1.9);
                glint *= 0.95 + sparkle * 0.10;
            #endif

            return min(glint * SUN_GLINT_STRENGTH * astroFade * (1.0 - rainStrength), 0.06);
        }
    #endif
#endif

vec3 normal_waves(vec3 pos, vec2 flowDirection, float flowAmount) {
    return ydr_water_texture_normal(pos, flowDirection, flowAmount, visibleSky);
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

vec3 water_specular_normal(vec3 normal) {
    vec3 macroNormal = normalize(waterNormal);
    vec3 normalDx = dFdx(normal);
    vec3 normalDy = dFdy(normal);
    float normalVariance = dot(normalDx, normalDx) + dot(normalDy, normalDy);
    float filterAmount = clamp(0.22 + normalVariance * 2.0, 0.22, 0.88);
    return normalize(mix(normal, macroNormal, filterAmount));
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
    // ATENÇÃO: no gbuffers, `texcoord` é a UV do atlas do bloco, NÃO a UV da
    // tela. Todo sample de depth/scene aqui tem que vir de gl_FragCoord; usar
    // texcoord fazia cada bloco de água ler uma posição de tela fixa
    // pseudoaleatória (a do tile no atlas) — xadrez por bloco e validação de
    // refração no lugar errado.
    vec2 screenUV = gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY);
    float surfaceDepth = max(-fragpos.z, 0.05);
    float bedDepth = 1e8;
    float d = texture2D(depthtex1, screenUV).r;
    if (d < 0.999999) {
        bedDepth = gbufferProjection[3][2] /
            (gbufferProjection[2][2] + 2.0 * d - 1.0);
    }
    #ifdef DISTANT_HORIZONS
        float dh = texture2D(dhDepthTex1, screenUV).r;
        if (dh < 0.999999) {
            float dhDepth = 2.0 * dhNearPlane * dhFarPlane /
                (dhFarPlane + dhNearPlane - (2.0 * dh - 1.0) *
                (dhFarPlane - dhNearPlane));
            bedDepth = min(bedDepth, dhDepth);
        }
    #endif
    float thickness = (bedDepth < 1e8)
        ? clamp(bedDepth - surfaceDepth, 0.0, 24.0) : 8.0;

    vec2 offset = vec2(0.0);
    #if REFRACTION == 1
        float refractAmount = 0.012 * (WATER_REFRACTION_STRENGTH * 0.01) *
            clamp(thickness * 0.12, 0.0, 1.0);
        offset = normal.xy * refractAmount;
    #endif
    vec2 refractUV = clamp(screenUV + offset, vec2(pixelSizeX, pixelSizeY),
        vec2(1.0) - vec2(pixelSizeX, pixelSizeY));
    float destinationDepth = texture2D(depthtex1, refractUV).r;
    float baseDepth = texture2D(depthtex1, screenUV).r;
    // Refraction may only sample opaque geometry behind the water. If the
    // displaced UV crosses an edge or lands on sky/nearer geometry, use the
    // undisplaced opaque sample instead of importing unrelated scene pixels.
    if (destinationDepth >= 0.999999 || destinationDepth < baseDepth - 0.00005) {
        refractUV = screenUV;
    }
    vec3 bedColor = texture2D(gaux1, refractUV).rgb;
    // Nevoa fisica sobre o fundo visto atraves da agua (inclui o LOD do DH).
    bedColor = ydr_bed_underwater_fog(bedColor, surfaceDepth, refractUV,
        destinationDepth, visibleSky, lightColor);
    vec3 result = ydr_water_compose(fragpos, normal, color, sky_reflect, bedColor,
        thickness, fresnel, visibleSky, lightColor);

    if (isEyeInWater == 0) {
        #if SUN_REFLECTION == 1 && !defined NETHER && !defined THE_END
            result += vec3(sun_reflection(reflect(normalize(fragpos), normal))) *
                lightColor * visibleSky * (1.0 - rainStrength) * 0.35;
        #endif
    }

    return result;
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