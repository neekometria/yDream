#ifndef YDREAM_SATURATE
#define YDREAM_SATURATE(x) clamp(x, 0.0, 1.0)
#endif

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

// View-space distance of a depth buffer value. TAA only ever compares depths
// with each other, so linearising them first makes the tolerance independent of
// the hugely non-linear vanilla depth distribution.
float taaPlanarDepth(float depthValue) {
    return (near * far) / max(far - depthValue * (far - near), 0.0000001);
}

// Resolves one frame of TAA/ATAA.
//
// The caller reprojects the current pixel into the previous frame; this
// function decides whether that history still belongs to the same surface and
// then clips and blends it. The history colour is kept in colortex3, and the
// previous frame's depth is recovered by sampling depthtex1 at the reprojected
// position, so no extra metadata buffer is needed.
//
// currentDepth is the depth of the pixel being resolved. historyUsed tells the
// caller whether the history contributed (the DOF path needs that to decide
// whether it may reuse the history alpha).
vec4 fastTaa(vec4 currentColor, vec2 previousUV, float currentDepth, out float historyUsed) {
    historyUsed = 0.0;

    // colortex3 is not cleared, so it holds garbage on the first frames after a
    // pack reload or a dimension change. Skipping the blend until it has been
    // written once avoids a one-frame flash of noise.
    if (frameCounter < 2) {
        return currentColor;
    }

    vec2 pixelSize = vec2(pixelSizeX, pixelSizeY);

    if (previousUV.x < 0.0 || previousUV.y < 0.0 || previousUV.x > 1.0 || previousUV.y > 1.0) {
        return currentColor;
    }

    float historyDepth = texture2DLod(depthtex1, previousUV, 0.0).r;

    bool currentSky = currentDepth >= 0.9999;
    bool historySky = historyDepth >= 0.9999;

    // Sky and geometry must never share history. The sky is reprojected with a
    // rotation only, so mixing the two smears every silhouette into the sky.
    if (currentSky != historySky) {
        return currentColor;
    }

    float currentPlanar = 0.0;
    float depthError = 0.0;
    float depthTolerance = 1.0;
    float depthConfidence = 1.0;

    if (!currentSky) {
        currentPlanar = taaPlanarDepth(currentDepth);
        float historyPlanar = taaPlanarDepth(historyDepth);
        depthError = abs(currentPlanar - historyPlanar);
        // 1.5% of the distance plus 5 cm: enough for reprojection error, depth
        // precision and the sub-pixel jitter, tight enough to reject real
        // disocclusions.
        depthTolerance = currentPlanar * 0.015 + 0.05;

        // A depth mismatch usually means a disocclusion, but rejecting the
        // history outright makes the jittered frames alternate between
        // "blended" and "raw", which reads as the whole image shaking. Instead
        // measure how far off the history is and fade it out smoothly. Only a
        // clear disocclusion (several times the tolerance) drops it entirely.
        depthConfidence = 1.0 - smoothstep(depthTolerance, depthTolerance * 5.0, depthError);

        if (depthConfidence <= 0.0) {
            return currentColor;
        }
    }

    vec3 previous = texture2DLod(colortex3, previousUV, 0.0).rgb;

    vec3 c = taaToneIn(currentColor.rgb);
    vec3 h = taaToneIn(previous);

    vec3 nLeft = taaToneIn(texture2DLod(colortex1, texcoord + vec2(-pixelSizeX, 0.0), 0.0).rgb);
    vec3 nRight = taaToneIn(texture2DLod(colortex1, texcoord + vec2(pixelSizeX, 0.0), 0.0).rgb);
    vec3 nDown = taaToneIn(texture2DLod(colortex1, texcoord + vec2(0.0, -pixelSizeY), 0.0).rgb);
    vec3 nUp = taaToneIn(texture2DLod(colortex1, texcoord + vec2(0.0, pixelSizeY), 0.0).rgb);

    #if ATAA_QUALITY != 0
        vec3 nUl = taaToneIn(texture2DLod(colortex1, texcoord + vec2(-pixelSizeX, pixelSizeY), 0.0).rgb);
        vec3 nUr = taaToneIn(texture2DLod(colortex1, texcoord + vec2(pixelSizeX, pixelSizeY), 0.0).rgb);
        vec3 nDl = taaToneIn(texture2DLod(colortex1, texcoord + vec2(-pixelSizeX, -pixelSizeY), 0.0).rgb);
        vec3 nDr = taaToneIn(texture2DLod(colortex1, texcoord + vec2(pixelSizeX, -pixelSizeY), 0.0).rgb);

        vec3 sum = c + nLeft + nRight + nDown + nUp + nUl + nUr + nDl + nDr;
        vec3 sumSq = c * c + nLeft * nLeft + nRight * nRight + nDown * nDown + nUp * nUp +
            nUl * nUl + nUr * nUr + nDl * nDl + nDr * nDr;
        const float invCount = 0.1111111111;

        vec3 mean = sum * invCount;
        vec3 stdDev = sqrt(max(sumSq * invCount - mean * mean, vec3(0.0)));

        vec3 colorMax = max(max(max(nLeft, nRight), max(nDown, nUp)), max(max(nUl, nUr), max(max(nDl, nDr), c)));
        vec3 colorMin = min(min(min(nLeft, nRight), min(nDown, nUp)), min(min(nUl, nUr), min(min(nDl, nDr), c)));
    #else
        vec3 sum = c + nLeft + nRight + nDown + nUp;
        vec3 sumSq = c * c + nLeft * nLeft + nRight * nRight + nDown * nDown + nUp * nUp;
        const float invCount = 0.2;

        vec3 mean = sum * invCount;
        vec3 stdDev = sqrt(max(sumSq * invCount - mean * mean, vec3(0.0)));

        vec3 colorMax = max(max(nLeft, nRight), max(nDown, nUp));
        vec3 colorMin = min(min(nLeft, nRight), min(nDown, nUp));
        colorMax = max(colorMax, c);
        colorMin = min(colorMin, c);
    #endif

    // ATAA adapts the rejection box to the local contrast. Low contrast areas
    // keep more history; high contrast edges reject it aggressively.
    float contrast = luma(colorMax - colorMin);
    float gamma = mix(1.15, 2.5, YDREAM_SATURATE(contrast * 5.0));

    vec3 boxMin = max(colorMin, mean - stdDev * gamma);
    vec3 boxMax = min(colorMax, mean + stdDev * gamma);
    boxMin = min(boxMin, boxMax - 0.0001);

    vec3 clipped = taaClipToBox(h, boxMin, boxMax);

    float clipAmount = YDREAM_SATURATE(distance(h, clipped) / (distance(boxMin, boxMax) + 0.03));

    #if AA_MODE == 1
        float historyWeight = 0.82;
    #elif AA_MODE == 5
        // SMAA T2x resolves after exactly two frames.
        float historyWeight = 0.50;
    #elif ATAA_QUALITY == 0
        float historyWeight = 0.86;
    #else
        float historyWeight = 0.92;
    #endif

    historyWeight = mix(historyWeight, min(historyWeight, 0.35), clipAmount);

    // Fast motion and residual depth error both reduce the history share.
    float motionPixels = length((texcoord - previousUV) / pixelSize);
    historyWeight *= 1.0 - clamp(motionPixels / 48.0, 0.0, 0.45);
    historyWeight *= 1.0 - YDREAM_SATURATE(depthError / max(depthTolerance, 0.0001)) * 0.35;

    // Partial depth mismatches (silhouettes, reprojection error) now fade the
    // history instead of dropping it. Keeping a small share still lets the
    // jittered samples converge, so the image stops flickering between the
    // accumulated and the raw frame.
    historyWeight *= mix(0.10, 1.0, depthConfidence);

    #if AA_MODE != 5
        // Distant geometry is usually static and benefits from a long history.
        // Never do this for T2x: it must resolve after exactly two frames.
        float farFactor = smoothstep(128.0, 512.0, currentPlanar);
        historyWeight = mix(historyWeight, max(historyWeight, 0.965), farFactor * (1.0 - clipAmount));
    #endif

    #ifdef MOTION_BLUR
        historyWeight *= 1.0 - clamp(motionPixels * 0.004, 0.0, 0.25);
    #endif

    historyUsed = 1.0;

    return vec4(taaToneOut(mix(c, clipped, historyWeight)), currentColor.a);
}

vec4 fastTaaDepth(vec4 currentColor, vec2 previousUV, float currentDepth, out float historyUsed) {
    vec4 resolved = fastTaa(currentColor, previousUV, currentDepth, historyUsed);
    float previousAlpha = currentColor.a;

    if (historyUsed > 0.5) {
        previousAlpha = texture2DLod(colortex3, previousUV, 0.0).a;
    }

    resolved.a = mix(currentColor.a, previousAlpha, 0.5);
    return resolved;
}
