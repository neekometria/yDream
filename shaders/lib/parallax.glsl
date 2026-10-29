vec2 pomWrap(vec2 uv, vec2 mid, vec2 halfSize) {
    vec2 safeHalf = max(halfSize, vec2(0.00001));
    vec2 local = (uv - mid) / safeHalf;
    local -= 2.0 * floor((local + 1.0) * 0.5);
    local = clamp(local, vec2(-0.995), vec2(0.995));
    return mid + local * safeHalf;
}

float pomDepthAt(vec2 uv, vec2 mid, vec2 halfSize) {
    return 1.0 - texture2DLod(normals, pomWrap(uv, mid, halfSize), 0.0).a;
}

vec2 pomOffset(vec2 baseUV, vec2 texMid, vec2 texHalf, vec3 tangent, vec3 bitangent, vec3 normal, vec3 viewPosVec, float fade) {
    vec4 probe = texture2DLod(normals, baseUV, 0.0);

    if (fade <= 0.01 || probe.b + probe.a < 0.004) {
        return baseUV;
    }

    vec3 viewDirVS = normalize(-viewPosVec);
    vec3 viewDirTS = vec3(
        dot(viewDirVS, tangent),
        dot(viewDirVS, bitangent),
        dot(viewDirVS, normal)
    );

    float safeZ = max(viewDirTS.z, 0.15);
    float numLayers = max(floor(mix(float(POM_STEPS) * 0.5, float(POM_STEPS), fade)), 4.0);
    float layerDepth = 1.0 / numLayers;
    vec2 deltaUV = (viewDirTS.xy * (POM_DEPTH * 2.5 * fade) * (texHalf * 2.0)) / (safeZ * numLayers);

    vec2 currentUV = baseUV;
    float currentLayerDepth = 0.0;
    float currentDepth = pomDepthAt(currentUV, texMid, texHalf);

    for (int i = 0; i < POM_STEPS; i++) {
        if (float(i) >= numLayers || currentLayerDepth >= currentDepth) {
            break;
        }

        currentUV -= deltaUV;
        currentLayerDepth += layerDepth;
        currentDepth = pomDepthAt(currentUV, texMid, texHalf);
    }

    if (currentLayerDepth < currentDepth) {
        return pomWrap(currentUV, texMid, texHalf);
    }

    vec2 aboveUV = currentUV + deltaUV;
    vec2 belowUV = currentUV;
    float aboveLayer = currentLayerDepth - layerDepth;
    float belowLayer = currentLayerDepth;

    for (int k = 0; k < 4; k++) {
        vec2 midUV = (aboveUV + belowUV) * 0.5;
        float midLayer = (aboveLayer + belowLayer) * 0.5;

        if (pomDepthAt(midUV, texMid, texHalf) > midLayer) {
            aboveUV = midUV;
            aboveLayer = midLayer;
        } else {
            belowUV = midUV;
            belowLayer = midLayer;
        }
    }

    return pomWrap(belowUV, texMid, texHalf);
}
