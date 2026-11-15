// Shared water composition for every backend that renders a water surface.
// Callers supply thickness/bed colour from their own depth source, then this
// file applies the same volume, refraction validation, above-water reflection
// and underwater surface model. Requires the caller TU to declare:
// gbufferProjection, gbufferProjectionInverse (SSR only), gaux1, depthtex1,
// gaux4, texcoord, pixelSizeX/Y, isEyeInWater and the config macros.
#ifndef YDREAM_WATER_COMPOSE_INCLUDED
#define YDREAM_WATER_COMPOSE_INCLUDED

#include "/lib/water_body.glsl"

vec3 ydr_water_compose(
    vec3 fragpos,
    vec3 normal,
    vec3 surfaceColor,
    vec3 skyReflect,
    vec3 bedColor,
    float thickness,
    float fresnel,
    float visibleSky,
    vec3 lightColor
) {
    vec3 result = water_body(surfaceColor, bedColor, thickness);

    #if defined UNDERWATER_FX && !defined NETHER && !defined THE_END
        if (isEyeInWater == 1) {
            // Snell window from below: transmission inside the cone, TIR outside.
            // A mascara usa a normal GEOMETRICA (sem ondas): com a normal
            // ondulada o limite da janela oscila pixel a pixel e a linha da
            // agua vira uma moldura de "cortinas pingando".
            // Linha 1 da matriz inversa = eixo Y do mundo em espaco de visao.
            vec3 geometricUp = normalize(vec3(gbufferModelViewInverse[0].y,
                gbufferModelViewInverse[1].y, gbufferModelViewInverse[2].y));
            float cosIncident = clamp(abs(dot(geometricUp, normalize(-fragpos))), 0.0, 1.0);
            float sinTransmitted = sqrt(max(0.0, 1.0 - cosIncident * cosIncident)) / 1.333;
            float cosTransmitted = sqrt(max(0.0, 1.0 - sinTransmitted * sinTransmitted));
            // Transicao larga: reflexao interna total em agua ondulada nao
            // e uma fronteira nitida por pixel.
            float windowMask = smoothstep(0.06, 0.28, cosTransmitted);

            // Profundidade vertical aproximada da camera abaixo da superficie:
            // este fragmento E a superficie acima de nos; distancia ao longo do
            // raio x cos do angulo com a vertical da a profundidade.
            float camDepth = length(fragpos) * cosIncident;
            // Alem do limiar (UNDERWATER_DEEP_THRESHOLD) a janela comeca a
            // fechar: olhar para cima no fundo do oceano nao mostra mais o
            // ceu — so o veu escuro do abismo. Antes do limiar, decay lento.
            float windowDepth = exp(-max(camDepth - UNDERWATER_DEEP_THRESHOLD, 0.0) *
                0.05 * UNDERWATER_DARKNESS);
            float skyDepthDark = exp(-camDepth * 0.015 * UNDERWATER_DARKNESS);
            windowMask *= windowDepth;

            vec2 screenUV = gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY);
            // Ondas: a normal sozinha da um deslocamento suave. Duas escalas de
            // ruido animado somam a "lente" que deforma tudo (ceu, nuvem, sol,
            // terreno), que e o que se ve olhando para cima dentro d'agua.
            float wobbleT = frameTimeCounter * 0.35;
            vec2 hazeA = texture2D(noisetex, screenUV * vec2(6.0, 8.0) + vec2(wobbleT, -wobbleT)).rg - 0.5;
            vec2 hazeB = texture2D(noisetex, screenUV * vec2(3.0, 4.0) - vec2(wobbleT * 0.7, wobbleT * 0.4)).gb - 0.5;
            vec2 windowUV = clamp(screenUV + normal.xy * 0.03 + (hazeA + hazeB * 1.4) * 0.018,
                vec2(pixelSizeX, pixelSizeY), vec2(1.0) - vec2(pixelSizeX, pixelSizeY));
            // Direcao do raio do pixel ja ondulado. Ceu, nuvem, sol e terreno da
            // janela usam TODOS esta direcao: refazer a refracao de Snell para
            // um deles punha cada elemento num angulo diferente.
            vec3 windowWorldDir = normalize(mat3(gbufferModelViewInverse) *
                normalize((gbufferProjectionInverse * vec4(windowUV * 2.0 - 1.0, 1.0, 1.0)).xyz));
            vec3 transmittedSky = texture2D(gaux4, windowUV).rgb * vec3(0.62, 0.83, 1.0);

            // Cintilancia de superficie: bandas de brilho correndo pela janela,
            // como luz quebrando em ondas (o sol visto de baixo "fervilha").
            float shimmerPos = frameTimeCounter * 0.45;
            float shimmerA = texture2D(noisetex, windowUV * vec2(14.0, 20.0) + vec2(shimmerPos, -shimmerPos)).g;
            float shimmerB = texture2D(noisetex, windowUV * vec2(9.0, 13.0) - vec2(shimmerPos * 0.7, shimmerPos * 0.5)).g;
            transmittedSky *= 1.0 + (shimmerA * shimmerB - 0.42) * 0.55;

            // Sol/lua visto de baixo atraves da janela: mesma direcao do ceu
            // acima, entao o brilho cai onde cai o sol na superficie, ondula com
            // as ondas e some com a profundidade (skyDepthDark).
            vec3 astroWorld = normalize(mat3(gbufferModelViewInverse) *
                mix(moonPosition, sunPosition, step(0.5, dayNightMix)));
            float astroVisible = smoothstep(-0.05, 0.12, dot(astroWorld, geometricUp)) * (1.0 - rainStrength);
            float sunAlign = max(dot(windowWorldDir, astroWorld), 0.0);
            float sunGlow = pow(sunAlign, 40.0) * 0.15 + pow(sunAlign, 400.0) * 0.85;
            transmittedSky += lightColor * (sunGlow * astroVisible * skyDepthDark);

            // colortex7 (prepare) nao carrega nuvens: sem isso a janela mostrava
            // so o gradiente. Mesmo get_cloud do reflexo, para a nuvem da janela
            // ser a mesma do ceu de cima.
            #ifdef YDR_WATER_WINDOW_CLOUDS
                float windowCloudCoverage;
                transmittedSky = max(get_cloud(windowWorldDir,
                    transmittedSky, 0.0, rDither(gl_FragCoord.xy), cameraPosition,
                    int(CLOUD_STEPS_AVG * 0.5), umbral, cloudColor, darkCloudColor,
                    normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz) *
                        mix(-1.0, 1.0, step(0.5, dayNightMix)), 1e9, 1.0,
                    windowCloudCoverage), vec3(0.0));
            #endif

            // gaux4 so carrega ceu: sem isto a janela escondia o terreno acima
            // da linha d'agua (ilha, arvores). O copy opaco do mesmo pixel tem
            // a cena; a profundidade diz se ali existe geometria. A profundidade
            // do DH tambem conta: o LOD distante nao esta em depthtex1.
            bool windowHasTerrain = texture2D(depthtex1, windowUV).r < 0.9999;
            #ifdef DISTANT_HORIZONS
                float windowDHDepth = texture2D(dhDepthTex0, windowUV).r;
                windowHasTerrain = windowHasTerrain ||
                    (windowDHDepth > 0.000001 && windowDHDepth < 0.999999);
            #endif
            if (windowHasTerrain) {
                transmittedSky = texture2D(gaux1, windowUV).rgb * vec3(0.62, 0.83, 1.0);
            }

            transmittedSky *= skyDepthDark;

            vec3 tirRadiance = underwaterFogColor(lightColor, visibleSky) * 0.42 + WATER_COLOR * 0.18;
            // Regiao de reflexao interna total tambem escurece com profundidade.
            tirRadiance *= ydr_water_depth_darkening(camDepth);

            result = mix(tirRadiance, transmittedSky, clamp(windowMask, 0.0, 1.0));
            return result;
        }
    #endif

    // A SUPERFÍCIE (brilho de Fresnel com o céu) existe em TODOS os modos,
    // inclusive 0 — antes ela estava dentro do bloco de reflexo e no modo 0 a
    // água não tinha “tampa”. O SSR só entra nos modos com passos.
    if (isEyeInWater == 0) {
        // Agua em caverna/estrutura fechada nao tem ceu para refletir: o SSR
        // continua (reflete a propria parede), so o fallback do ceu escurece.
        vec3 reflectColor = skyReflect * visibleSky;

        #if YDREAM_WATER_SSR_STEPS > 0
            vec2 screenUV = gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY);
            vec4 ssr = ydr_water_ssr(screenUV, fragpos, normal, reflectColor);
            reflectColor = mix(reflectColor, ssr.rgb, ssr.a);
        #endif

        #if WATER_REFLECTIONS == 0
            // Sem SSR: só o sheen de Fresnel, energia menor que os modos com
            // reflexo, para a superfície existir sem inventar um espelho.
            const float surfaceStrength = 0.35;
        #else
            const float surfaceStrength = WATER_REFLECT_STRENGTH;
        #endif

        result = mix(result, reflectColor, clamp(fresnel * surfaceStrength, 0.0, 1.0));
        return result;
    }

    return result;
}

#endif
