#ifndef AURORA_LOW_COLOR
    #define AURORA_LOW_COLOR vec3(0.12, 1.0, 0.50)
    #define AURORA_HIGH_COLOR vec3(0.58, 0.28, 1.0)
#endif
#ifndef AURORA_MID_COLOR
    #define AURORA_MID_COLOR (mix(AURORA_LOW_COLOR, AURORA_HIGH_COLOR, 0.5) * 1.15)
#endif
#ifndef AURORA_RAY_COLOR
    #define AURORA_RAY_COLOR (AURORA_HIGH_COLOR * vec3(1.15, 0.80, 0.95))
#endif
#if AURORA_PALETTE == 1
    #undef AURORA_LOW_COLOR
    #undef AURORA_MID_COLOR
    #undef AURORA_HIGH_COLOR
    #undef AURORA_RAY_COLOR
    #define AURORA_LOW_COLOR vec3(0.60, 0.80, 0.80)
    #define AURORA_MID_COLOR vec3(0.44, 0.66, 0.82)
    #define AURORA_HIGH_COLOR vec3(0.58, 0.46, 0.78)
    #define AURORA_RAY_COLOR vec3(0.78, 0.42, 0.68)
#elif AURORA_PALETTE == 2
    #undef AURORA_LOW_COLOR
    #undef AURORA_MID_COLOR
    #undef AURORA_HIGH_COLOR
    #undef AURORA_RAY_COLOR
    #define AURORA_LOW_COLOR vec3(0.15, 0.95, 1.0)
    #define AURORA_MID_COLOR vec3(0.35, 0.58, 1.0)
    #define AURORA_HIGH_COLOR vec3(0.95, 0.25, 0.85)
    #define AURORA_RAY_COLOR vec3(1.0, 0.30, 0.80)
#elif AURORA_PALETTE == 3
    #undef AURORA_LOW_COLOR
    #undef AURORA_MID_COLOR
    #undef AURORA_HIGH_COLOR
    #undef AURORA_RAY_COLOR
    #define AURORA_LOW_COLOR vec3(1.0, 0.78, 0.30)
    #define AURORA_MID_COLOR vec3(1.0, 0.45, 0.48)
    #define AURORA_HIGH_COLOR vec3(0.85, 0.30, 0.85)
    #define AURORA_RAY_COLOR vec3(1.0, 0.35, 0.55)
#elif AURORA_PALETTE == 4
    #undef AURORA_LOW_COLOR
    #undef AURORA_MID_COLOR
    #undef AURORA_HIGH_COLOR
    #undef AURORA_RAY_COLOR
    #define AURORA_LOW_COLOR vec3(0.25, 1.0, 0.45)
    #define AURORA_MID_COLOR vec3(0.20, 0.95, 0.72)
    #define AURORA_HIGH_COLOR vec3(0.35, 0.55, 1.0)
    #define AURORA_RAY_COLOR vec3(0.90, 0.30, 0.60)
#elif AURORA_PALETTE == 5
    #undef AURORA_LOW_COLOR
    #undef AURORA_MID_COLOR
    #undef AURORA_HIGH_COLOR
    #undef AURORA_RAY_COLOR
    #define AURORA_LOW_COLOR vec3(0.30, 1.0, 0.50)
    #define AURORA_MID_COLOR vec3(0.70, 0.90, 0.35)
    #define AURORA_HIGH_COLOR vec3(1.0, 0.70, 0.30)
    #define AURORA_RAY_COLOR vec3(1.0, 0.55, 0.30)
#elif AURORA_PALETTE == 6
    #undef AURORA_LOW_COLOR
    #undef AURORA_MID_COLOR
    #undef AURORA_HIGH_COLOR
    #undef AURORA_RAY_COLOR
    #define AURORA_LOW_COLOR vec3(0.55, 0.95, 1.0)
    #define AURORA_MID_COLOR vec3(0.40, 0.75, 1.0)
    #define AURORA_HIGH_COLOR vec3(0.55, 0.60, 1.0)
    #define AURORA_RAY_COLOR vec3(0.70, 0.70, 1.0)
#elif AURORA_PALETTE == 7
    #undef AURORA_LOW_COLOR
    #undef AURORA_MID_COLOR
    #undef AURORA_HIGH_COLOR
    #undef AURORA_RAY_COLOR
    #define AURORA_LOW_COLOR vec3(1.0, 0.70, 0.80)
    #define AURORA_MID_COLOR vec3(0.95, 0.50, 0.75)
    #define AURORA_HIGH_COLOR vec3(0.75, 0.40, 0.95)
    #define AURORA_RAY_COLOR vec3(1.0, 0.45, 0.75)
#elif AURORA_PALETTE == 8
    #undef AURORA_LOW_COLOR
    #undef AURORA_MID_COLOR
    #undef AURORA_HIGH_COLOR
    #undef AURORA_RAY_COLOR
    #define AURORA_LOW_COLOR vec3(1.0, 0.85, 0.30)
    #define AURORA_MID_COLOR vec3(1.0, 0.55, 0.20)
    #define AURORA_HIGH_COLOR vec3(1.0, 0.25, 0.30)
    #define AURORA_RAY_COLOR vec3(1.0, 0.35, 0.25)
#elif AURORA_PALETTE == 9
    #undef AURORA_LOW_COLOR
    #undef AURORA_MID_COLOR
    #undef AURORA_HIGH_COLOR
    #undef AURORA_RAY_COLOR
    #define AURORA_LOW_COLOR vec3(AURORA_CUSTOM_LOW_R, AURORA_CUSTOM_LOW_G, AURORA_CUSTOM_LOW_B)
    #define AURORA_HIGH_COLOR vec3(AURORA_CUSTOM_HIGH_R, AURORA_CUSTOM_HIGH_G, AURORA_CUSTOM_HIGH_B)
    #define AURORA_MID_COLOR (mix(AURORA_LOW_COLOR, AURORA_HIGH_COLOR, 0.5))
    #define AURORA_RAY_COLOR AURORA_HIGH_COLOR
#endif

float hgPhase(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (12.566370614359172 * pow(max(1.0 + g2 - 2.0 * g * cosTheta, 0.0001), 1.5));
}

float valueNoise3(vec3 p) {
    vec3 cell = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n000 = hash13(cell);
    float n100 = hash13(cell + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(cell + vec3(0.0, 1.0, 0.0));
    float n110 = hash13(cell + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(cell + vec3(0.0, 0.0, 1.0));
    float n101 = hash13(cell + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(cell + vec3(0.0, 1.0, 1.0));
    float n111 = hash13(cell + vec3(1.0, 1.0, 1.0));

    return mix(
        mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
        mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
        f.z
    );
}

float fbm3(vec3 p) {
    float total = valueNoise3(p) * 0.5;
    total += valueNoise3(p * 2.03 + 11.7) * 0.25;
    total += valueNoise3(p * 4.11 + 23.1) * 0.125;
    total += valueNoise3(p * 8.27 + 37.9) * 0.0625;
    return total / 0.9375;
}

vec3 atmosphericSky(float viewElevation, float cosSun, float sunAltitude, float turbidity) {
    float viewCos = clamp(viewElevation, 0.0, 1.0);
    float viewZenith = degrees(acos(viewCos));
    float airmassView = 1.0 / (viewCos + 0.50572 * pow(max(96.07995 - viewZenith, 0.5), -1.6364));

    float sunCos = clamp(sunAltitude, 0.0, 1.0);
    float sunZenith = degrees(acos(sunCos));
    float airmassSun = 1.0 / (sunCos + 0.50572 * pow(max(96.07995 - sunZenith, 0.5), -1.6364));

    vec3 tauRayleigh = vec3(0.0464, 0.108, 0.265);
    float tauMie = 0.006 * turbidity;
    vec3 tauTotal = tauRayleigh + vec3(tauMie);

    float lowAir = mix(0.28, 1.0, exp(-viewCos * 3.0));
    vec3 sunTransmission = exp(-tauTotal * airmassSun * lowAir);

    float phaseRayleigh = 0.05968310365946075 * (1.0 + cosSun * cosSun);
    float phaseMie = hgPhase(cosSun, 0.78);

    vec3 scatter = tauRayleigh * (phaseRayleigh + 0.09) + vec3(tauMie * phaseMie * 0.55);
    vec3 inscatter = (1.0 - exp(-tauTotal * airmassView)) / tauTotal;

    return sunTransmission * scatter * inscatter;
}

vec3 starField(vec3 worldDir, float pixelAngle, float time, float density, float twinkleAmount, float starScale) {

    vec3 p = worldDir * starScale;
    vec3 cell = floor(p);

    float presence = hash13(cell);
    if (presence > density) {
        return vec3(0.0);
    }

    vec3 jitter = vec3(
        hash13(cell + vec3(17.31, 3.7, 9.1)),
        hash13(cell + vec3(41.77, 8.2, 2.6)),
        hash13(cell + vec3(83.19, 5.5, 6.4))
    ) * 0.34 + 0.33;

    float magnitudeRaw = hash13(cell + vec3(5.13, 12.9, 1.7));
    float magnitude = magnitudeRaw * magnitudeRaw * magnitudeRaw;
    float bright = smoothstep(0.78, 0.98, magnitudeRaw);

    float baseRadius = mix(0.15, 0.32, magnitude) + bright * 0.10;
    float pixelRadius = pixelAngle * starScale * 0.9;
    float radius = max(baseRadius, pixelRadius);
    float energy = clamp((baseRadius * baseRadius) / (radius * radius), 0.15, 1.0);

    float dist = length(p - (cell + jitter));
    float spot = (1.0 - smoothstep(0.0, radius, dist));
    spot *= spot;

    float halo = exp(-dist * 9.0) * bright * 0.30;

    float phase = hash13(cell + vec3(9.7, 4.4, 30.2));
    float twinkle = 1.0 - twinkleAmount * (0.5 + 0.5 * sin(time * (1.4 + phase * 4.0) + phase * 90.0)) * (0.55 + 0.45 * bright);

    float temperature = hash13(cell + vec3(2.9, 6.1, 14.3));
    vec3 tint = mix(vec3(0.62, 0.78, 1.0), vec3(1.0, 0.95, 0.88), smoothstep(0.0, 0.55, temperature));
    tint = mix(tint, vec3(1.0, 0.72, 0.50), smoothstep(0.82, 1.0, temperature));

    return tint * (spot * energy * (0.50 + magnitude * 2.6) + halo) * twinkle;
}

float noise1(float x, float seed) {
    float cell = floor(x);
    float f = fract(x);
    f = f * f * (3.0 - 2.0 * f);

    return mix(hash13(vec3(cell, seed, 0.37)), hash13(vec3(cell + 1.0, seed, 0.37)), f);
}

float valueNoise2(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash13(vec3(cell, 0.71));
    float b = hash13(vec3(cell + vec2(1.0, 0.0), 0.71));
    float c = hash13(vec3(cell + vec2(0.0, 1.0), 0.71));
    float d = hash13(vec3(cell + vec2(1.0, 1.0), 0.71));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 skyFaceUV(vec3 d, out float faceId) {
    vec3 a = abs(d);
    vec2 uv;

    if (a.x >= a.y && a.x >= a.z) {
        uv = d.yz / a.x;
        faceId = d.x > 0.0 ? 0.0 : 1.0;
    } else if (a.y >= a.z) {
        uv = d.xz / a.y;
        faceId = d.y > 0.0 ? 2.0 : 3.0;
    } else {
        uv = d.xy / a.z;
        faceId = d.z > 0.0 ? 4.0 : 5.0;
    }

    return uv;
}

float skyCellHash(vec2 cell, float faceId, float salt) {
    return hash13(vec3(cell, faceId * 7.7 + salt));
}

vec3 heroStars(vec3 worldDir, float pixelAngle, float time, float amount, float sizeScale, float sparkle) {
    const float grid = 0.06;
    float faceId;
    vec2 uv = skyFaceUV(worldDir, faceId);
    vec2 cell = floor(uv / grid);

    if (skyCellHash(cell, faceId, 3.3) > amount * 0.025) {
        return vec3(0.0);
    }

    vec2 nodeUV = (cell + vec2(skyCellHash(cell, faceId, 11.7), skyCellHash(cell, faceId, 29.1)) * 0.4 + 0.3) * grid;
    vec2 offset = (uv - nodeUV) / (1.0 + dot(uv, uv));
    float dist = length(offset);

    float magnitudeRaw = skyCellHash(cell, faceId, 7.7);
    float magnitude = magnitudeRaw * magnitudeRaw;

    float size = max(sizeScale * mix(0.0016, 0.0034, magnitude), pixelAngle * 1.2);
    float edgeFade = (1.0 - smoothstep(0.0045, 0.0125, dist));

    float core = exp(-(dist * dist) / (size * size) * 2.0);
    float halo = exp(-dist / (size * 4.5)) * 0.34 * edgeFade;

    float dx = abs(offset.x);
    float dy = abs(offset.y);
    float spikes = (exp(-dx / (size * 5.0)) * exp(-dy / (size * 0.35)) + exp(-dy / (size * 5.0)) * exp(-dx / (size * 0.35))) * 0.5;
    spikes *= smoothstep(0.30, 0.80, magnitudeRaw) * edgeFade * sparkle;

    float phase = skyCellHash(cell, faceId, 19.1);
    float twinkle = 0.82 + 0.18 * sin(time * (0.9 + phase * 2.2) + phase * 40.0);

    float temperature = skyCellHash(cell, faceId, 2.9);
    vec3 tint = mix(vec3(0.60, 0.78, 1.0), vec3(1.0, 0.96, 0.90), smoothstep(0.0, 0.50, temperature));
    tint = mix(tint, vec3(1.0, 0.74, 0.52), smoothstep(0.84, 1.0, temperature));

    return tint * ((core * 2.3 + halo + spikes * 1.1) * (0.55 + 0.9 * magnitude) * twinkle);
}

vec2 constellationNode(vec2 cell, float faceId) {
    return (cell + vec2(skyCellHash(cell, faceId, 13.3), skyCellHash(cell, faceId, 27.7)) * 0.5 + 0.25) * 0.13;
}

bool constellationHas(vec2 cell, float faceId) {
    return skyCellHash(cell, faceId, 4.1) < 0.17;
}

bool constellationLinked(vec2 cell, float faceId, float axis) {
    return skyCellHash(cell, faceId, axis * 17.3 + 5.1) < 0.42;
}

float constellationSegment(vec2 p, vec2 a, vec2 b, float width, float angularScale) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.000001), 0.0, 1.0);
    float dist = length(p - (a + ab * t)) * angularScale;
    return (1.0 - smoothstep(0.0, width, dist)) * smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.94, 1.0, t));
}

vec3 constellations(vec3 worldDir, float pixelAngle, float time) {
    const float grid = 0.13;
    float faceId;
    vec2 uv = skyFaceUV(worldDir, faceId);
    vec2 cell = floor(uv / grid);

    if (!constellationHas(cell, faceId)) {
        return vec3(0.0);
    }

    vec2 nodeUV = constellationNode(cell, faceId);
    float angularScale = 1.0 / (1.0 + dot(uv, uv));
    float width = max(0.0015, pixelAngle * 1.3);
    float lineAmount = 0.0;

    for (int axis = 0; axis < 4; axis++) {
        vec2 axisStep = axis == 0 ? vec2(1.0, 0.0) : (axis == 1 ? vec2(0.0, 1.0) : (axis == 2 ? vec2(1.0, 1.0) : vec2(1.0, -1.0)));

        vec2 forwardCell = cell + axisStep;
        if (constellationHas(forwardCell, faceId) && constellationLinked(cell, faceId, float(axis))) {
            lineAmount = max(lineAmount, constellationSegment(uv, nodeUV, constellationNode(forwardCell, faceId), width, angularScale));
        }

        vec2 backCell = cell - axisStep;
        if (constellationHas(backCell, faceId) && constellationLinked(backCell, faceId, float(axis))) {
            lineAmount = max(lineAmount, constellationSegment(uv, constellationNode(backCell, faceId), nodeUV, width, angularScale));
        }
    }

    float phase = skyCellHash(cell, faceId, 8.8);
    float shimmer = 0.78 + 0.22 * sin(time * 0.5 + phase * 6.2831853);

    float nodeDist = length(uv - nodeUV) * angularScale;
    float nodeSize = max(0.0030, pixelAngle * 1.8);
    float node = exp(-(nodeDist * nodeDist) / (nodeSize * nodeSize) * 2.0) * 1.4 + exp(-nodeDist / (nodeSize * 3.0)) * 0.12 * (1.0 - smoothstep(0.008, 0.03, nodeDist));

    vec3 lineColor = vec3(0.55, 0.72, 1.0);
    vec3 nodeColor = mix(vec3(0.70, 0.84, 1.0), vec3(1.0, 0.95, 0.88), phase);

    return lineColor * (lineAmount * 0.55 * shimmer) + nodeColor * (node * shimmer);
}

float starCluster(vec3 dir) {
    float broad = valueNoise3(dir * 2.4 + vec3(3.7, 1.3, 8.1));
    float fine = valueNoise3(dir * 6.3 + vec3(11.1, 5.9, 2.3));
    return smoothstep(0.22, 0.78, broad * 0.68 + fine * 0.32);
}

vec3 starDust(vec3 dir, float cluster) {
    float grain = valueNoise3(dir * 15.0 + vec3(5.0, 9.0, 1.0));
    float veil = cluster * cluster * (0.55 + 0.45 * grain);
    vec3 tint = mix(vec3(0.40, 0.52, 1.0), vec3(0.78, 0.60, 1.0), valueNoise3(dir * 3.1 + 7.7));
    return tint * veil;
}

vec3 airglow(vec3 dir, float time) {
    float e = dir.y;

    if (e < 0.02 || e > 0.70) {
        return vec3(0.0);
    }

    float lowBand = smoothstep(0.02, 0.12, e) * (1.0 - smoothstep(0.14, 0.40, e));
    float highBand = smoothstep(0.20, 0.34, e) * (1.0 - smoothstep(0.38, 0.70, e));
    vec2 q = dir.xz / (e + 0.40);
    float drift = valueNoise2(q * 1.3 + vec2(time * 0.004, 4.0));
    float ripple = 0.5 + 0.5 * sin(q.x * 6.5 + q.y * 3.2 + drift * 7.0 + time * 0.05);
    float ripple2 = 0.5 + 0.5 * sin(q.x * 3.1 - q.y * 5.4 + drift * 5.0 - time * 0.03);
    vec3 low = vec3(0.05, 0.52, 0.40) * (lowBand * (0.35 + 0.65 * ripple));
    vec3 high = vec3(0.34, 0.14, 0.56) * (highBand * (0.30 + 0.70 * ripple2));
    return (low + high) * (0.55 + 0.45 * drift);
}

vec3 shootingStarColor(float hueSeed) {
    #if SHOOTING_COLOR == 1
        return vec3(1.0, 0.98, 0.95);
    #elif SHOOTING_COLOR == 2
        return vec3(0.55, 0.82, 1.0);
    #elif SHOOTING_COLOR == 3
        return vec3(1.0, 0.82, 0.45);
    #elif SHOOTING_COLOR == 4
        return vec3(1.0, 0.55, 0.80);
    #elif SHOOTING_COLOR == 5
        return vec3(0.45, 1.0, 0.65);
    #elif SHOOTING_COLOR == 6
        return mix(AURORA_LOW_COLOR, AURORA_HIGH_COLOR, hueSeed) * 1.1;
    #elif SHOOTING_COLOR == 7
        return 0.55 + 0.45 * cos(6.283185307179586 * (hueSeed + vec3(0.0, 0.33, 0.67)));
    #elif SHOOTING_COLOR == 8
        return vec3(SHOOTING_R, SHOOTING_G, SHOOTING_B);
    #else
        return vec3(0.88, 0.94, 1.0);
    #endif
}

float shootingStarTrail(vec3 worldDir, float time, float cycleLength, float slot, float lengthScale, float speedScale, float pixelAngle, out float hueSeed) {
    float shifted = time + slot * 3.7;
    float cycle = floor(shifted / cycleLength);
    float local = (shifted - cycle * cycleLength) * speedScale;
    float seed = cycle * 7.13 + slot * 13.37;
    hueSeed = hash13(vec3(seed, 4.4, 1.9));

    if (local > 1.1 || hash13(vec3(seed, 3.1, 8.7)) < 0.30) {
        return 0.0;
    }

    vec3 start = normalize(vec3(
        hash13(vec3(seed, 1.3, 5.9)) * 2.0 - 1.0,
        0.35 + hash13(vec3(seed, 9.2, 2.4)) * 0.55,
        hash13(vec3(seed, 6.6, 4.8)) * 2.0 - 1.0
    ));
    vec3 side = normalize(cross(start, vec3(0.0, 1.0, 0.0)));
    float turn = hash13(vec3(seed, 2.2, 7.7)) * 2.0 - 1.0;
    vec3 heading = normalize(side + vec3(0.0, -0.55 - 0.35 * turn, 0.0));
    heading = normalize(heading - start * dot(heading, start));

    float travel = local * 0.55;
    vec3 head = normalize(start + heading * travel);
    vec3 offset = worldDir - head;
    float along = dot(offset, heading);
    float across = length(offset - heading * along);

    float trailLength = 0.34 * lengthScale;
    float behind = smoothstep(-trailLength, 0.0, along);
    float trail = pow(behind, 1.8) * step(along, 0.004);
    float taper = max(mix(0.00035, 0.0015, behind), pixelAngle * 0.7);
    float core = 1.0 - smoothstep(0.0, taper, across);
    float halo = (1.0 - smoothstep(0.0, taper * 5.0, across)) * 0.18;
    float fade = smoothstep(0.0, 0.12, local) * (1.0 - smoothstep(0.75, 1.1, local));

    float headDist = length(offset);
    float flicker = 0.85 + 0.15 * sin(time * 40.0 + seed * 5.0);
    float headGlow = (exp(-headDist * 600.0) * 1.4 + exp(-headDist * 150.0) * 0.18) * flicker;

    return (trail * (core * 1.15 + halo) + headGlow) * fade;
}

vec3 auroraCurtains(vec3 worldDir, float time, float reveal) {
    if (reveal < 0.003) {
        return vec3(0.0);
    }

    time *= AURORA_SPEED;
    float height = worldDir.y;
    float reach = mix(0.40, 1.0, reveal);

    if (height < 0.03 || height > AURORA_HEIGHT_MAX * reach) {
        return vec3(0.0);
    }

    float azimuth = atan(worldDir.z, worldDir.x);
    float wrapped = azimuth - (3.9 + float(AURORA_DIRECTION) * 0.7853981633974483);
    wrapped = wrapped - 6.283185307179586 * floor((wrapped + 3.141592653589793) / 6.283185307179586);
    float azOuter = AURORA_AZ_OUTER * mix(0.32, 1.0, reveal);
    float azInner = AURORA_AZ_INNER * mix(0.10, 1.0, reveal);
    float azimuthMask = 1.0 - smoothstep(azInner, azOuter, abs(wrapped));

    if (azimuthMask < 0.005) {
        return vec3(0.0);
    }

    float t = time * 0.06;
    float thickness = AURORA_THICKNESS * mix(0.55, 1.0, reveal);
    vec3 accum = vec3(0.0);

    for (int i = 0; i < AURORA_LAYERS; i++) {
        float layer = float(i);

        float sway = noise1(wrapped * 1.5 + layer * 3.1 + t * 1.1, 1.7 + layer);
        float baseLine = 0.13 + layer * 0.085 + (sway - 0.5) * 0.22 + AURORA_HEIGHT_OFFSET +
            AURORA_SHIMMER * (0.03 * sin(wrapped * 3.0 + time * 0.25 + layer * 2.0) + 0.018 * sin(wrapped * 7.5 - time * 0.4 + layer));
        baseLine -= (1.0 - reveal) * 0.07;
        float above = height - baseLine;

        if (above < -0.07) {
            continue;
        }

        float lowerEdge = smoothstep(-0.012, 0.030, above);
        float fadeUp = exp(-max(above, 0.0) * min(5.5 + layer * 1.5, 8.5) / thickness);
        float rim = exp(-abs(above) * 70.0) * 0.55;

        float rays = noise1(wrapped * 60.0 + layer * 7.7 + t * 3.0, 5.3 + layer) * 0.5 +
            noise1(wrapped * 17.0 + layer * 3.3 - t * 1.4, 8.1 + layer) * 0.5;
        rays = mix(1.0, 0.35 + 0.65 * smoothstep(0.22, 0.78, rays), clamp(AURORA_RAYS, 0.0, 1.5));

        float patches = smoothstep(0.30, 0.68, noise1(wrapped * 1.4 + layer * 2.3 + t * 0.7, 9.1));
        float pulse = 0.80 + 0.20 * sin(wrapped * 2.3 - time * 0.22 + layer * 1.9);

        float shape = (lowerEdge * fadeUp * rays + rim * lowerEdge * rays * 0.6) *
            max(mix(1.0, 0.35 + 0.65 * patches, AURORA_PATCHINESS), 0.0) * pulse;
        float heightMix = clamp(above * 4.2 * AURORA_GRADIENT, 0.0, 1.0);
        vec3 color = mix(mix(AURORA_LOW_COLOR, AURORA_MID_COLOR, smoothstep(0.0, 0.5, heightMix)), AURORA_HIGH_COLOR, smoothstep(0.35, 1.0, heightMix));

        accum += color * shape * max(0.62 - layer * 0.12, 0.30);
    }

    return accum * (azimuthMask * 1.15 * reveal * reveal * (3.0 - 2.0 * reveal));
}

#if !defined THE_END && GLEAM_MOON_DISK == 1
vec3 moonDiskLayer(vec3 nfragpos, vec3 moonDir, vec3 upVector, float cosMoon, float moonAltitude, float skyElevation, float rainAmount) {
    float moonRadius = radians(STYLE_MOON_RADIUS * MOON_SIZE);
    vec3 result = vec3(0.0);

    if (cosMoon > cos(moonRadius * 1.2)) {
        vec3 moonU = normalize(cross(moonDir, upVector));
        vec3 moonV = cross(moonU, moonDir);
        vec3 moonOffset = nfragpos - moonDir * cosMoon;
        vec2 moonUV = vec2(dot(moonOffset, moonU), dot(moonOffset, moonV)) / sin(moonRadius);
        float moonR2 = dot(moonUV, moonUV);

        if (moonR2 < 1.2) {
            float moonRadial = sqrt(moonR2);
            vec3 moonNormal = vec3(moonUV, sqrt(max(1.0 - moonR2, 0.0)));
            float phaseStep = float(MOON_PHASE_USED <= 4 ? MOON_PHASE_USED : 8 - MOON_PHASE_USED);
            float phaseAngle = phaseStep * 0.7853981633974483;
            float phaseSide = MOON_PHASE_USED < 4 ? -1.0 : 1.0;
            vec3 moonLight = vec3(phaseSide * sin(phaseAngle), 0.0, cos(phaseAngle));
            float ndl = dot(moonNormal, moonLight);
            float moonLit = smoothstep(-0.03, 0.26, ndl);
            float moonShade = mix(0.50, 1.0, pow(clamp(ndl, 0.0, 1.0), 0.45));

            float maria = valueNoise2(moonUV * 2.6 + 1.7) * 0.6 + valueNoise2(moonUV * 6.5 + 4.1) * 0.4;
            float moonAlbedo = mix(0.40, 1.0, smoothstep(0.36, 0.60, maria));

            vec2 craterP = moonUV * 6.0;
            vec2 craterCell = floor(craterP);
            float craterShade = 1.0;
            for (int cy = -1; cy <= 1; cy++) {
                for (int cx = -1; cx <= 1; cx++) {
                    vec2 cc = craterCell + vec2(float(cx), float(cy));
                    vec2 cp = cc + vec2(hash12(cc * 1.7 + 3.1), hash12(cc * 2.3 + 8.7)) * 0.7 + 0.15;
                    float cr = 0.10 + 0.22 * hash12(cc + 17.0);
                    float cd = length(craterP - cp);
                    float present = step(0.45, hash12(cc * 3.3 + 1.1));
                    float floorDark = smoothstep(cr, cr * 0.35, cd) * 0.22;
                    float rim = (1.0 - smoothstep(0.0, cr * 0.28, abs(cd - cr))) * 0.16;
                    craterShade -= (floorDark - rim) * present;
                }
            }

            float moonLimb = 1.0 - smoothstep(0.94, 1.0, moonRadial);
            float limbDark = mix(0.80, 1.0, (1.0 - smoothstep(0.45, 1.0, moonRadial)));
            float moonDiskVisibility = smoothstep(-0.05, 0.03, moonAltitude) * smoothstep(-0.02, 0.02, skyElevation) *
                mix(0.25, 1.0, skyNightAmount()) * (1.0 - rainAmount * 0.9);

            float surface = moonAlbedo * craterShade * limbDark;
            result += MOON_DISK_COLOR * ((surface * moonShade * moonLit * 2.5 + 0.030) * moonLimb * moonDiskVisibility);
            result += vec3(0.30, 0.44, 0.92) * (surface * (1.0 - moonLit) * 0.050 * moonLimb * moonDiskVisibility);
        }
    }

    return result;
}
#endif

vec3 sunHaloLayer(float sunAngle, vec3 worldDir, float time) {
    float innerCenter = 0.3840;
    float outerCenter = 0.8029;

    float nearInner = abs(sunAngle - innerCenter);
    float nearOuter = abs(sunAngle - outerCenter);

    if (nearInner > 0.30 && nearOuter > 0.30) {
        return vec3(0.0);
    }

    float innerEdge = smoothstep(innerCenter - 0.010, innerCenter + 0.006, sunAngle);
    float innerFall = exp(-max(sunAngle - innerCenter, 0.0) / 0.046);
    float innerProfile = innerEdge * innerFall;

    float outerEdge = smoothstep(outerCenter - 0.022, outerCenter + 0.012, sunAngle);
    float outerFall = exp(-max(sunAngle - outerCenter, 0.0) / 0.075);
    float outerProfile = outerEdge * outerFall * 0.20;

    float spread = clamp((sunAngle - innerCenter) / 0.10, 0.0, 1.0);
    vec3 innerTint = mix(vec3(1.0, 0.52, 0.32), vec3(0.64, 0.80, 1.0), smoothstep(0.0, 1.0, spread));
    innerTint = mix(vec3(1.0), innerTint, 0.50);

    float outerSpread = clamp((sunAngle - outerCenter) / 0.14, 0.0, 1.0);
    vec3 outerTint = mix(vec3(0.95, 0.72, 0.85), vec3(0.62, 0.82, 1.0), outerSpread);

    float ice = valueNoise3(worldDir * 6.5 + vec3(time * 0.004, 0.0, 0.0)) * 0.62 +
        valueNoise3(worldDir * 15.0 - vec3(0.0, time * 0.006, 0.0)) * 0.38;
    float patchy = 0.35 + 0.65 * smoothstep(0.28, 0.72, ice);

    return (innerTint * innerProfile + outerTint * outerProfile) * patchy;
}

vec3 rainbowHue(float t) {
    float hue = mix(0.76, 0.0, clamp(t, 0.0, 1.0));
    vec3 k = clamp(abs(mod(hue * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return k * k * (3.0 - 2.0 * k);
}

vec4 rainbowArc(vec3 viewDir, vec3 antiSolar) {
    float angle = acos(clamp(dot(viewDir, antiSolar), -1.0, 1.0));
    float t1 = (angle - 0.690) / 0.060;
    float band1 = smoothstep(0.0, 0.20, t1) * (1.0 - smoothstep(0.80, 1.0, t1));
    float t2 = (angle - 0.855) / 0.080;
    float band2 = smoothstep(0.0, 0.20, t2) * (1.0 - smoothstep(0.80, 1.0, t2)) * 0.30;
    float weight = band1 + band2;
    vec3 color = (rainbowHue(t1) * band1 + rainbowHue(1.0 - t2) * band2) / max(weight, 0.0001);
    return vec4(color, clamp(weight, 0.0, 1.0));
}

// Shared procedural star system used by the Overworld night sky and custom
// dimension skies, so cluster density, hero stars and constellations match.
vec3 customStarsLayer(vec3 worldDir, float pixelAngle, float time, float densityScale) {
    vec3 layer = vec3(0.0);

    #if GLEAM_STARS == 1 || GLEAM_NIGHT_LOOK == 2
        float cluster = starCluster(worldDir);
        float clusterDensity = mix(0.40, 1.65, cluster) * STAR_DENSITY * densityScale;
    #endif

    #if GLEAM_STARS == 1
        #if GLEAM_COLOR_STYLE == 0
            layer += starField(worldDir, pixelAngle, time, 0.10 * clusterDensity, 0.0, 105.0) * STAR_BRIGHTNESS;
        #else
            #if GLEAM_NIGHT_LOOK == 2
                layer += starField(worldDir, pixelAngle, time, 0.30 * clusterDensity,
                    min(0.40 * STAR_TWINKLE, 1.0), 105.0) * (STAR_BRIGHTNESS * 1.35);
                #if GLEAM_QUALITY >= 2
                    layer += starField(worldDir, pixelAngle, time, 0.55 * clusterDensity,
                        min(0.55 * STAR_TWINKLE, 1.0), 210.0) * (STAR_BRIGHTNESS * 0.42);
                #endif
            #else
                layer += starField(worldDir, pixelAngle, time, 0.18 * clusterDensity,
                    min(0.35 * STAR_TWINKLE, 1.0), 105.0) * STAR_BRIGHTNESS;
            #endif
        #endif

        #if GLEAM_COLOR_STYLE != 0
            if (HERO_STARS > 0.001) {
                layer += heroStars(worldDir, pixelAngle, time, HERO_STARS, HERO_STAR_SIZE, STAR_SPARKLE) *
                    (STAR_BRIGHTNESS * 1.15);
            }
            if (CONSTELLATIONS > 0.001) {
                layer += constellations(worldDir, pixelAngle, time) * (CONSTELLATIONS * STAR_BRIGHTNESS);
            }
        #endif
    #endif

    return layer;
}

vec3 nightSkyLayer(vec3 worldDir, float pixelAngle, float time, float auroraReveal) {
    vec3 layer = vec3(0.0);

    #if GLEAM_STARS == 1 || GLEAM_NIGHT_LOOK == 2
        float cluster = starCluster(worldDir);
        float clusterDensity = mix(0.40, 1.65, cluster) * STAR_DENSITY;
    #endif

    #if GLEAM_NIGHT_LOOK == 2
        layer += starDust(worldDir, cluster) * (0.09 * NEBULA_STRENGTH);
        #if GLEAM_QUALITY >= 1
            layer += airglow(worldDir, time) * (0.115 * NIGHT_AIRGLOW);
        #endif
    #endif

    #if GLEAM_STARS == 1
        #if GLEAM_COLOR_STYLE == 0
            layer += starField(worldDir, pixelAngle, time, 0.10 * clusterDensity, 0.0, 105.0) * STAR_BRIGHTNESS;
        #else
            #if GLEAM_NIGHT_LOOK == 2
                layer += starField(worldDir, pixelAngle, time, 0.30 * clusterDensity, min(0.40 * STAR_TWINKLE, 1.0), 105.0) * (STAR_BRIGHTNESS * 1.35);
                #if GLEAM_QUALITY >= 2
                    layer += starField(worldDir, pixelAngle, time, 0.55 * clusterDensity, min(0.55 * STAR_TWINKLE, 1.0), 210.0) * (STAR_BRIGHTNESS * 0.42);
                #endif
            #else
                layer += starField(worldDir, pixelAngle, time, 0.18 * clusterDensity, min(0.35 * STAR_TWINKLE, 1.0), 105.0) * STAR_BRIGHTNESS;
            #endif
        #endif
    #endif

    #if GLEAM_COLOR_STYLE != 0 && GLEAM_STARS == 1
        if (HERO_STARS > 0.001) {
            layer += heroStars(worldDir, pixelAngle, time, HERO_STARS, HERO_STAR_SIZE, STAR_SPARKLE) * (STAR_BRIGHTNESS * 1.15);
        }

        if (CONSTELLATIONS > 0.001) {
            layer += constellations(worldDir, pixelAngle, time) * (CONSTELLATIONS * STAR_BRIGHTNESS);
        }
    #endif

    #if GLEAM_SHOOTING == 1 || METEOR_SHOWER == 1
        for (int shootIndex = 0; shootIndex < SHOOTING_AMOUNT + FUN_METEOR_EXTRA; shootIndex++) {
            float shootHue;
            float shootTrail = shootingStarTrail(worldDir, time, 6.0 / (SHOOTING_FREQUENCY * FUN_METEOR_RATE), float(shootIndex), SHOOTING_LENGTH, SHOOTING_SPEED, pixelAngle, shootHue);
            layer += shootingStarColor(shootHue) * (shootTrail * 4.2 * SHOOTING_BRIGHTNESS);
        }
    #endif

    #if GLEAM_AURORA == 1
        layer += auroraCurtains(worldDir, time, auroraReveal) * (AURORA_INTENSITY * 0.45);
    #endif

    return layer;
}
