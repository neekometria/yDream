#include "/lib/config.glsl"

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

uniform sampler2D gaux3;
uniform sampler2D gaux4;
uniform float pixelSizeX;
uniform float pixelSizeY;

#if MC_VERSION < 11604
    uniform mat4 gbufferProjectionInverse;
    uniform float viewWidth;
    uniform float viewHeight;
    uniform float rainStrength;
#endif

#if MC_VERSION < 11604
    varying vec3 upVector;
    varying vec3 zenithSkyColor;
    varying vec3 horizonSkyColor;
#endif

varying vec4 star_data;

#if MC_VERSION < 11604
    #include "/lib/dither.glsl"
#endif

void main() {
    #if defined THE_END
        // The prepared End sky is the only sky. Vanilla End sky would overwrite it.
        discard;
    #endif
    #if defined THE_END
        #if MC_VERSION < 11604
            vec4 background_color = vec4(ZENITH_DAY_COLOR, 1.0);
        #endif
        vec4 blockColor = vec4(0.0, 0.0, 0.0, 1.0);
    #elif defined NETHER
        #if MC_VERSION < 11604
            vec4 background_color = vec4(netherFog(fogColor), 1.0);
        #endif
        vec4 blockColor = vec4(netherFog(fogColor), 1.0);
    #else
        #if MC_VERSION < 11604
            #if AA_TYPE > 0
                float dither = shiftedRDither(gl_FragCoord.xy);
            #else
                float dither = dither13(gl_FragCoord.xy);
            #endif

            dither = (dither - .5) * 0.03125;

            vec4 fragpos =
                gbufferProjectionInverse *
                (vec4(gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY), gl_FragCoord.z, 1.0) * 2.0 - 1.0);
            vec3 nfragpos = normalize(fragpos.xyz);
            float n_u = clamp(dot(nfragpos, upVector) + dither, 0.0, 1.0);
            vec4 background_color = vec4(mix(horizonSkyColor, zenithSkyColor, smoothstep(0.0, 1.0, pow(n_u, 0.333))), 1.0);
            background_color.rgb = xyzToRgb(background_color.rgb);
        #else

            vec4 background_color = texture2DLod(gaux4, gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY), 0);
        #endif

        vec4 blockColor = star_data;

        blockColor = mix(background_color, blockColor, blockColor);
    #endif

    #if MC_VERSION >= 11604
        vec3 skyDetail = texture2D(gaux3, gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY)).rgb;
        float starAmount = clamp(star_data.a * 2.0, 0.0, 1.0);

        #if GLEAM_STARS == 2 && !defined THE_END && !defined NETHER
            skyDetail = mix(skyDetail, vec3(1.9), starAmount);
        #endif

        blockColor.rgba = vec4(skyDetail, starAmount);
    #endif

    #include "/src/writebuffers.glsl"
}
