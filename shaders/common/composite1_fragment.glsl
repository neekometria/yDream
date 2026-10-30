#include "/lib/config.glsl"

#ifdef DOF
    const bool colortex1MipmapEnabled = true;
#endif

#ifdef BLOOM
    const bool colortex0MipmapEnabled = true;
#endif

uniform sampler2D colortex1;
uniform sampler2D colortex0;
uniform float aspectRatioInverse;

#ifdef DOF
    uniform float centerDepthSmooth;
    uniform float pixelSizeX;
    uniform float pixelSizeY;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float fovYInverse;
#endif

#ifdef BLOOM
    uniform float softLod;
#endif

varying vec2 texcoord;

#if YDREAM_LENS_FLARE == 1 && !defined THE_END && !defined NETHER && !defined UNKNOWN_DIM
    varying vec2 flareSunUV;
    varying float flareVisibility;

    float flareHex(vec2 p, float radius, float angle) {
        float s = sin(angle);
        float c = cos(angle);
        vec2 q = abs(mat2(c, -s, s, c) * p);
        return max(q.x * 0.8660254 + q.y * 0.5, q.y) / radius;
    }

    float flareGhostShape(float h) {
        float body = 1.0 - smoothstep(0.35, 1.0, h);
        float rim = smoothstep(0.72, 0.96, h) * (1.0 - smoothstep(0.96, 1.05, h));

        return body * 0.30 + rim * 0.70;
    }

    vec3 flareGhost(vec2 uv, vec2 center, float radius, float angle, float aspect) {
        vec2 delta = (uv - center) * vec2(aspect, 1.0);
        float h = flareHex(delta, radius, angle);

        return vec3(flareGhostShape(h * 1.045), flareGhostShape(h), flareGhostShape(h * 0.955));
    }
#endif

#ifdef BLOOM
    #include "/lib/bloom.glsl"
#endif

#if defined BLOOM || defined DOF
    #include "/lib/dither.glsl"
#endif

#ifdef DOF
    #include "/lib/blur.glsl"
#endif

void main() {
    vec4 blockColor = texture2DLod(colortex1, texcoord, 0);

    #if defined BLOOM || defined DOF
        #if AA_TYPE > 0
            float dither = shiftedSemiblue(gl_FragCoord.xy);
        #else
            float dither = semiblue(gl_FragCoord.xy);
        #endif
    #endif

    #ifdef DOF
        blockColor.rgb = noisedBlur(blockColor, colortex1, texcoord, DOF_STRENGTH, dither);
    #endif

    #ifdef BLOOM
        vec3 bloom = mipmap_bloom(colortex0, texcoord, dither);
        bloom = mix(vec3(dot(bloom, vec3(0.2126, 0.7152, 0.0722))), bloom, BLOOM_SATURATION);
        blockColor.rgb += bloom * BLOOM_INTENSITY * YDREAM_STYLE_BLOOM_MULT * STYLE_BLOOM_TINT;
    #endif

    #if YDREAM_LENS_FLARE == 1 && !defined THE_END && !defined NETHER && !defined UNKNOWN_DIM
        if (flareVisibility > 0.002) {
            float flareAspect = 1.0 / aspectRatioInverse;
            vec2 flareAxis = vec2(0.5) - flareSunUV;
            vec2 toSun = (texcoord - flareSunUV) * vec2(flareAspect, 1.0);
            float sunDistance = length(toSun);

            vec3 flare = vec3(0.0);
            flare += flareGhost(texcoord, flareSunUV + flareAxis * 0.12, 0.020, 0.3, flareAspect) * vec3(1.00, 0.92, 0.80) * 0.14;
            flare += flareGhost(texcoord, flareSunUV + flareAxis * 0.32, 0.045, 0.0, flareAspect) * vec3(1.00, 0.85, 0.70) * 0.16;
            flare += flareGhost(texcoord, flareSunUV + flareAxis * 0.62, 0.030, 0.6, flareAspect) * vec3(0.80, 0.95, 1.00) * 0.22;
            flare += flareGhost(texcoord, flareSunUV + flareAxis * 1.15, 0.075, 0.0, flareAspect) * vec3(1.00, 0.75, 0.90) * 0.12;
            flare += flareGhost(texcoord, flareSunUV + flareAxis * 1.60, 0.040, 1.1, flareAspect) * vec3(0.85, 1.00, 0.80) * 0.18;
            flare += flareGhost(texcoord, flareSunUV + flareAxis * 2.10, 0.100, 0.5, flareAspect) * vec3(0.90, 0.85, 1.00) * 0.08;
            flare += flareGhost(texcoord, flareSunUV + flareAxis * 2.55, 0.022, 0.9, flareAspect) * vec3(1.00, 0.80, 0.65) * 0.10;
            flare += flareGhost(texcoord, flareSunUV + flareAxis * 2.95, 0.055, 1.4, flareAspect) * vec3(0.75, 0.90, 1.00) * 0.07;

            float ringDistance = sunDistance - 0.23;
            float haloRing = exp(-pow(ringDistance / 0.020, 2.0));
            vec3 spectral = 0.5 + 0.5 * cos(6.2831853 * (vec3(0.0, 0.33, 0.67) + ringDistance * 9.0));
            flare += mix(vec3(1.0, 0.92, 0.80), spectral, 0.45) * (haloRing * 0.20);

            float sunAngle = atan(toSun.y, toSun.x);
            float spikes = pow(abs(cos(sunAngle * 3.0 + 0.35)), 48.0) * exp(-sunDistance * 6.0);

            float streakDist = abs(texcoord.y - flareSunUV.y);
            float streakCore = exp(-streakDist * 220.0);
            float streakWide = exp(-streakDist * 40.0);
            float streakAlong = (texcoord.x - flareSunUV.x) * flareAspect;
            float streakLength = exp(-abs(streakAlong) * 1.1);
            float streakHue = clamp(abs(streakAlong) * 1.6, 0.0, 1.0);
            vec3 streakColor = mix(vec3(1.0, 0.95, 0.85), vec3(0.45, 0.70, 1.0), streakHue);
            streakColor = mix(streakColor, vec3(1.0, 0.98, 0.94), streakCore * 0.6);
            float veil = exp(-sunDistance * 2.6) * 0.10;

            flare += vec3(1.0, 0.92, 0.78) * (spikes * 0.28 + veil);
            flare += streakColor * (streakLength * (streakCore * 0.85 + streakWide * 0.18) * ANAMORPHIC_STREAK_MULT);

            blockColor.rgb += flare * (flareVisibility * LENS_FLARE_STRENGTH * STYLE_FLARE_STRENGTH * 0.55);
        }
    #endif

    blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
    /* DRAWBUFFERS:1 */
    gl_FragData[0] = blockColor;
}
