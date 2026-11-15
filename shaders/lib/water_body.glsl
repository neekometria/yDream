// ============================================================================
// Water body/surface transmission helpers built on the unified medium model.
// Includes depth-buffer sampling helpers and bed-fog composition.
// Requires in TU (as applicable): gbufferProjection, cameraPosition,
// depth/dh depth samplers and planes when used, and underwaterFogColor().
// ============================================================================
#ifndef YDREAM_WATER_BODY_INCLUDED
#define YDREAM_WATER_BODY_INCLUDED

#include "/lib/water_color.glsl"
#include "/lib/water_medium.glsl"

// --- Depth buffer conversions ---------------------------------------------

// Convert a non-linear depth buffer sample to linear view distance using the
// standard gbuffer projection. Caller must ensure depth is not sky.
float ydr_water_linear_depth_standard(float depthSample) {
    return gbufferProjection[3][2] /
        (gbufferProjection[2][2] + 2.0 * depthSample - 1.0);
}

#ifdef DISTANT_HORIZONS
// Convert a DH depth sample to linear view distance.
float ydr_water_linear_depth_dh(float depthSample) {
    return 2.0 * dhNearPlane * dhFarPlane /
        (dhFarPlane + dhNearPlane - (2.0 * depthSample - 1.0) *
        (dhFarPlane - dhNearPlane));
}
#endif

// --- Surface body (above-water view through surface) -----------------------

vec3 water_body(vec3 surfaceColor, vec3 refractedColor, float waterThickness) {
    float thickness = max(waterThickness, 0.0);

    vec3 transmit = ydr_water_body_transmittance(thickness);

    vec3 shallowScatter = mix(WATER_COLOR, surfaceColor * vec3(0.88, 1.18, 1.06), 0.45);
    float depthMix = clamp((1.0 - exp(-thickness * 0.45)) *
        clamp(YDREAM_WATER_DEPTH_TINT, 0.0, 1.5), 0.0, 1.0);
    vec3 scatter = mix(shallowScatter, WATER_COLOR * 0.68, depthMix);

    return refractedColor * transmit + scatter * (1.0 - transmit) * 1.15;
}

// --- Bed fog (camera above water, looking down through column) ------------

// Fog do meio aquático aplicada ao conteúdo refratado visto de cima. Mede o
// caminho dentro da água até o fundo no UV refratado e aplica a névoa da
// coluna d'água (modelo unificado). A absorção seletiva de corpo fica a cargo
// de water_body() para evitar dupla atenuação.
vec3 ydr_bed_underwater_fog(vec3 bedColor, float surfaceDepth, vec2 refractUV,
    float destinationDepth, float visibleSky, vec3 lightColor) {
    float bedDist = 1e8;
    #ifdef DISTANT_HORIZONS
        float dhd = texture2D(dhDepthTex0, refractUV).r;
        if (dhd > 0.000001 && dhd < 0.999999) {
            bedDist = ydr_water_linear_depth_dh(dhd);
        }
    #endif
    if (destinationDepth < 0.999999) {
        float viewDepth = ydr_water_linear_depth_standard(destinationDepth);
        bedDist = min(bedDist, viewDepth);
    }

    // Sem leito no buffer (chunk/LOD do DH ausente no UV refratado) o sample
    // seria o ceu/névoa CRUA, e isso aparecia como "buracos" claros no meio da
    // agua — visivel só com render distance maior, porque é onde o LOD tem
    // lacunas. Sem leito = profundidade infinita: devolve a cor da coluna.
    // Mesma coisa se o "leito" medido está na frente da superficie (depth
    // velho do passe DH): caminho zero mostraria o sample cru.
    if (bedDist >= 1e8 || bedDist <= surfaceDepth) {
        return ydr_water_column_fog_radiance(lightColor, visibleSky, cameraPosition.y);
    }

    vec2 ndc = refractUV * 2.0 - 1.0;
    vec3 viewRay = normalize((gbufferProjectionInverse * vec4(ndc, 1.0, 1.0)).xyz);
    float bedRayDistance = ydr_water_view_to_ray_distance(bedDist, viewRay);
    float surfaceRayDistance = ydr_water_view_to_ray_distance(surfaceDepth, viewRay);
    float waterPath = max(bedRayDistance - surfaceRayDistance, 0.0);

    vec3 waterPathFog = ydr_water_apply_column_fog(
        bedColor, lightColor, visibleSky, cameraPosition.y, waterPath
    );
    // Olhando de FORA para dentro a coluna tem que virar parede depois de ~5
    // blocos abaixo da superficie; antes o leito/LOD continuava legivel porque
    // a extincao de fundo (Beer-Lambert) e fraca nessa distancia. Nao afeta a
    // vista de dentro d'agua: ali o bedColor e descartado pelo ramo submerso
    // de ydr_water_compose.
    return mix(
        waterPathFog,
        ydr_water_column_fog_radiance(lightColor, visibleSky, cameraPosition.y),
        smoothstep(YDR_WATER_SURFACE_HIDE_DEPTH - 2.0,
            YDR_WATER_SURFACE_HIDE_DEPTH, waterPath)
    );
}

#endif
