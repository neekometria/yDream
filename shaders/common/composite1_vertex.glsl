#include "/lib/config.glsl"

varying vec2 texcoord;

#if GLEAM_LENS_FLARE == 1 && !defined THE_END && !defined NETHER && !defined UNKNOWN_DIM
    uniform mat4 gbufferProjection;
    uniform mat4 gbufferModelView;
    uniform vec3 sunPosition;
    uniform float rainStrength;
    uniform sampler2D depthtex0;

    varying vec2 flareSunUV;
    varying float flareVisibility;
#endif

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = gl_MultiTexCoord0.xy;

    #if GLEAM_LENS_FLARE == 1 && !defined THE_END && !defined NETHER && !defined UNKNOWN_DIM
        vec3 sunView = normalize(sunPosition);
        vec4 sunClip = gbufferProjection * vec4(sunView, 0.0);
        float sunFront = step(0.001, sunClip.w);
        flareSunUV = sunClip.xy / max(sunClip.w, 0.001) * 0.5 + 0.5;

        float sunUp = smoothstep(-0.02, 0.10, dot(sunView, normalize(gbufferModelView[1].xyz)));
        vec2 tapCenter = clamp(flareSunUV, vec2(0.02), vec2(0.98));

        float skyTaps = step(0.9999, texture2DLod(depthtex0, tapCenter, 0.0).r);
        skyTaps += step(0.9999, texture2DLod(depthtex0, tapCenter + vec2(0.012, 0.0), 0.0).r);
        skyTaps += step(0.9999, texture2DLod(depthtex0, tapCenter - vec2(0.012, 0.0), 0.0).r);
        skyTaps += step(0.9999, texture2DLod(depthtex0, tapCenter + vec2(0.0, 0.012), 0.0).r);
        skyTaps += step(0.9999, texture2DLod(depthtex0, tapCenter - vec2(0.0, 0.012), 0.0).r);

        float screenEdge = smoothstep(-0.30, 0.04, min(min(flareSunUV.x, 1.0 - flareSunUV.x), min(flareSunUV.y, 1.0 - flareSunUV.y)));
        flareVisibility = sunFront * sunUp * (skyTaps * 0.2) * screenEdge * (1.0 - rainStrength);
    #endif
}
