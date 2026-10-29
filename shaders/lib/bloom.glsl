float bloomInside(vec2 uv) {
    vec2 edge = min(uv, 1.0 - uv);

    return smoothstep(0.0, 0.02, min(edge.x, edge.y));
}

vec3 mipmap_bloom(sampler2D image, vec2 coords, float dither) {
    vec3 haloSample = vec3(0.0);
    float haloWeight = 0.0;

    vec2 blurRadiusVec = vec2(BLOOM_RADIUS * aspectRatioInverse, BLOOM_RADIUS);

    int samplesQuantity = max(int(BLOOM_SAMPLES), 1);
    float invCount = 1.0 / float(samplesQuantity);

    for(int i = 0; i < samplesQuantity; i++) {
        float t = (float(i) + dither) * invCount;
        float angle = (float(i) + dither) * 2.399963229728653;
        float radius = mix(0.12, 1.0, t * t);
        vec2 offset = vec2(cos(angle), sin(angle)) * radius * blurRadiusVec;
        vec2 offset2 = vec2(-offset.y * 1.25, offset.x * 1.25);

        float lod = softLod + 1.3 + t * 2.4;
        float weight = exp(-t * t * 2.4) + 0.12;

        vec2 uvA = coords + offset;
        vec2 uvB = coords - offset;
        vec2 uvC = coords + offset2;
        vec2 uvD = coords - offset2;

        float wA = bloomInside(uvA);
        float wB = bloomInside(uvB);
        float wC = bloomInside(uvC);
        float wD = bloomInside(uvD);

        vec3 pair = texture2DLod(image, uvA, lod).rgb * wA;
        pair += texture2DLod(image, uvB, lod).rgb * wB;
        pair += texture2DLod(image, uvC, lod).rgb * wC;
        pair += texture2DLod(image, uvD, lod).rgb * wD;

        haloSample += pair * weight;
        haloWeight += weight * (wA + wB + wC + wD);
    }

    haloSample /= max(haloWeight, 0.0001);

    float veilAngle = dither * 6.283185307179586;
    vec2 veilOffset = vec2(cos(veilAngle), sin(veilAngle)) * blurRadiusVec * 2.4;
    vec2 veilOffset2 = vec2(-veilOffset.y, veilOffset.x);
    float veilLod = softLod + 4.0;

    float vA = bloomInside(coords + veilOffset);
    float vB = bloomInside(coords - veilOffset);
    float vC = bloomInside(coords + veilOffset2);
    float vD = bloomInside(coords - veilOffset2);

    vec3 veil = texture2DLod(image, coords + veilOffset, veilLod).rgb * vA;
    veil += texture2DLod(image, coords - veilOffset, veilLod).rgb * vB;
    veil += texture2DLod(image, coords + veilOffset2, veilLod).rgb * vC;
    veil += texture2DLod(image, coords - veilOffset2, veilLod).rgb * vD;
    veil /= max(vA + vB + vC + vD, 0.0001);

    #if PERFORMANCE_MODE != 3
        float auraAngle = dither * 6.283185307179586 + 1.5707963267948966;
        vec2 auraOffset = vec2(cos(auraAngle), sin(auraAngle)) * blurRadiusVec * 4.6;
        vec2 auraOffset2 = vec2(-auraOffset.y, auraOffset.x);
        float auraLod = softLod + 5.4;

        float aA = bloomInside(coords + auraOffset);
        float aB = bloomInside(coords - auraOffset);
        float aC = bloomInside(coords + auraOffset2);
        float aD = bloomInside(coords - auraOffset2);

        vec3 aura = texture2DLod(image, coords + auraOffset, auraLod).rgb * aA;
        aura += texture2DLod(image, coords - auraOffset, auraLod).rgb * aB;
        aura += texture2DLod(image, coords + auraOffset2, auraLod).rgb * aC;
        aura += texture2DLod(image, coords - auraOffset2, auraLod).rgb * aD;
        aura /= max(aA + aB + aC + aD, 0.0001);

        return haloSample * 0.95 + veil * 0.72 + aura * (0.34 * BLOOM_WIDE);
    #else
        return haloSample * 0.95 + veil * 0.72;
    #endif
}
