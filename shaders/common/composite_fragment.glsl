#include "/lib/config.glsl"
const bool colortex1MipmapEnabled = true;

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

uniform sampler2D colortex1;
uniform float far;
uniform float near;
uniform float blindness;
uniform float rainStrength;
uniform sampler2D depthtex0;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#ifdef NETHER_EMBERS_ACTIVE
    uniform sampler2D noisetex;
    uniform float frameTimeCounter;
    uniform float aspectRatioInverse;
#endif

#if (VOL_LIGHT == 1 || VOL_LIGHT == 2) && !defined NETHER
    uniform float frameTimeCounter;
#endif

#if VOL_LIGHT == 1 && !defined NETHER
    uniform sampler2D depthtex1;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float dayNightMix;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferModelView;
    uniform float volumetricDayMixer;
#endif

#if VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER
    uniform float dayNightMix;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferModelView;
    uniform float volumetricDayMixer;
    uniform vec3 shadowLightPosition;
    uniform mat4 shadowModelView;
    uniform mat4 shadowProjection;
    uniform sampler2DShadow shadowtex1;

    #if defined COLORED_GODRAYS || defined SCREENSHOT_MODE
        uniform sampler2DShadow shadowtex0;
        uniform sampler2D shadowcolor0;
    #endif
#endif

varying vec2 texcoord;
varying vec3 directLightColor;

#if VOL_LIGHT == 1 && !defined NETHER
    varying vec3 volumetricLightColor;
    varying vec2 lightpos;
    varying vec3 astroLightPos;
#endif

#if VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER
    varying vec3 volumetricLightColor;
#endif

#if (VOL_LIGHT == 1 && !defined NETHER) || (VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER)
    varying mat4 modeli_times_projectioni;
#endif

#ifdef UNDERWATER_FX
    uniform vec3 cameraPosition;
#endif

#include "/lib/basic_utils.glsl"
#include "/lib/depth.glsl"

#if (VOL_LIGHT == 1 || VOL_LIGHT == 2) && !defined NETHER
    float glimmerHash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
    }

    float glimmerNoise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        float a = glimmerHash(i);
        float b = glimmerHash(i + vec2(1.0, 0.0));
        float c = glimmerHash(i + vec2(0.0, 1.0));
        float d = glimmerHash(i + vec2(1.0, 1.0));
        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    }
#endif

#ifdef BLOOM
    #include "/lib/luma.glsl"
#endif

#if VOL_LIGHT == 1 && !defined NETHER
    #include "/lib/dither.glsl"
    #include "/lib/volumetric_light.glsl"
#endif

#if VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER
    #include "/lib/dither.glsl"
    #include "/lib/volumetric_light.glsl"
#endif

void main() {
    vec4 blockColor = texture2DLod(colortex1, texcoord, 0);
    float d = texture2DLod(depthtex0, texcoord, 0).r;
    float linearDepth = ld(d);

    vec2 eyeBrightSmoothFloat = vec2(eyeBrightnessSmooth);

    float screen_distance = linearDepth * far * 0.5;

    if(isEyeInWater == 1) {
        #ifdef UNDERWATER_FX
            float uwDistance = linearDepth * far;

            vec3 underwaterFog = underwaterFogColor(directLightColor, eyeBrightSmoothFloat.y * 0.004166666666666667);
            underwaterFog = mix(underwaterFog * vec3(0.85, 1.35, 1.20), underwaterFog, clamp((63.0 - cameraPosition.y) * 0.07, 0.0, 1.0));
            vec3 uwSigma = vec3(0.070, 0.038, 0.022) * ((UNDERWATER_FOG_DENSITY * 0.2 + WATER_ABSORPTION * 2.0) * 0.83);
            vec3 uwTrans = exp(-uwSigma * uwDistance);

            float uwDepthDark = mix(1.0, 0.6, clamp((63.0 - cameraPosition.y) * 0.025, 0.0, 1.0));
            vec3 uwFogFinal = underwaterFog * uwDepthDark;

            blockColor.rgb = blockColor.rgb * uwTrans + uwFogFinal * (vec3(1.0) - uwTrans);
        #else
            float waterAbsorption = clamp(1.0 - pow(1.001 - linearDepth, UNDERWATER_FOG_DENSITY + (4.0 * WATER_ABSORPTION)), 0.0, 1.0);
            vec3 underwaterFog = underwaterFogColor(directLightColor, eyeBrightSmoothFloat.y * 0.004166666666666667);

            blockColor.rgb *= underwaterTransmission(waterAbsorption * 0.9);
            blockColor.rgb = mix(blockColor.rgb, underwaterFog, waterAbsorption);
        #endif

    } else if(isEyeInWater == 2) {
        blockColor = mix(blockColor, vec4(1.0, .1, 0.0, 1.0), clamp(sqrt(linearDepth * far * 0.125), 0.0, 1.0));
    }

    #ifdef NETHER_EMBERS_ACTIVE
        if(isEyeInWater != 2 && d < 0.9999) {
            vec2 emberAspectUV = vec2((texcoord.x - 0.5) * aspectRatioInverse, texcoord.y - 0.5);

            vec2 emberUvA = emberAspectUV * 70.0 + vec2(0.0, -frameTimeCounter * 0.09);
            vec2 emberUvB = emberAspectUV * 95.0 + vec2(frameTimeCounter * 0.05, -frameTimeCounter * 0.14);

            float emberA = texture2D(noisetex, emberUvA).r;
            float emberB = texture2D(noisetex, emberUvB).g;

            float emberSparkA = smoothstep(0.965, 0.995, emberA);
            float emberSparkB = smoothstep(0.972, 0.998, emberB);

            float emberFade = (1.0 - smoothstep(0.30, 0.90, linearDepth)) * NETHER_EMBERS_AMOUNT;
            vec3 emberColor = mix(vec3(1.0, 0.30, 0.04), vec3(1.0, 0.68, 0.20), emberB);

            blockColor.rgb += emberColor * (emberSparkA * 1.5 + emberSparkB * 0.9) * emberFade;
        }
    #endif

    #if MC_VERSION >= 11900

        if((blindness > .01 || darknessFactor > .01) && linearDepth > 0.9) {
            blockColor.rgb = vec3(0.0);
        }
    #else
        if(blindness > .01 && linearDepth > 0.999) {
            blockColor.rgb = vec3(0.0);
        }
    #endif

    #if (VOL_LIGHT == 1 && !defined NETHER) || (VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER)
        #if AA_TYPE > 0
           float dither = shiftedDither17(gl_FragCoord.xy);
        #else
            float dither = rDither(gl_FragCoord.xy);
        #endif
    #endif

    #if VOL_LIGHT == 1 && !defined NETHER
        #if defined THE_END
            float volumetricLight = 0.1;
            if(d > 0.9999) {
                volumetricLight = 0.5;
            }
        #else
            float volumetricLight = ssGodrays(dither);
        #endif

        vec4 centerFarPlanePos = modeli_times_projectioni * (vec4(0.5, 0.5, 1.0, 1.0) * 2.0 - 1.0);
        vec3 centerEyeDirection = normalize(centerFarPlanePos.xyz);

        vec4 farPlaneClipPos = modeli_times_projectioni * (vec4(texcoord, 1.0, 1.0) * 2.0 - 1.0);
        vec3 eyeDirection = normalize(farPlaneClipPos.xyz);

        #if defined THE_END

            vec3 auxVector =
                normalize((gbufferModelViewInverse * gbufferModelView * vec4(0.0, 0.89442719, 0.4472136, 0.0)).xyz);
            float volumetricIntensity =
                clamp(dot(centerEyeDirection, auxVector), 0.0, 1.0);

            volumetricIntensity *= clamp(dot(eyeDirection, auxVector), 0.0, 1.0);

            volumetricIntensity *= 0.666;

            blockColor.rgb += (volumetricLightColor * volumetricLight * volumetricIntensity * 2.0);
        #else

            vec3 auxVector =
                normalize((gbufferModelViewInverse * vec4(astroLightPos, 0.0)).xyz);
            float volumetricIntensity =
                clamp(dot(centerEyeDirection, auxVector), 0.0, 1.0);
            volumetricIntensity *= dot(eyeDirection, auxVector);
            volumetricIntensity =
                pow(clamp(volumetricIntensity, 0.0, 1.0), volumetricDayMixer) * 0.5 * abs(dayNightMix * 2.0 - 1.0);

            float underwaterBeams = float(isEyeInWater == 1);
            vec3 beamTint = mix(vec3(1.0), normalize(WATER_COLOR + 0.0001), underwaterBeams);

            float waterGlimmer = 1.0;
            if (underwaterBeams > 0.5) {
                vec2 glimmerUvA = eyeDirection.xy * 1.4 + vec2(frameTimeCounter * 0.09, frameTimeCounter * 0.06);
                vec2 glimmerUvB = eyeDirection.xy * 2.1 - vec2(frameTimeCounter * 0.05, frameTimeCounter * 0.11);
                float glimmerA = glimmerNoise(glimmerUvA);
                float glimmerB = glimmerNoise(glimmerUvB);
                waterGlimmer = 0.82 + 0.32 * (glimmerA * 0.6 + glimmerB * 0.4);
            }

            blockColor.rgb += volumetricLightColor * beamTint * volumetricLight * volumetricIntensity * waterGlimmer *
                (GODRAY_STRENGTH * STYLE_GODRAY_MULT * mix(1.0 - rainStrength, 1.3, underwaterBeams));
        #endif
    #endif

    #if VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER
        #if defined THE_END
            bool godrayActive = isEyeInWater != 1;
        #else
            bool godrayActive = sunElevation > -0.06;
        #endif

        #if !defined THE_END
            if (isEyeInWater == 0 && (rainStrength > 0.98 || abs(dayNightMix * 2.0 - 1.0) < 0.02)) {
                godrayActive = false;
            }
        #endif

        vec3 volumetricLight = vec3(0.0);
        if (godrayActive) {
            volumetricLight = get_volumetric_scatter(dither, screen_distance, modeli_times_projectioni);
        }

        vec4 farPlaneClipPos = modeli_times_projectioni * (vec4(texcoord, 1.0, 1.0) * 2.0 - 1.0);
        vec3 eyeDirection = normalize(farPlaneClipPos.xyz);

        #if defined THE_END
            float endIntensity = dot(eyeDirection, normalize((gbufferModelViewInverse * gbufferModelView * vec4(0.0, 0.89442719, 0.4472136, 0.0)).xyz));
            endIntensity = squarePow(clamp((endIntensity + .666667) * 0.6, 0.0, 1.0)) * 0.5;
            blockColor.rgb += volumetricLightColor * volumetricLight * (endIntensity * 2.0);
        #else
            float underwaterBeams = float(isEyeInWater == 1);
            float lobeExponent = mix((2.0 + volumetricDayMixer) * GODRAY_SHARPNESS, 1.5, underwaterBeams);
            float lightCos = dot(eyeDirection, normalize((gbufferModelViewInverse * vec4(shadowLightPosition, 0.0)).xyz));
            float forwardLobe = pow(clamp(lightCos, 0.0, 1.0), lobeExponent);
            float scatterPhase = mix(mix(0.16 * GODRAY_SPREAD, 1.0, forwardLobe), mix(0.30, 1.0, forwardLobe), underwaterBeams);
            float rayDistance = linearDepth * far;

            float scatterAmount = mix(
                mix(1.0 - exp(-rayDistance * (0.0065 * GODRAY_BUILDUP)), 0.30, step(0.9999, d)),
                1.0 - exp(-rayDistance * (0.05 + UNDERWATER_FOG_DENSITY * 0.012)),
                underwaterBeams
            );
            float goldenHour = (1.0 - smoothstep(0.05, 0.45, sunElevation)) * step(0.0, sunElevation);
            vec3 beamTint = mix(vec3(1.0), normalize(WATER_COLOR + 0.0001), underwaterBeams);
            beamTint *= mix(mix(vec3(1.0, 0.97, 0.90), vec3(1.0, 0.80, 0.55), clamp(goldenHour * GODRAY_WARMTH, 0.0, 1.0)), vec3(1.0), underwaterBeams);
            float scatterStrength = GODRAY_STRENGTH * STYLE_GODRAY_MULT *
                mix(mix(0.56, 0.40, goldenHour) * (1.0 + 0.9 * goldenHour) * (1.0 - rainStrength), 1.25, underwaterBeams) *
                abs(dayNightMix * 2.0 - 1.0);

            float waterGlimmer = 1.0;
            if (underwaterBeams > 0.5) {
                vec2 glimmerUvA = eyeDirection.xy * 1.4 + vec2(frameTimeCounter * 0.09, frameTimeCounter * 0.06);
                vec2 glimmerUvB = eyeDirection.xy * 2.1 - vec2(frameTimeCounter * 0.05, frameTimeCounter * 0.11);
                float glimmerA = glimmerNoise(glimmerUvA);
                float glimmerB = glimmerNoise(glimmerUvB);
                waterGlimmer = 0.82 + 0.32 * (glimmerA * 0.6 + glimmerB * 0.4);
            }

            blockColor.rgb += volumetricLightColor * beamTint * volumetricLight * waterGlimmer *
                (scatterPhase * scatterAmount * scatterStrength);
        #endif
    #endif

    #ifdef BLOOM
        if(isEyeInWater == 3) {
            blockColor.rgb =
                mix(blockColor.rgb, vec3(0.7, 0.8, 1.0) / GLEAM_EXPOSURE, clamp(screen_distance, 0.0, 1.0));
        }
    #else
        if(isEyeInWater == 3) {
            blockColor.rgb =
                mix(blockColor.rgb, vec3(0.85, 0.9, 0.6), clamp(screen_distance, 0.0, 1.0));
        }
    #endif

    #ifdef BLOOM
        vec3 bloomSource = min(blockColor.rgb * GLEAM_EXPOSURE, vec3(8.0));
        float bloomPeak = max(max(bloomSource.r, bloomSource.g), bloomSource.b);
        float bloomMeasure = max(luma(bloomSource), bloomPeak * 0.62);
        float bloomSkyLift = step(0.9999, d) * 0.15;
        #if defined THE_END || defined NETHER
            float bloomDay = 0.0;
        #else
            float bloomDay = skyDayAmount();
        #endif
        float bloomHand = 1.0 - step(0.56, d);
        float bloomDayLift = bloomDay * (1.0 - step(0.9999, d)) * (0.45 * BLOOM_DAY_SUPPRESSION);
        float bloomLift = bloomSkyLift + bloomDayLift;
        float bloomWeight = smoothstep(BLOOM_THRESHOLD - 0.22 + bloomLift, BLOOM_THRESHOLD + 0.45 + bloomLift, bloomMeasure);
        bloomWeight *= (1.0 - bloomHand * 0.9 * bloomDay) * mix(1.0, max(1.0 - 0.3 * BLOOM_DAY_SUPPRESSION, 0.25), bloomDay * (1.0 - step(0.9999, d)));
        #if !defined THE_END && !defined NETHER
            float bloomTwilight = 1.0 - smoothstep(0.0, 0.40, abs(sunElevation));
            bloomWeight *= 1.0 - step(0.9999, d) * 0.45 * bloomTwilight;
        #endif

        blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
        /* DRAWBUFFERS:01 */
        float bloomCap = mix(3.4, 0.8 + 1.6 * SUN_BLOOM, step(0.9999, d));
        vec3 bloomOut = min(blockColor.rgb, vec3(bloomCap));
        bloomOut /= 1.0 + max(max(bloomOut.r, bloomOut.g), bloomOut.b) * 0.16;
        gl_FragData[0] = vec4(bloomOut * (bloomWeight * 0.62), 1.0);
        gl_FragData[1] = blockColor;
    #else
        blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
        /* DRAWBUFFERS:1 */
        gl_FragData[0] = blockColor;
    #endif
}
