// Temporal anti-aliasing resolve used by composite2.
//
// The history buffer (colortex3) stores the resolved frame in RGB, tone-mapped
// with Reinhard, and the pixel age in A divided by TAA_MAX_AGE. Keeping the
// history in tone-mapped space and the age normalised makes the pass independent
// of the buffer precision, and no depth is stored in the history anymore.
//
// Per pixel:
//   - the history is sampled with a 9-tap Catmull-Rom filter;
//   - the 3x3 neighbourhood of the current frame, converted to YCoCg, bounds the
//     history with a variance-based AABB, so stale colour is rejected;
//   - the blend weight depends on the view distance and on how many frames the
//     pixel has accumulated, and an off-centre term reduces blur in motion.

#define TAA_MAX_AGE 64.0

vec3 taa_reinhard(vec3 c) {
    return c / (c + 1.0);
}

vec3 taa_reinhard_inverse(vec3 c) {
    return c / max(1.0 - min(c, vec3(0.999)), vec3(0.001));
}

vec3 taa_rgb_to_ycocg(vec3 c) {
    return vec3(
         0.25 * c.r + 0.5 * c.g + 0.25 * c.b,
         0.5 * c.r - 0.5 * c.b,
        -0.25 * c.r + 0.5 * c.g - 0.25 * c.b
    );
}

vec3 taa_ycocg_to_rgb(vec3 c) {
    return vec3(
        c.x + c.y - c.z,
        c.x + c.z,
        c.x - c.y - c.z
    );
}

float taa_linear_step(float a, float b, float x) {
    return clamp((x - a) / (b - a), 0.0, 1.0);
}

// Current frame colour in the tone-mapped YCoCg space used for the neighbourhood.
vec3 taa_fetch_ycocg(vec2 uv) {
    vec3 c = max(texture2DLod(colortex1, uv, 0.0).rgb, vec3(0.0));
    return taa_rgb_to_ycocg(taa_reinhard(c));
}

// Clamp das amostras do Catmull-Rom para dentro da tela. Sem isso,
// o bilinear dos 9 taps na borda puxa histórico repetido ou inválido e pode
// criar manchas/smear em bordas de tela.
vec3 taa_sample_clamped(sampler2D tex, vec2 pos, vec2 res) {
    return texture2DLod(tex, clamp(pos, vec2(0.5) / res, vec2(1.0) - vec2(0.5) / res), 0.0).rgb;
}

// 9-tap Catmull-Rom filter built from bilinear taps. Sharper than bilinear, so
// the accumulated history does not blur more and more over time.
vec3 taa_catmull_rom(sampler2D tex, vec2 uv, vec2 res) {
    // Garante que texPos0/texPos3 (1 tap para fora do texel mais próximo)
    // ficam dentro da tela, para que a borda não puxe dados de fora.
    uv = clamp(uv, vec2(2.0) / res, vec2(1.0) - vec2(2.0) / res);

    vec2 samplePos = uv * res;
    vec2 texPos1 = floor(samplePos - 0.5) + 0.5;
    vec2 f = samplePos - texPos1;

    vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
    vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
    vec2 w3 = f * f * (-0.5 + 0.5 * f);

    vec2 w12 = w1 + w2;
    vec2 offset12 = w2 / w12;

    vec2 texPos0 = (texPos1 - 1.0) / res;
    vec2 texPos3 = (texPos1 + 2.0) / res;
    vec2 texPos12 = (texPos1 + offset12) / res;

    vec3 result = vec3(0.0);
    result += taa_sample_clamped(tex, vec2(texPos0.x, texPos0.y), res) * (w0.x * w0.y);
    result += taa_sample_clamped(tex, vec2(texPos12.x, texPos0.y), res) * (w12.x * w0.y);
    result += taa_sample_clamped(tex, vec2(texPos3.x, texPos0.y), res) * (w3.x * w0.y);
    result += taa_sample_clamped(tex, vec2(texPos0.x, texPos12.y), res) * (w0.x * w12.y);
    result += taa_sample_clamped(tex, vec2(texPos12.x, texPos12.y), res) * (w12.x * w12.y);
    result += taa_sample_clamped(tex, vec2(texPos3.x, texPos12.y), res) * (w3.x * w12.y);
    result += taa_sample_clamped(tex, vec2(texPos0.x, texPos3.y), res) * (w0.x * w3.y);
    result += taa_sample_clamped(tex, vec2(texPos12.x, texPos3.y), res) * (w12.x * w3.y);
    result += taa_sample_clamped(tex, vec2(texPos3.x, texPos3.y), res) * (w3.x * w3.y);
    return result;
}

// AABB clipping towards the centre of the box, in YCoCg space. Clips the history
// along the line to the centre instead of hard-clamping each channel, which keeps
// the hue of the history intact.
vec3 taa_clip_aabb(vec3 history, vec3 minColor, vec3 maxColor) {
    vec3 pClip = 0.5 * (maxColor + minColor);
    vec3 eClip = max(0.5 * (maxColor - minColor), vec3(1e-3));
    vec3 vClip = history - pClip;
    vec3 aUnit = abs(vClip / eClip);
    float maxUnit = max(aUnit.x, max(aUnit.y, aUnit.z));
    return maxUnit > 1.0 ? pClip + vClip / maxUnit : history;
}

// Resolves one frame.
//   currentLinear  this frame's scene colour (linear, already jitter-free in value)
//   texcoordUv     pixel centre of this frame
//   previousUV     position of this pixel in the previous frame, in UNJITTERED
//                  screen space (the history is jitter-free, so reprojection must
//                  use unjittered positions for both frames, not the previous jitter)
//   previousValid  false when the reprojection leaves the screen or history is not ready
//   historyAge     number of frames accumulated by the history pixel
//   viewDistance   view distance of the closest sample, used for the blend weight
void taa_resolve(
    vec3 currentLinear,
    vec2 texcoordUv,
    vec2 previousUV,
    bool previousValid,
    float historyAge,
    float viewDistance,
    out vec3 outLinear,
    out vec3 outHistory,
    out float outAge
) {
    vec2 ps = vec2(pixelSizeX, pixelSizeY);
    vec2 res = vec2(1.0 / pixelSizeX, 1.0 / pixelSizeY);

    vec3 currentReinhard = taa_reinhard(max(currentLinear, vec3(0.0)));
    vec3 centre = taa_rgb_to_ycocg(currentReinhard);

    vec3 north = taa_fetch_ycocg(texcoordUv + vec2(0.0, ps.y));
    vec3 south = taa_fetch_ycocg(texcoordUv - vec2(0.0, ps.y));
    vec3 west = taa_fetch_ycocg(texcoordUv - vec2(ps.x, 0.0));
    vec3 east = taa_fetch_ycocg(texcoordUv + vec2(ps.x, 0.0));

    vec3 minCross = min(min(min(north, south), min(west, east)), centre);
    vec3 maxCross = max(max(max(north, south), max(west, east)), centre);

    vec3 minColor = minCross;
    vec3 maxColor = maxCross;
    vec3 sum = centre + north + south + west + east;
    vec3 sumSq = centre * centre + north * north + south * south + west * west + east * east;
    float invCount = 0.2;

#if ATAA_QUALITY != 0
    vec3 northWest = taa_fetch_ycocg(texcoordUv + vec2(-ps.x, ps.y));
    vec3 northEast = taa_fetch_ycocg(texcoordUv + vec2(ps.x, ps.y));
    vec3 southWest = taa_fetch_ycocg(texcoordUv + vec2(-ps.x, -ps.y));
    vec3 southEast = taa_fetch_ycocg(texcoordUv + vec2(ps.x, -ps.y));

    // Soft minimum and maximum: average of the cross and the full 3x3 bounds.
    vec3 minCorner = min(min(northWest, northEast), min(southWest, southEast));
    vec3 maxCorner = max(max(northWest, northEast), max(southWest, southEast));
    minColor = 0.5 * (minCross + min(minCross, minCorner));
    maxColor = 0.5 * (maxCross + max(maxCross, maxCorner));

    sum += northWest + northEast + southWest + southEast;
    sumSq += northWest * northWest + northEast * northEast
           + southWest * southWest + southEast * southEast;
    invCount = 1.0 / 9.0;
#endif

    float distanceFactor = 1.0 - exp2(-0.025 * viewDistance);

    // Variance clipping: tighten the box to the local mean and spread.
    vec3 mu = sum * invCount;
    vec3 sigma = sqrt(max(sumSq * invCount - mu * mu, vec3(0.0)));

    // gamma mais apertado (era mix(1.0, 1.25, ...)). Com 1.25 o AABB
    // cabia cores que já deveriam ser rejeitadas, causando ghosting residual
    // em objetos que se movem. 0.85 perto / 1.10 longe mantém a resposta rápida
    // onde o usuário percebe mais detalhe e um pouco mais de estabilidade longe.
    float gamma = mix(0.85, 1.10, taa_linear_step(0.25, 1.0, distanceFactor));

    minColor = max(minColor, mu - gamma * sigma);
    maxColor = min(maxColor, mu + gamma * sigma);
    minColor = min(minColor, maxColor);

    vec3 resolved = currentReinhard;
    float pixelAge = 1.0;

    if (previousValid) {
        vec3 history = taa_catmull_rom(colortex3, previousUV, res);

        // Defensive: cor não pode ser negativa/NaN. Se for, esquece o
        // histórico e fica com o frame atual (evita mancha preta/roxa).
        if (any(lessThan(history, vec3(0.0))) || any(isnan(history))) {
            history = currentReinhard;
        }

        vec3 historyY = taa_clip_aabb(
            taa_rgb_to_ycocg(history), minColor, maxColor);
        vec3 historyRgb = max(taa_ycocg_to_rgb(historyY), vec3(0.0));

        // Every frame in the history counts the same, so the average converges
        // fast; distant surfaces get a longer history than close ones.
        pixelAge = historyAge + 1.0;

        // Piso de alpha mais alto (era mix(0.10, 0.05, ...)). Com piso
        // muito baixo o TAA_MAX_AGE deixa de ser o fator limitante (alpha
        // fica preso em ~0.05/0.10), e a resposta fica lenta. mix(0.15, 0.08)
        // corresponde a ~7 frames perto e ~13 longe, mais responsivo.
        float blendWeight = mix(0.15, 0.08, distanceFactor);
        float alpha = max(1.0 / pixelAge, blendWeight);

#if AA_MODE == 5
        // SMAA T2x resolves after exactly two frames.
        alpha = 0.5;
#endif

        // Off-centre rejection: reduces blur while moving, at the cost of some
        // aliasing when the history is sampled far from a texel centre.
        // Agora que previousUV não é mais sobrescrito em composite2, motion
        // é o movimento físico real (sem jitter), então este termo finalmente
        // dispara em movimento de câmera/objeto.
        vec2 pixelOffset = 1.0 - abs(2.0 * fract(res * previousUV) - 1.0);
        float offcenter = sqrt(pixelOffset.x * pixelOffset.y) * 0.25 + 0.75;
        // Only apply it when the pixel actually moves, so sub-pixel jitter on a
        // still image does not raise alpha and let the jitter through.
        float motion = clamp(length((previousUV - texcoordUv) * res) - 0.5, 0.0, 1.0);
        offcenter = mix(1.0, offcenter, motion);
        alpha = 1.0 - (1.0 - alpha) * offcenter;
        pixelAge *= offcenter;

        resolved = mix(historyRgb, currentReinhard, alpha);
    }

    outHistory = clamp(resolved, vec3(0.0), vec3(0.999));
    outLinear = clamp(taa_reinhard_inverse(outHistory), vec3(0.0), vec3(50.0));
    outAge = min(pixelAge, TAA_MAX_AGE);
}