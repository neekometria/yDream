// ============================================================================
// Cor do corpo da água: absorção por canal, espalhamento e transmissão do fundo.
// Compartilhado por Vanilla e DH, aplicado inline no próprio passe da água.
//
// Earth look: vermelho é absorvido primeiro, então água rasa fica esverdeada e
// a profunda caminha para o WATER_COLOR do preset. O slider WATER_ABSORPTION
// escala a densidade; a cor do preset controla o espalhamento profundo.
//
// Calibração: os coeficientes precisam vender a superfície olhando de cima
// (fresnel ~0 nessa direção, então o corpo é a única coisa que “desenha” a
// água rasa). Coeficientes fracos deixavam o leito visível quase direto — a
// água parecia inexistente, principalmente com WATER_REFLECTIONS=0.
// ============================================================================
#ifndef YDREAM_WATER_BODY_INCLUDED
#define YDREAM_WATER_BODY_INCLUDED

vec3 ydr_water_absorption() {
    // Coeficientes por canal (1/bloco): R some rápido, G/B permanecem.
    // Escala por WATER_ABSORPTION (slider).
    return vec3(4.20, 1.10, 0.80) * max(WATER_ABSORPTION, 0.001);
}

vec3 water_body(vec3 surfaceColor, vec3 refractedColor, float waterThickness) {
    float thickness = max(waterThickness, 0.0);

    // Transmitância de Beer-Lambert por canal.
    vec3 transmit = exp(-ydr_water_absorption() * thickness);

    // Espalhamento: raso mistura a luz da superfície, fundo usa o preset com
    // um escurecimento fixo — água profunda não pode ficar tão clara quanto o
    // preset puro, senão parece névoa sobre o leito em vez de volume.
    vec3 shallowScatter = mix(WATER_COLOR, surfaceColor * vec3(0.88, 1.18, 1.06), 0.55);
    // O slider WATER_DEPTH_TINT controla quão rápido o corpo chega à cor do
    // preset; sem isso água de 2–3 blocos continuava praticamente invisível.
    float depthMix = clamp((1.0 - exp(-thickness * 0.30)) *
        clamp(YDREAM_WATER_DEPTH_TINT, 0.0, 1.5), 0.0, 1.0);
    vec3 scatter = mix(shallowScatter, WATER_COLOR * 0.72, depthMix);

    // Fundo atenuado + luz espalhada no volume.
    return refractedColor * transmit + scatter * (1.0 - transmit);
}

// Fog subaquatica fisica (Beer-Lambert) aplicada ao CONTEUDO REFRATADO.
// O composite foga olhando "de dentro", usando a distancia ate a SUPERFICIE;
// olhando de fora para dentro, a superficie esta perto e a fog dava 0,
// deixando o fundo (inclusive o LOD do DH) cru. Aqui medimos o comprimento
// do caminho dentro da agua ate o fundo no UV refratado e aplicamos a mesma
// extincao usada pelo composite, para os dois lados baterem.
// Requer do TU chamador: depthtex1, dhDepthTex0 + dhNearPlane/dhFarPlane
// (com DISTANT_HORIZONS), gbufferProjection, cameraPosition, visibleSky e
// lightColor.
vec3 ydr_bed_underwater_fog(vec3 bedColor, float surfaceDepth, vec2 refractUV,
    float destinationDepth, float visibleSky, vec3 lightColor) {
    float bedDist = 1e9;
    #ifdef DISTANT_HORIZONS
        float dhd = texture2D(dhDepthTex0, refractUV).r;
        if (dhd < 0.999999) {
            bedDist = 2.0 * dhNearPlane * dhFarPlane /
                (dhFarPlane + dhNearPlane - (2.0 * dhd - 1.0) *
                (dhFarPlane - dhNearPlane));
        }
    #endif
    if (destinationDepth < 0.999999) {
        float viewDepth = gbufferProjection[3][2] /
            (gbufferProjection[2][2] + 2.0 * destinationDepth - 1.0);
        bedDist = min(bedDist, viewDepth);
    }

    if (bedDist >= 1e9) return bedColor;

    float waterPath = max(bedDist - surfaceDepth, 0.0);
    float uwExtinction = (0.035 + 0.014 * UNDERWATER_FOG_DENSITY) * max(UNDERWATER_DARKNESS, 0.5);
    float uwFogAmount = 1.0 - exp(-waterPath * uwExtinction);
    float uwDepthDark = exp(-max(62.0 - cameraPosition.y, 0.0) * 0.05 * UNDERWATER_DARKNESS);
    vec3 uwFogColor = underwaterFogColor(lightColor, visibleSky) * uwDepthDark;
    return mix(bedColor, uwFogColor, uwFogAmount);
}

#endif
