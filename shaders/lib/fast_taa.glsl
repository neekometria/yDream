vec3 taaToneIn(vec3 c) {
    return c / (1.0 + luma(c));
}

vec3 taaToneOut(vec3 c) {
    return c / max(1.0 - min(luma(c), 0.995), 0.005);
}

vec3 taaClipToBox(vec3 history, vec3 boxMin, vec3 boxMax) {
    vec3 boxCenter = 0.5 * (boxMax + boxMin);
    vec3 boxExtent = 0.5 * (boxMax - boxMin) + 0.00005;
    vec3 offset = history - boxCenter;
    vec3 scaled = abs(offset / boxExtent);
    float maxScaled = max(scaled.x, max(scaled.y, scaled.z));
    return maxScaled > 1.0 ? boxCenter + offset / maxScaled : history;
}

vec3 taaResolve(
    vec3 currentColor, vec3 previousColor, vec2 texcoordPast, float depthValue,
    vec3 up, vec3 down, vec3 left, vec3 right,
    vec3 ul, vec3 ur, vec3 dl, vec3 dr) {

    vec3 c = taaToneIn(currentColor);
    vec3 h = taaToneIn(previousColor);
    vec3 nUp = taaToneIn(up);
    vec3 nDown = taaToneIn(down);
    vec3 nLeft = taaToneIn(left);
    vec3 nRight = taaToneIn(right);
    vec3 nUl = taaToneIn(ul);
    vec3 nUr = taaToneIn(ur);
    vec3 nDl = taaToneIn(dl);
    vec3 nDr = taaToneIn(dr);

    vec3 sum = c + nUp + nDown + nLeft + nRight + nUl + nUr + nDl + nDr;
    vec3 sumSq = c * c + nUp * nUp + nDown * nDown + nLeft * nLeft + nRight * nRight +
        nUl * nUl + nUr * nUr + nDl * nDl + nDr * nDr;

    vec3 mean = sum * 0.1111111111;
    vec3 stdDev = sqrt(max(sumSq * 0.1111111111 - mean * mean, vec3(0.0)));

    vec3 colorMax = max(max(max(nLeft, nRight), max(nDown, nUp)), max(max(nUl, nUr), max(max(nDl, nDr), c)));
    vec3 colorMin = min(min(min(nLeft, nRight), min(nDown, nUp)), min(min(nUl, nUr), min(min(nDl, nDr), c)));

    float farFactor = smoothstep(0.9975, 0.9997, depthValue);
    float gamma = mix(1.45, 2.2, farFactor);

    vec3 boxMin = max(colorMin, mean - stdDev * gamma);
    vec3 boxMax = min(colorMax, mean + stdDev * gamma);
    boxMin = min(boxMin, boxMax - 0.0001);

    vec3 clipped = taaClipToBox(h, boxMin, boxMax);

    float clipAmount = clamp(distance(h, clipped) / (distance(boxMin, boxMax) + 0.03), 0.0, 1.0);
    float velocityPixels = length((texcoord - texcoordPast) / vec2(pixelSizeX, pixelSizeY));

    float historyWeight = mix(0.93, 0.62, clipAmount);
    historyWeight = mix(historyWeight, max(historyWeight, 0.955), farFactor);
    historyWeight *= 1.0 - clamp(velocityPixels * 0.025, 0.0, 0.45);

    #ifdef MOTION_BLUR
        historyWeight *= 1.0 - clamp(velocityPixels * 0.01, 0.0, 0.25);
    #endif

    return taaToneOut(mix(c, clipped, historyWeight));
}

vec3 fastTaa(vec3 currentColor, vec2 texcoordPast, float depthValue) {

    if (clamp(texcoordPast, 0.0, 1.0) != texcoordPast) {
        return currentColor;
    } else {

        vec3 previous = texture2DLod(colortex3, texcoordPast, 0.0).rgb;

        vec3 left = texture2DLod(colortex1, texcoord + vec2(-pixelSizeX, 0.0), 0.0).rgb;
        vec3 right = texture2DLod(colortex1, texcoord + vec2(pixelSizeX, 0.0), 0.0).rgb;
        vec3 down = texture2DLod(colortex1, texcoord + vec2(0.0, -pixelSizeY), 0.0).rgb;
        vec3 up = texture2DLod(colortex1, texcoord + vec2(0.0, pixelSizeY), 0.0).rgb;
        vec3 ul = texture2DLod(colortex1, texcoord + vec2(-pixelSizeX, pixelSizeY), 0.0).rgb;
        vec3 ur = texture2DLod(colortex1, texcoord + vec2(pixelSizeX, pixelSizeY), 0.0).rgb;
        vec3 dl = texture2DLod(colortex1, texcoord + vec2(-pixelSizeX, -pixelSizeY), 0.0).rgb;
        vec3 dr = texture2DLod(colortex1, texcoord + vec2(pixelSizeX, -pixelSizeY), 0.0).rgb;

        return taaResolve(currentColor, previous, texcoordPast, depthValue, up, down, left, right, ul, ur, dl, dr);
    }
}

vec4 fastTaaDepth(vec4 currentColor, vec2 texcoordPast, float depthValue) {

    if (clamp(texcoordPast, 0.0, 1.0) != texcoordPast) {
        return currentColor;
    } else {

        vec4 previous = texture2DLod(colortex3, texcoordPast, 0.0);

        vec3 left = texture2DLod(colortex1, texcoord + vec2(-pixelSizeX, 0.0), 0.0).rgb;
        vec3 right = texture2DLod(colortex1, texcoord + vec2(pixelSizeX, 0.0), 0.0).rgb;
        vec3 down = texture2DLod(colortex1, texcoord + vec2(0.0, -pixelSizeY), 0.0).rgb;
        vec3 up = texture2DLod(colortex1, texcoord + vec2(0.0, pixelSizeY), 0.0).rgb;
        vec3 ul = texture2DLod(colortex1, texcoord + vec2(-pixelSizeX, pixelSizeY), 0.0).rgb;
        vec3 ur = texture2DLod(colortex1, texcoord + vec2(pixelSizeX, pixelSizeY), 0.0).rgb;
        vec3 dl = texture2DLod(colortex1, texcoord + vec2(-pixelSizeX, -pixelSizeY), 0.0).rgb;
        vec3 dr = texture2DLod(colortex1, texcoord + vec2(pixelSizeX, -pixelSizeY), 0.0).rgb;

        vec3 resolved = taaResolve(currentColor.rgb, previous.rgb, texcoordPast, depthValue, up, down, left, right, ul, ur, dl, dr);
        return vec4(resolved, mix(currentColor.a, previous.a, 0.5));
    }
}
