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

#endif
