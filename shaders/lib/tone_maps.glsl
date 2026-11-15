vec3 ydreamSigmoid(vec3 color) {
    color = 1.4 * color;
    color = color / pow(pow(color, vec3(2.5)) + 1.0, vec3(0.4));

    return pow(color, vec3(1.15));
}

vec3 kneeTone(vec3 color, float knee) {
    float peak = max(max(color.r, color.g), color.b);

    if (peak <= knee) {
        return color;
    }

    float over = (peak - knee) / (1.0 - knee);
    float mapped = knee + (1.0 - knee) * (1.0 - exp(-over));
    // Mantém o matiz: todos os canais saem pelo mesmo fator. Antes havia um
    // "whiten" que misturava até 55% com cinza neutro acima de pico 1.2; era
    // isso que lavava a luz colorida e as entidades iluminadas em branco.
    return color * (mapped / peak);
}

vec3 naturalTone(vec3 color) {
    color = kneeTone(color, 0.66);
    vec3 curve = color * color * (3.0 - 2.0 * color);
    color = mix(color, curve, 0.10);
    float toneLuma = dot(color, vec3(0.2126, 0.7152, 0.0722));

    return max(mix(vec3(toneLuma), color, 1.08), vec3(0.0));
}

vec3 filmicTone(vec3 color) {
    color = kneeTone(color, 0.70);
    vec3 curve = color * color * (3.0 - 2.0 * color);
    color = mix(color, curve, 0.42);
    color = color * 0.985 + 0.010;
    float toeLuma = dot(color, vec3(0.2126, 0.7152, 0.0722));

    return mix(vec3(toeLuma), color, 1.05);
}

vec3 custom_sigmoid(vec3 color) {
    #if YDREAM_TONEMAP == 1
        return ydreamSigmoid(color);
    #elif YDREAM_TONEMAP == 2
        return naturalTone(color);
    #else
        return filmicTone(color);
    #endif
}
