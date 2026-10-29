vec3 slViewPos(vec2 uv, float depthValue) {
    vec4 clipPos = vec4(uv * 2.0 - 1.0, depthValue * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * clipPos;
    return viewPos.xyz / viewPos.w;
}

float slStaticNoise(vec2 fragCoord) {
    return fract(52.9829189 * fract(dot(fragCoord, vec2(0.06711056, 0.00583715))));
}

vec3 slNormal(vec2 uv, vec3 centerPos) {
    vec2 px = vec2(pixelSizeX, pixelSizeY);

    vec3 posR = slViewPos(uv + vec2(px.x, 0.0), texture2DLod(depthtex0, uv + vec2(px.x, 0.0), 0.0).r);
    vec3 posL = slViewPos(uv - vec2(px.x, 0.0), texture2DLod(depthtex0, uv - vec2(px.x, 0.0), 0.0).r);
    vec3 posU = slViewPos(uv + vec2(0.0, px.y), texture2DLod(depthtex0, uv + vec2(0.0, px.y), 0.0).r);
    vec3 posD = slViewPos(uv - vec2(0.0, px.y), texture2DLod(depthtex0, uv - vec2(0.0, px.y), 0.0).r);

    vec3 dx = abs(posR.z - centerPos.z) < abs(posL.z - centerPos.z) ? posR - centerPos : centerPos - posL;
    vec3 dy = abs(posU.z - centerPos.z) < abs(posD.z - centerPos.z) ? posU - centerPos : centerPos - posD;

    return normalize(cross(dx, dy) + vec3(0.0, 0.0, 0.00001));
}

vec3 slSnapAxis(vec3 n) {
    vec3 a = abs(n);

    if (a.x > a.y && a.x > a.z) {
        return vec3(sign(n.x), 0.0, 0.0);
    }

    if (a.y > a.z) {
        return vec3(0.0, sign(n.y), 0.0);
    }

    return vec3(0.0, 0.0, sign(n.z));
}

#if GLEAM_VOXEL_LIGHT > 0
float vlMax3(vec3 v) {
    return max(v.r, max(v.g, v.b));
}

vec3 vlFetch(vec3 idx) {
    if (idx.x < 0.0 || idx.y < 0.0 || idx.z < 0.0 || idx.x >= 96.0 || idx.y >= 48.0 || idx.z >= 96.0) {
        return vec3(0.0);
    }
    float tileX = mod(idx.y, 7.0);
    float tileY = floor(idx.y / 7.0);
    vec2 texel = vec2(tileX * 96.0 + idx.x, tileY * 96.0 + idx.z) + 0.5;
    return texture2DLod(colortex8, texel / 672.0, 0.0).rgb;
}

uniform vec3 previousCameraPosition;

vec3 vlCell(vec3 worldRel) {
    return cameraPosition + worldRel - floor(previousCameraPosition) + vec3(48.0, 24.0, 48.0) - 0.5;
}

vec3 vlField(vec3 worldRel) {
    vec3 cell = vlCell(worldRel);
    vec3 base = floor(cell);
    vec3 f = cell - base;

    vec3 x00 = mix(vlFetch(base), vlFetch(base + vec3(1.0, 0.0, 0.0)), f.x);
    vec3 x10 = mix(vlFetch(base + vec3(0.0, 1.0, 0.0)), vlFetch(base + vec3(1.0, 1.0, 0.0)), f.x);
    vec3 x01 = mix(vlFetch(base + vec3(0.0, 0.0, 1.0)), vlFetch(base + vec3(1.0, 0.0, 1.0)), f.x);
    vec3 x11 = mix(vlFetch(base + vec3(0.0, 1.0, 1.0)), vlFetch(base + vec3(1.0, 1.0, 1.0)), f.x);

    return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

vec3 vlApply(vec3 color, vec2 uv, vec3 viewPos, out vec3 fieldOut) {
    fieldOut = vec3(0.0);

    vec4 lightData = texture2DLod(colortex2, uv, 0.0);
    float candle = lightData.a;

    if (candle > 0.01 && vlMax3(lightData.rgb) < 0.05) {
        vec3 normalWorld = slSnapAxis(mat3(gbufferModelViewInverse) * slNormal(uv, viewPos));
        vec3 surface = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + normalWorld * 0.55;
        vec3 field = vlField(surface);
        float strength = vlMax3(field);
        fieldOut = field;

        if (strength > 0.015) {
            vec3 albedo = texture2DLod(colortex9, uv, 0.0).rgb;
            vec3 hue = field / strength;
            vec3 hueNormal = mix(vec3(1.0), min(hue / max(luma(hue), 0.08), vec3(2.1)), 0.9);
            vec3 warmNormal = vec3(1.0, 0.60, 0.26) / 0.6605;

            float strengthOut = vlMax3(vlField(surface + normalWorld * 0.9));
            float strengthIn = vlMax3(vlField(surface - normalWorld * 0.15));
            float facing = clamp(0.66 + 1.5 * (strengthOut - strengthIn), 0.5, 1.0);

            float dominance = smoothstep(0.08, 0.45, strength);
            float reach = smoothstep(0.004, 0.14, candle);

            float spill = pow(strength, 2.0);
            vec3 replaced = albedo * (hueNormal - warmNormal) * (candle * dominance * COLORED_LIGHT_STRENGTH * 0.8);
            vec3 glow = albedo * hueNormal * (spill * 0.42 * facing * reach * COLORED_LIGHT_STRENGTH);
            color = max(color + replaced + glow, vec3(0.0));
        }
    }

    return color;
}
#endif

#ifdef GLEAM_VL_GLOW
vec3 vlFetchSoft(vec3 cell) {
    vec3 base = floor(cell);
    vec3 f = cell - base;

    if (base.x < 0.0 || base.z < 0.0 || base.y < 0.0 || base.x >= 95.0 || base.z >= 95.0 || base.y >= 47.0) {
        return vec3(0.0);
    }

    float tileLowX = mod(base.y, 7.0);
    float tileLowY = floor(base.y / 7.0);
    float upperY = base.y + 1.0;
    float tileHighX = mod(upperY, 7.0);
    float tileHighY = floor(upperY / 7.0);

    vec2 inTile = vec2(base.x + f.x, base.z + f.z) + 0.5;
    vec3 lower = texture2DLod(colortex8, (vec2(tileLowX, tileLowY) * 96.0 + inTile) / 672.0, 0.0).rgb;
    vec3 upper = texture2DLod(colortex8, (vec2(tileHighX, tileHighY) * 96.0 + inTile) / 672.0, 0.0).rgb;

    return mix(lower, upper, f.y);
}

vec3 vlGlow(vec2 uv, float depthValue, float noise) {
    vec3 farView = slViewPos(uv, 1.0);
    vec3 rayDir = normalize(mat3(gbufferModelViewInverse) * farView);

    float surfaceDistance = 40.0;
    if (depthValue < 0.99999) {
        surfaceDistance = length(slViewPos(uv, depthValue));
    }

    float maxDistance = min(surfaceDistance, 30.0);
    float stepsInverse = 1.0 / float(GLEAM_VL_GLOW_STEPS);

    vec3 accumulated = vec3(0.0);

    for (int i = 0; i < GLEAM_VL_GLOW_STEPS; i++) {
        float lowEdge = float(i) * stepsInverse;
        float highEdge = float(i + 1) * stepsInverse;
        float centerT = (float(i) + noise) * stepsInverse;
        float dist = 0.2 + maxDistance * pow(centerT, 1.35);
        float segment = maxDistance * (pow(highEdge, 1.35) - pow(lowEdge, 1.35));

        vec3 field = vlFetchSoft(vlCell(rayDir * dist) + 0.5);
        float fieldStrength = vlMax3(field);

        if (fieldStrength > 0.004) {
            vec3 hue = field / fieldStrength;
            vec3 saturated = mix(vec3(1.0), min(hue / max(luma(hue), 0.08), vec3(2.1)), 0.9);
            accumulated += saturated * (pow(fieldStrength, 1.8) * segment);
        }
    }

    float daylight = smoothstep(0.03, 0.42, sunElevation) * clamp(float(eyeBrightnessSmooth.y) * 0.004166666666666667, 0.0, 1.0);
    float darkness = 1.0 - 0.85 * daylight;

    return accumulated * (0.05 * COLORED_LIGHT_STRENGTH * darkness);
}
#endif
