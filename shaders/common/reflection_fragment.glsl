#include "/lib/config.glsl"

// Fonte de cor dos hits do SSR. colortex4 (gaux1) guarda a cena OPACA sem a
// água, escrita em deferred/gi_blur. colortex1 NÃO serve: ele já contém a água
// translúcida blendada, então o reflexo acabava "se refletindo" (feedback).
uniform sampler2D colortex4;
// Buffer de céu/fog escrito por prepare (DRAWBUFFERS:167). É um céu puro em
// tela cheia, independente da geometria, ideal para o fallback sem hit.
uniform sampler2D colortex7;
// Dados da água escritos por gbuffers_water / dh_water:
// rgb = direção do reflexo * 0.5 + 0.5, a = fresnel.
uniform sampler2D WATER_REFLECT_TEX;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

#ifdef DISTANT_HORIZONS
    uniform sampler2D dhDepthTex1;
    uniform mat4 dhProjectionInverse;
#endif

varying vec2 texcoord;

// Ruído interleaved gradient: jitter por pixel para esconder o banding do passo.
float ydr_ign(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

// Profundidade (0..1) -> posição de visão. Mesma convenção de composite2_fragment.
vec3 ydr_view(mat4 projInv, vec2 uv, float depth) {
    vec4 v = projInv * vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    float w = (abs(v.w) < 1e-6) ? 1e-6 : v.w;
    return v.xyz / w;
}

// Distância de visão da superfície OPACA em uv (a água nunca entra aqui).
// 1e9 = céu ou nada. Usa o mais distante entre depthtex0/1 (a água fica sempre na frente).
float ydr_opaque_dist(vec2 uv) {
    float dist = 1e9;
    float d = max(texture2DLod(depthtex0, uv, 0.0).r, texture2DLod(depthtex1, uv, 0.0).r);
    if (d < 0.99999) dist = -ydr_view(gbufferProjectionInverse, uv, d).z;
    #ifdef DISTANT_HORIZONS
        float dh = texture2DLod(dhDepthTex1, uv, 0.0).r;
        if (dh < 0.99999) dist = min(dist, -ydr_view(dhProjectionInverse, uv, dh).z);
    #endif
    return dist;
}

// Raymarch em espaço de visão. Retorna uv do acerto; hit = 1.0 se acertou algo opaco.
vec2 ydr_trace(vec3 origin, vec3 dir, float jitter, int steps, float stride, out float hit) {
    hit = 0.0;
    vec3 prev = origin;
    vec3 pos = origin;
    vec2 uv = vec2(0.5);

    for (int i = 0; i < 96; i++) {
        if (i >= steps) break;

        // O passo cresce com a distância percorrida; o primeiro recebe jitter.
        float s = stride * (1.0 + float(i) * 0.12);
        if (i == 0) s *= 0.5 + jitter;

        prev = pos;
        pos += dir * s;

        if (pos.z > -0.05) break;                 // ponto atrás da câmera

        vec4 clip = gbufferProjection * vec4(pos, 1.0);
        if (clip.w < 1e-6) break;
        uv = clip.xy / clip.w * 0.5 + 0.5;
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) break;   // saiu da tela

        float rayDist = -pos.z;
        float diff = rayDist - ydr_opaque_dist(uv);      // > 0: raio passou atrás da superfície
        // Só aceita a interseção se a superfície estiver a menos de um passo de
        // profundidade do raio. O limite antigo (0.6 + 0.08 * rayDist) chegava a
        // ~11 blocos no fim do raio e produzia hits falsos/arrasto. Como `s` é o
        // comprimento 3D do passo, `max(s, 0.5)` cobre o avanço em Z de qualquer
        // direção sem ser frouxo à distância.
        if (diff > 0.0 && diff < max(s, 0.5)) {
            // Refinamento binário entre prev e pos.
            vec3 lo = prev;
            vec3 hi = pos;
            for (int r = 0; r < 5; r++) {
                vec3 m = (lo + hi) * 0.5;
                vec4 mc = gbufferProjection * vec4(m, 1.0);
                if (mc.w < 1e-6) break;
                vec2 muv = mc.xy / mc.w * 0.5 + 0.5;
                if (-m.z > ydr_opaque_dist(muv)) hi = m; else lo = m;
            }
            vec4 hc = gbufferProjection * vec4(hi, 1.0);
            if (hc.w > 1e-6) uv = hc.xy / hc.w * 0.5 + 0.5;
            hit = 1.0;
            return clamp(uv, vec2(0.001), vec2(0.999));
        }
    }
    return clamp(uv, vec2(0.001), vec2(0.999));
}

// Cor refletida para um pixel de água. O alpha de saída é o fresnel (0 = sem
// reflexo). Nunca retorna NaN: sem acerto usa a borda da tela na direção do
// reflexo (céu/horizonte).
vec4 ydr_water_reflection(vec2 uv, vec4 waterData) {
    float fresnel = waterData.a;
    if (fresnel < 0.001) return vec4(0.0);

    vec3 rawDir = waterData.rgb * 2.0 - 1.0;
    if (length(rawDir) < 0.5) return vec4(0.0);
    vec3 dir = normalize(rawDir);

    float dMin = min(texture2DLod(depthtex0, uv, 0.0).r, texture2DLod(depthtex1, uv, 0.0).r);
    vec3 origin;
    if (dMin < 0.99999) {
        origin = ydr_view(gbufferProjectionInverse, uv, dMin);
    } else {
        #ifdef DISTANT_HORIZONS
            float dh = texture2DLod(dhDepthTex1, uv, 0.0).r;
            if (dh >= 0.99999) return vec4(0.0);
            origin = ydr_view(dhProjectionInverse, uv, dh);
        #else
            return vec4(0.0);
        #endif
    }

    float hit;
    float jitter = ydr_ign(gl_FragCoord.xy);
    vec2 huv = ydr_trace(origin + dir * 0.02, dir, jitter, REFLECT_STEPS, REFLECT_STRIDE, hit);

    vec3 refl;
    if (hit > 0.5) {
        // Cena opaca refletida (sem água), no mesmo espaço linear pré-exposição
        // que o resto do composite/final espera.
        refl = texture2DLod(colortex4, huv, 0.0).rgb;
    } else {
        // Sem acerto: usa o buffer de céu puro na direção do reflexo.
        vec4 dc = gbufferProjection * vec4(dir, 0.0);
        vec2 skyUV = vec2(uv.x, 0.999);
        if (dc.w > 1e-4) skyUV = dc.xy / dc.w * 0.5 + 0.5;
        refl = texture2DLod(colortex7, clamp(skyUV, vec2(0.001), vec2(0.999)), 0.0).rgb;
    }

    if (!(refl.r == refl.r) || !(refl.g == refl.g) || !(refl.b == refl.b)) return vec4(0.0);
    if (dot(refl, vec3(0.333)) < 0.002) return vec4(0.0);

    return vec4(refl, fresnel);
}

void main() {
    /* RENDERTARGETS: 5 */
    #if WATER_REFLECT_BUFFER == 1
        vec4 waterData = texture2DLod(WATER_REFLECT_TEX, texcoord, 0.0);
        gl_FragData[0] = ydr_water_reflection(texcoord, waterData);
    #else
        // Sem buffer de dados (GI + luz colorida ocupam os buffers): o reflexo
        // cai no caminho rápido inline e este passe só limpa a saída.
        gl_FragData[0] = vec4(0.0);
    #endif
}
