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
            float cosIncident = clamp(abs(dot(normalize(normal), normalize(-fragpos))), 0.0, 1.0);
            float sinTransmitted = sqrt(max(0.0, 1.0 - cosIncident * cosIncident)) / 1.333;
            float cosTransmitted = sqrt(max(0.0, 1.0 - sinTransmitted * sinTransmitted));
            float windowMask = smoothstep(0.02, 0.16, cosTransmitted);

            vec2 screenUV = gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY);
            vec2 windowUV = clamp(screenUV + normal.xy * 0.0028,
                vec2(pixelSizeX, pixelSizeY), vec2(1.0) - vec2(pixelSizeX, pixelSizeY));
            vec3 transmittedSky = texture2D(gaux4, windowUV).rgb * vec3(0.62, 0.83, 1.0);
            vec3 tirRadiance = underwaterFogColor(lightColor, visibleSky) * 0.42 + WATER_COLOR * 0.18;

            result = mix(tirRadiance, transmittedSky, windowMask);
            return result;
        }
    #endif

    // A SUPERFÍCIE (brilho de Fresnel com o céu) existe em TODOS os modos,
    // inclusive 0 — antes ela estava dentro do bloco de reflexo e no modo 0 a
    // água não tinha “tampa”. O SSR só entra nos modos com passos.
    if (isEyeInWater == 0) {
        vec3 reflectColor = skyReflect;

        #if YDREAM_WATER_SSR_STEPS > 0
            vec2 screenUV = gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY);
            vec4 ssr = ydr_water_ssr(screenUV, fragpos, normal, skyReflect);
            reflectColor = mix(skyReflect, ssr.rgb, ssr.a);
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
