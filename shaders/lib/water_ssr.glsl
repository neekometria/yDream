// Small bounded view-space SSR used only for above-water reflections.
// Caller supplies opaque scene color/depth, avoiding water feedback.
#ifndef YDREAM_WATER_SSR_INCLUDED
#define YDREAM_WATER_SSR_INCLUDED


vec3 ydr_water_reconstruct_view(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * clip;
    return viewPos.xyz / max(abs(viewPos.w), 1e-6) * sign(viewPos.w);
}

vec2 ydr_water_project_view(vec3 viewPos) {
    vec4 clip = gbufferProjection * vec4(viewPos, 1.0);
    return clip.xy / max(abs(clip.w), 1e-6) * sign(clip.w) * 0.5 + 0.5;
}

// z de cena (view space, negativo) no UV: opaco do vanilla ou, quando ali so
// tem ceu, o LOD do DH. Sem o DH o raymarch da agua do LOD nunca acha alvo,
// porque depthtex1 e ceu em toda a faixa do LOD. -1e8 = nenhuma geometria.
float ydr_water_ssr_scene_z(vec2 uv) {
    float d = texture2D(depthtex1, uv).r;
    // O opaco do vanilla esta sempre a frente do LOD (o LOD so preenche onde
    // nao existe chunk), entao so consulta o DH quando o pixel e ceu no vanilla.
    if (d < 0.999999) return ydr_water_reconstruct_view(uv, d).z;

    #ifdef DISTANT_HORIZONS
        float dd = texture2D(dhDepthTex1, uv).r;
        if (dd < 0.999999) {
            return -2.0 * dhNearPlane * dhFarPlane /
                (dhFarPlane + dhNearPlane - (2.0 * dd - 1.0) * (dhFarPlane - dhNearPlane));
        }
    #endif

    return -1e8;
}

vec4 ydr_water_ssr(vec2 uv, vec3 viewPos, vec3 viewNormal, vec3 skyFallback) {
    vec3 rayDir = normalize(reflect(normalize(viewPos), normalize(viewNormal)));
    if (rayDir.z >= -0.025) return vec4(skyFallback, 0.0);

    float rayLength = clamp(abs(viewPos.z) * 0.42, 2.0, 42.0);
    float stride = rayLength / float(YDREAM_WATER_SSR_STEPS);
    float hit = 0.0;
    vec2 hitUV = uv;
    float prevT = 0.0;

    for (int i = 0; i < YDREAM_WATER_SSR_STEPS; ++i) {
        float t = (float(i) + 0.75) * stride;
        vec3 samplePos = viewPos + rayDir * t;
        vec2 sampleUV = ydr_water_project_view(samplePos);
        if (sampleUV.x < 0.002 || sampleUV.x > 0.998 || sampleUV.y < 0.002 || sampleUV.y > 0.998) break;

        float sceneZ = ydr_water_ssr_scene_z(sampleUV);
        if (sceneZ > -1e7) {
            float delta = samplePos.z - sceneZ;
            float thickness = max(0.12, abs(samplePos.z) * 0.012);
            if (delta < 0.0 && abs(delta) <= thickness && t > 0.8) {
                hit = 1.0 - smoothstep(thickness * 0.45, thickness, abs(delta));
                hitUV = sampleUV;

                // Refino binário entre o passo anterior (sem hit) e este. Sem
                // isso o ponto de impacto fica preso à grade de passos e o
                // reflexo muda de forma/cor em degraus quando a câmera move.
                float lo = prevT;
                float hi = t;
                for (int j = 0; j < 4; ++j) {
                    float mid = (lo + hi) * 0.5;
                    vec3 midPos = viewPos + rayDir * mid;
                    vec2 midUV = ydr_water_project_view(midPos);
                    float midZ = ydr_water_ssr_scene_z(midUV);
                    if (midZ <= -1e7) {
                        lo = mid;
                        continue;
                    }
                    float midDelta = midPos.z - midZ;
                    if (midDelta < 0.0) {
                        hi = mid;
                        hitUV = midUV;
                    } else {
                        lo = mid;
                    }
                }
                break;
            }
        }
        prevT = t;
    }

    if (hit < 0.001) return vec4(skyFallback, 0.0);
    vec3 sceneColor = texture2D(gaux1, hitUV).rgb;
    return vec4(sceneColor, hit);
}

#endif
