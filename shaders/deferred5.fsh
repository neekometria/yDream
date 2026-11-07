#version 120
#extension GL_ARB_shader_texture_lod : enable

#include "/lib/config.glsl"

uniform sampler2D colortex1;      // cena colorida (frame atual)
uniform sampler2D colortex10;     // dados do reflexo (dir, fresnel) escritos pelo gbuffers_water
uniform sampler2D depthtex0;      // opaco apenas  → alvo do raymarch
uniform sampler2D depthtex1;      // opaco + água  → superfície inicial

#ifdef DISTANT_HORIZONS
    uniform sampler2D dhDepthTex1;
    uniform float dhNearPlane;
    uniform float dhFarPlane;
#endif

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

varying vec2 texcoord;

// Limpa colortex15 uma vez por frame; o pass reescreve tudo o que importa
const bool colortex15Clear = true;

// Profundidade OPACA (o que o raio de reflexo deve acertar)
float scene_depth_opaque(vec2 uv) {
    float d = texture2D(depthtex0, uv).r;
    #ifdef DISTANT_HORIZONS
        float dd = texture2D(dhDepthTex1, uv).r;
        if (dd < d) return dd;
    #endif
    return d;
}

vec3 raymarch(vec3 dir, vec3 origin, float dither, inout float hit) {
    vec3 pos = origin;
    float lastDiff = 1.0;
    bool search = false;
    int steps = REFLECT_STEPS;

    for (int i = 0; i < 96; i++) {
        if (i >= steps) break;

        if (!search) {
            float t = exp2(float(i) * 0.35 + dither * 2.0) - 1.0;
            pos += dir * (0.25 + t * 0.5);
        } else {
            pos += dir * 0.5 * sign(lastDiff);
        }

        if (pos.x != pos.x || pos.y != pos.y || pos.z != pos.z) break;

        vec4 clip = gbufferProjection * vec4(pos, 1.0);
        if (clip.w <= 0.0) {
            hit = 1.0;
            return texture2D(colortex1, clamp(texcoord, 0.001, 0.999)).rgb;
        }
        vec3 sp = clip.xyz / clip.w;
        vec2 uv = sp.xy * 0.5 + 0.5;

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            hit = 1.0;
            vec2 cuv = clamp(uv, 0.001, 0.999);
            return texture2D(colortex1, cuv).rgb;
        }

        float sceneD = scene_depth_opaque(uv);
        float diff = sceneD - sp.z;

        if (diff < 0.0 && !search) search = true;

        if (search && abs(diff) < 0.001) {
            hit = 1.0;
            return texture2D(colortex1, uv).rgb;
        }

        lastDiff = diff;
    }

    hit = 0.0;
    vec2 skyUV = clamp(vec2(texcoord.x, 0.99), vec2(0.001), vec2(0.999));
    return texture2D(colortex1, skyUV).rgb;
}

void main() {
    /* RENDERTARGETS: 15 */

    vec4 waterData = texture2D(colortex10, texcoord);
    float fresnel = waterData.a;

    if (fresnel < 0.001) {
        gl_FragData[0] = vec4(0.0);
        return;
    }

    vec3 reflectDir = waterData.rgb * 2.0 - 1.0;
    if (reflectDir.x != reflectDir.x || reflectDir.y != reflectDir.y || reflectDir.z != reflectDir.z) {
        gl_FragData[0] = vec4(0.0);
        return;
    }

    // depthtex1 contém a superfície da água (opaco + translúcido)
    float surfaceDepth = texture2D(depthtex1, texcoord).r;
    if (surfaceDepth >= 0.99999) {
        gl_FragData[0] = vec4(0.0);
        return;
    }

    vec4 viewPos = gbufferProjectionInverse * vec4(texcoord * 2.0 - 1.0, surfaceDepth * 2.0 - 1.0, 1.0);
    if (viewPos.w == 0.0 || viewPos.w != viewPos.w) {
        gl_FragData[0] = vec4(0.0);
        return;
    }
    viewPos.xyz /= viewPos.w;

    if (viewPos.x != viewPos.x) {
        gl_FragData[0] = vec4(0.0);
        return;
    }

    float dither = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
    float hit = 1.0;
    vec3 reflectColor = raymarch(reflectDir, viewPos.xyz, dither, hit);

    if (reflectColor.x != reflectColor.x || reflectColor.y != reflectColor.y || reflectColor.z != reflectColor.z) {
        reflectColor = vec3(0.0);
    }
    reflectColor = clamp(reflectColor, vec3(0.0), vec3(50.0));

    gl_FragData[0] = vec4(reflectColor, fresnel);
}