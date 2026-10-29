float giNoise(vec2 fragCoord) {
    return fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715))));
}

vec3 giViewPos(vec2 uv, float depthValue) {
    vec4 clipPos = vec4(uv * 2.0 - 1.0, depthValue * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * clipPos;
    return viewPos.xyz / viewPos.w;
}

vec3 giSnapAxis(vec3 n) {
    vec3 a = abs(n);

    if (a.x > a.y && a.x > a.z) {
        return vec3(sign(n.x), 0.0, 0.0);
    }

    if (a.y > a.z) {
        return vec3(0.0, sign(n.y), 0.0);
    }

    return vec3(0.0, 0.0, sign(n.z));
}

#ifdef GI_PASS_GATHER
vec3 giNormal(vec2 uv, vec3 centerPos) {
    vec2 px = vec2(pixelSizeX, pixelSizeY);

    vec3 posR = giViewPos(uv + vec2(px.x, 0.0), texture2DLod(depthtex0, uv + vec2(px.x, 0.0), 0.0).r);
    vec3 posL = giViewPos(uv - vec2(px.x, 0.0), texture2DLod(depthtex0, uv - vec2(px.x, 0.0), 0.0).r);
    vec3 posU = giViewPos(uv + vec2(0.0, px.y), texture2DLod(depthtex0, uv + vec2(0.0, px.y), 0.0).r);
    vec3 posD = giViewPos(uv - vec2(0.0, px.y), texture2DLod(depthtex0, uv - vec2(0.0, px.y), 0.0).r);

    vec3 dx = abs(posR.z - centerPos.z) < abs(posL.z - centerPos.z) ? posR - centerPos : centerPos - posL;
    vec3 dy = abs(posU.z - centerPos.z) < abs(posD.z - centerPos.z) ? posU - centerPos : centerPos - posD;

    return normalize(cross(dx, dy) + vec3(0.0, 0.0, 0.00001));
}

vec4 giGather(vec2 uv, float depthValue, float noise) {
    vec3 viewPos = giViewPos(uv, depthValue);
    float viewDepth = -viewPos.z;
    float viewDist = length(viewPos);

    if (viewDepth > 72.0) {
        return vec4(0.0);
    }

    vec3 normalWorld = giSnapAxis(mat3(gbufferModelViewInverse) * giNormal(uv, viewPos));
    vec3 receiver = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + normalWorld * 0.35;

    vec3 shadowPos = mat3(shadowModelView) * receiver + shadowModelView[3].xyz;
    shadowPos = vec3(shadowProjection[0].x, shadowProjection[1].y, shadowProjection[2].z) * shadowPos + shadowProjection[3].xyz;

    float distortion = length(shadowPos.xy) * SHADOW_DIST + (1.0 - SHADOW_DIST);
    vec2 shadowUV = shadowPos.xy / distortion * 0.5 + 0.5;

    if (shadowUV.x < 0.02 || shadowUV.x > 0.98 || shadowUV.y < 0.02 || shadowUV.y > 0.98) {
        return vec4(0.0, 0.0, 0.0, viewDist);
    }

    float radiusUV = 0.5 * GI_RADIUS * shadowProjection[0].x / distortion;
    float discAreaWorld = 12.5663706 * radiusUV * radiusUV / (shadowProjection[0].x * shadowProjection[1].y);
    float tapsInverse = 1.0 / float(GI_TAPS);

    float sunHeight = (gbufferModelViewInverse * vec4(normalize(sunPosition), 0.0)).y;
    float lightScale = 0.08 + 0.92 * smoothstep(-0.05, 0.25, sunHeight);

    vec3 gathered = vec3(0.0);

    for (int i = 0; i < GI_TAPS; i++) {
        float tapIndex = float(i) + noise;
        float angle = tapIndex * 2.39996323 + noise * 6.2831853;
        float tapRadius = sqrt((tapIndex + 0.5) * tapsInverse);
        tapRadius = mix(tapRadius, tapRadius * tapRadius, 0.35);
        vec2 tapUV = shadowUV + vec2(cos(angle), sin(angle)) * (tapRadius * radiusUV);

        vec4 tapData = texture2D(shadowcolor1, tapUV);

        if (tapData.a > 0.5) {
            vec3 tapAlbedo = texture2D(shadowcolor0, tapUV).rgb;
            vec3 toTap = tapData.xyz - receiver;
            float distSq = dot(toTap, toTap) + 2.2;
            vec3 dir = toTap * inversesqrt(distSq);

            float cosReceiver = max(dot(normalWorld, dir), 0.0);
            float cosSource = 0.35 + 0.65 * max(-dir.y, 0.0);

            float tapDistortion = (1.0 - SHADOW_DIST) / max(1.0 - SHADOW_DIST * length(tapUV * 2.0 - 1.0), 0.02);
            float areaWeight = tapDistortion * tapDistortion * tapDistortion / (1.0 - SHADOW_DIST);

            vec3 tapContribution = tapAlbedo * (cosReceiver * cosSource * areaWeight / distSq);
            gathered += min(tapContribution, vec3(1.2));
        }
    }

    vec3 indirect = gathered * (discAreaWorld * tapsInverse * 0.3183099 * lightScale);

    return vec4(min(indirect, vec3(1.2)), viewDist);
}
#endif

#ifdef GI_PASS_TEMPORAL
vec4 giResolve(sampler2D historyTex, vec4 current, vec2 uv, float keepBase) {
    if (current.a <= 0.0) {
        return vec4(0.0);
    }

    vec3 rayDir = normalize(mat3(gbufferModelViewInverse) * giViewPos(uv, 1.0));
    vec3 rel = rayDir * current.a + (cameraPosition - previousCameraPosition);
    vec4 prevView = gbufferPreviousModelView * vec4(rel, 1.0);
    vec4 prevClip = gbufferPreviousProjection * prevView;

    if (prevClip.w <= 0.0) {
        return current;
    }

    vec2 prevUV = prevClip.xy / prevClip.w * 0.5 + 0.5;

    if (prevUV.x < 0.002 || prevUV.y < 0.002 || prevUV.x > 0.998 || prevUV.y > 0.998) {
        return current;
    }

    vec4 history = texture2DLod(historyTex, prevUV, 0.0);

    if (history.a <= 0.0) {
        return current;
    }

    float expectedDist = length(prevView.xyz);
    float distGap = abs(history.a - expectedDist) / max(expectedDist * 0.04, 0.12);
    float distOk = 1.0 - smoothstep(0.7, 1.0, distGap);

    float currentLuma = luma(current.rgb);
    float historyLuma = luma(history.rgb);
    float lumaGap = abs(currentLuma - historyLuma) / (max(abs(currentLuma), abs(historyLuma)) + 0.05);

    float keep = keepBase * distOk * (1.0 - 0.4 * smoothstep(0.4, 1.0, lumaGap));

    return vec4(mix(current.rgb, history.rgb, keep), current.a);
}
#endif

#if defined GI_PASS_BLUR && GLEAM_RSM_GI > 0
vec3 giBlur(vec2 uv) {
    vec4 center = texture2DLod(colortex14, uv, 0.0);

    if (center.a <= 0.0) {
        return vec3(0.0);
    }

    vec2 px = vec2(pixelSizeX, pixelSizeY) * 3.0;
    float depthTolerance = max(center.a * 0.12, 0.25);

    vec3 sum = center.rgb;
    float weightSum = 1.0;

    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            if (x != 0 || y != 0) {
                vec4 tapSample = texture2DLod(colortex14, uv + vec2(float(x), float(y)) * px, 0.0);

                if (tapSample.a > 0.0) {
                    float depthDelta = (tapSample.a - center.a) / depthTolerance;
                    float distanceWeight = exp(-float(x * x + y * y) * 0.16);
                    float weight = distanceWeight * exp(-depthDelta * depthDelta);
                    sum += tapSample.rgb * weight;
                    weightSum += weight;
                }
            }
        }
    }

    return sum / weightSum;
}
#endif
