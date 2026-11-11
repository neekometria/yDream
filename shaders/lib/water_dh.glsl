#ifndef gaux4
    #define gaux4 colortex7
#endif

// Parent DH water TU already declares gbufferProjection[Inverse], depthtex1,
// gaux1 (aliased to colortex4) and worldTime.
#if YDREAM_WATER_SSR_STEPS > 0
    #include "/lib/water_ssr.glsl"
#endif

#include "/lib/water_motion.glsl"
#include "/lib/water_compose.glsl"
#include "/lib/water_body.glsl"

#if AA_TYPE > 0 && MC_VERSION >= 11300
    uniform vec2 taaOffset;
#endif

#if SUN_REFLECTION == 1
    #if !defined NETHER && !defined THE_END
        float sun_reflection(vec3 fragpos) {
            vec3 astroLightPos = worldTime > 12900 ? moonPosition : sunPosition;
            float astroAlignment = clamp(dot(normalize(fragpos), normalize(astroLightPos)), 0.0, 1.0);
            
            // Mesma lobe limitada da água vanilla. Ruído temporal só criava
            // cintilação e não corrigia o aliasing especular.
            float core = pow(astroAlignment, 16.0);
            float body = pow(astroAlignment, 4.0);
            float glint = core * 0.035 + body * 0.012;
            return min(glint * SUN_GLINT_STRENGTH * (1.0 - rainStrength), 0.06);
        }
    #endif
#endif

vec3 normal_waves_dh(vec3 pos) {
    // Mesmo campo de ondas da água vanilla; sem fluxo detectado no LOD.
    return ydr_water_texture_normal(pos, vec2(1.0, 0.0), 0.0, visibleSky);
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
    // `texcoord` no DH é a UV do atlas/vertex-data, não a UV da tela (mesma
    // regra do water.glsl). Screen UV vem de gl_FragCoord.
    vec2 screenUV = gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY);
    float surfaceDepth = max(-fragpos.z, 0.05);
    float bedDepth = 1e8;
    #ifdef DISTANT_HORIZONS
        float dh = texture2D(dhDepthTex1, screenUV).r;
        if (dh < 0.999999) {
            bedDepth = 2.0 * dhNearPlane * dhFarPlane /
                (dhFarPlane + dhNearPlane - (2.0 * dh - 1.0) *
                (dhFarPlane - dhNearPlane));
        }
    #endif
    if (bedDepth >= 1e8) {
        float d = texture2D(depthtex1, screenUV).r;
        if (d < 0.999999) {
            bedDepth = gbufferProjection[3][2] /
                (gbufferProjection[2][2] + 2.0 * d - 1.0);
        }
    }
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
    if (destinationDepth >= 0.999999 || destinationDepth < baseDepth - 0.00005) {
        refractUV = screenUV;
    }
    vec3 bedColor = texture2D(gaux1, refractUV).rgb;
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