#include "/lib/config.glsl"

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

uniform sampler2D tex;
uniform float pixelSizeX;
uniform float pixelSizeY;
uniform float near;
uniform float far;
uniform sampler2D gaux1;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform float nightVision;
uniform float rainStrength;
uniform float dayNightMix;
uniform ivec2 eyeBrightnessSmooth;
uniform sampler2D gaux4;
uniform vec3 cameraPosition;

#if defined DISTANT_HORIZONS
    uniform float dhNearPlane;
    uniform float dhFarPlane;
    uniform sampler2D dhDepthTex1;
#endif

#if V_CLOUDS != 0
    uniform sampler2D gaux2;
#endif

#if defined SHADOW_CASTING && !defined NETHER
    uniform sampler2DShadow shadowtex1;
    #if defined COLORED_SHADOW
        uniform sampler2DShadow shadowtex0;
        uniform sampler2D shadowcolor0;
    #endif
#endif


#if defined CLOUD_REFLECTION && (V_CLOUDS != 0 && !defined UNKNOWN_DIM) && !defined NETHER
    uniform mat4 gbufferModelViewInverse;
#endif

uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
    uniform float darknessLightFactor;
#endif

#if SHADOW_LOCK > 0 && defined SHADOW_CASTING
    uniform mat4 shadowModelView;
    uniform mat4 shadowProjection;
    uniform vec3 shadowLightPosition;
#endif

#if defined THE_END || (SHADOW_LOCK > 0 && defined SHADOW_CASTING && !defined NETHER)
    uniform mat4 gbufferModelView;
#endif

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 tintColor;
varying float frogAdjust;
varying float fogSunScatter;
#include "/lib/fog_blend.glsl"
varying vec3 waterNormal;
varying float blockType;
varying vec4 worldposition;
varying vec3 fragposition;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 directLightColor;
varying vec3 candleColor;
varying float directLightStrength;
varying vec3 omniLight;
varying float visibleSky;
varying vec3 upVector;
varying vec3 zenithSkyColor;
varying vec3 horizonSkyColor;

#if defined SHADOW_CASTING && !defined NETHER
    varying vec3 shadowPos;
    varying float shadowDiffuse;
#endif

#if defined SHADOW_CASTING && SHADOW_LOCK > 0 && !defined NETHER
    varying vec3 vWorldPos;
    varying vec3 vNormal;
    varying vec3 vBias;
#endif

#if (V_CLOUDS != 0 && !defined UNKNOWN_DIM) && !defined NO_CLOUDY_SKY
    varying float umbral;
    varying vec3 cloudColor;
    varying vec3 darkCloudColor;
#endif

#include "/lib/projection_utils.glsl"
#include "/lib/basic_utils.glsl"
#include "/lib/dither.glsl"
#include "/lib/water.glsl"

#if defined SHADOW_CASTING && !defined NETHER
    #include "/lib/shadow_frag.glsl"
#endif

#include "/lib/luma.glsl"

#if defined CLOUD_REFLECTION && (V_CLOUDS != 0 && !defined UNKNOWN_DIM) && !defined NETHER
    #include "/lib/volumetric_clouds.glsl"
#endif

#if defined SHADOW_CASTING && SHADOW_LOCK > 0 && !defined NETHER
    #include "/lib/shadow_vertex.glsl"
#endif

void main() {
    vec2 eyeBrightSmoothFloat = vec2(eyeBrightnessSmooth);

    #if SHADOW_TYPE == 1 || defined DISTANT_HORIZONS || (defined CLOUD_REFLECTION && (V_CLOUDS != 0 && !defined UNKNOWN_DIM) && !defined NETHER) || SSR_TYPE > 0
        #if AA_TYPE > 0
            float dither = shiftedRDither(gl_FragCoord.xy);
        #else
            float dither = rDither(gl_FragCoord.xy);
        #endif
    #else
        float dither = 1.0;
    #endif

    vec4 blockColor;
    vec3 realLight;
    vec3 glassAlbedo = vec3(0.0);

    vec3 waterNormalBase = normal_waves(worldposition.xzy);

    vec3 surfaceNormal;
    if(blockType > 2.5) {
        surfaceNormal = get_normals(waterNormalBase, fragposition);
    } else {
        surfaceNormal = get_normals(vec3(0.0, 0.0, 1.0), fragposition);
    }

    float normalDotEye = dot(surfaceNormal, normalize(fragposition));
    float fresnel = 0.02 + 0.98 * pow(clamp(1.0 + normalDotEye, 0.0, 1.0), STYLE_WATER_FRESNEL);

    vec3 reflectWaterVector = reflect(fragposition, surfaceNormal);
    vec3 normalizedReflectWaterVector = normalize(reflectWaterVector);

    vec3 skyColorReflect;
    if(isEyeInWater == 0 || isEyeInWater == 2) {
        skyColorReflect = mix(horizonSkyColor, zenithSkyColor, smoothstep(0.0, 1.0, pow(clamp(dot(normalizedReflectWaterVector, upVector), 0.0001, 1.0), 0.333)));
    } else {
        skyColorReflect = zenithSkyColor * .5 * ((eyeBrightSmoothFloat.y * .8 + 48) * 0.004166666666666667);
    }

    skyColorReflect = xyzToRgb(skyColorReflect);

    #if !defined NETHER && !defined THE_END
        if(isEyeInWater == 0) {
            vec3 reflectAstro = normalize(mix(moonPosition, sunPosition, step(0.5, dayNightMix)));
            float reflectAlign = max(dot(normalizedReflectWaterVector, reflectAstro), 0.0);
            float reflectFade = smoothstep(-0.05, 0.12, dot(reflectAstro, upVector)) * (1.0 - rainStrength);
            float reflectGlow = pow(reflectAlign, 6.0) * 0.16 + pow(reflectAlign, 32.0) * 0.30;
            skyColorReflect += directLightColor * (reflectGlow * reflectFade * STYLE_SUN_GLOW * SUN_GLOW);
        }
    #endif

    #if defined CLOUD_REFLECTION && (V_CLOUDS != 0 && !defined UNKNOWN_DIM) && !defined NETHER
        if(isEyeInWater == 0) {
            skyColorReflect = get_cloud(normalize((gbufferModelViewInverse * vec4(reflectWaterVector * far, 1.0)).xyz), skyColorReflect, 0.0, dither, worldposition.xyz, int(CLOUD_STEPS_AVG * 0.5), umbral, cloudColor, darkCloudColor, normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz) * mix(-1.0, 1.0, step(0.5, dayNightMix)), 1e9);
        }
    #endif
    if(blockType > 2.5) {
        #ifdef VANILLA_WATER
            blockColor = texture2D(tex, texcoord);
            #if defined SHADOW_CASTING && !defined NETHER
                #if SHADOW_LOCK > 0
                    vec3 offsetVector = vNormal * 0.002;
                    vec3 preSnapPos = vWorldPos + offsetVector;
                    float texelSize = SHADOW_LOCK;
                    vec3 absPos = preSnapPos + cameraPosition;

                    vec3 snappedAbsolute = floor(absPos * texelSize) / texelSize;
                    snappedAbsolute += 0.5 / texelSize;
                    vec3 final_world_pos = (snappedAbsolute - cameraPosition) + vBias;
                    vec3 shadow_real_pos = get_shadow_pos(final_world_pos);
                #else
                    vec3 shadow_real_pos = shadowPos;
                #endif
                #if defined COLORED_SHADOW
                    vec3 shadowValue = get_colored_shadow(shadow_real_pos, 0.5);
                    shadowValue = mix(shadowValue, vec3(1.0), shadowDiffuse);
                #else
                    float shadowValue = get_shadow(shadow_real_pos, 0.5);
                    shadowValue = mix(shadowValue, 1.0, shadowDiffuse);
                #endif
            #else
                float shadowValue = abs((dayNightMix * 2.0) - 1.0);
            #endif

            float fresnelTex = luma(blockColor.rgb);

            realLight = omniLight +
                (directLightStrength * shadowValue * directLightColor) * (1.0 - rainStrength * 0.55) +
                candleColor;

            realLight *= (fresnelTex * 2.0) - 0.25;

            blockColor.rgb *= mix(realLight, vec3(1.0), nightVision * .125) * tintColor.rgb;

            blockColor.rgb = water_shader(fragposition, surfaceNormal, blockColor.rgb, skyColorReflect, normalizedReflectWaterVector, fresnel, visibleSky, dither, directLightColor);

            blockColor.a = sqrt(blockColor.a);
        #else
            #if WATER_TEXTURE == 1
                blockColor = texture2D(tex, texcoord);
                float waterTexture = luma(blockColor.rgb);
            #else
                float waterTexture = 1.0;
            #endif

            realLight = omniLight +
                (directLightStrength * visibleSky * directLightColor) * (1.0 - rainStrength * 0.55) +
                candleColor;

            float waterNightDim = 1.0 - smoothstep(0.0, 0.35, dayNightMix);
            realLight *= 1.0 - 0.45 * waterNightDim;

            #if WATER_COLOR_SOURCE == 0
                blockColor.rgb = waterTexture * realLight * WATER_COLOR;
            #elif WATER_COLOR_SOURCE == 1
                blockColor.rgb = 0.3 * waterTexture * realLight * tintColor.rgb;
            #endif

            blockColor = vec4(refraction(fragposition, blockColor.rgb, waterNormalBase), 1.0);

            #if !defined NETHER && !defined THE_END
                if(isEyeInWater == 0) {
                    vec3 sssLight = normalize(mix(moonPosition, sunPosition, step(0.5, dayNightMix)));
                    float sssView = pow(max(dot(normalize(fragposition), sssLight), 0.0), 3.0);
                    float sssCrest = clamp(length(waterNormalBase.xy) * 2.4, 0.0, 1.0);
                    float sssFade = smoothstep(0.0, 0.25, dot(sssLight, upVector)) * (1.0 - rainStrength);
                    blockColor.rgb += directLightColor * WATER_COLOR * (sssView * (0.35 + 0.65 * sssCrest) * sssFade * visibleSky * 1.6 * (1.0 - 0.6 * waterNightDim));
                }
            #endif

            #if WATER_TEXTURE == 1
                waterTexture += 0.25;
                waterTexture *= waterTexture;
                waterTexture *= waterTexture;
                fresnel = clamp(fresnel * (waterTexture), 0.0, 1.0);
            #endif

            blockColor.rgb = water_shader(fragposition, surfaceNormal, blockColor.rgb, skyColorReflect, normalizedReflectWaterVector, fresnel, visibleSky, dither, directLightColor);

        #endif

    } else {
        blockColor = texture2D(tex, texcoord);

        blockColor *= tintColor;

        #if defined SHADOW_CASTING && !defined NETHER
            #if defined COLORED_SHADOW
                vec3 shadowValue = get_colored_shadow(shadowPos, dither);
                shadowValue = mix(shadowValue, vec3(1.0), shadowDiffuse);
            #else
                float shadowValue = get_shadow(shadowPos, dither);
                shadowValue = mix(shadowValue, 1.0, shadowDiffuse);
            #endif
        #else
            float shadowValue = abs((dayNightMix * 2.0) - 1.0);
        #endif

        realLight = omniLight +
            (directLightStrength * shadowValue * directLightColor) * (1.0 - rainStrength * 0.55) +
            candleColor;

        glassAlbedo = blockColor.rgb;

        blockColor.rgb *= mix(realLight, vec3(1.0), nightVision * .125);

        if(blockType > 1.5) {
            blockColor = cristal_shader(fragposition, waterNormal, blockColor, skyColorReflect, fresnel * fresnel, visibleSky, dither, directLightColor);
        }
    }

    #if !defined NETHER && !defined THE_END
        if(isEyeInWater == 1 && blockType > 2.5) {
            vec3 uwView = normalize(fragposition);
            float uwCosI = clamp(abs(dot(surfaceNormal, uwView)), 0.0, 1.0);
            float outsideWindow = 1.0 - smoothstep(0.58, 0.72, uwCosI);

            vec2 uwUV = gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY);
            vec3 skyWindow = texture2D(gaux4, uwUV + waterNormalBase.xy * 0.004).rgb;
            vec3 windowColor = skyWindow * vec3(0.62, 0.86, 1.05) * (0.90 + 0.35 * smoothstep(0.72, 1.0, uwCosI));

            vec3 uwLight = normalize(mix(moonPosition, sunPosition, step(0.5, dayNightMix)));
            float uwSunAlign = max(dot(uwView, uwLight), 0.0);
            float uwSunFade = smoothstep(-0.05, 0.20, dot(uwLight, upVector)) * (1.0 - rainStrength);
            windowColor += directLightColor * vec3(0.55, 0.90, 1.0) * ((pow(uwSunAlign, 70.0) * 0.85 + pow(uwSunAlign, 9.0) * 0.14) * uwSunFade);

            vec3 tirColor = underwaterFogColor(directLightColor, visibleSky) * 1.25 + WATER_COLOR * 0.10;
            tirColor *= mix(0.78, 1.10, smoothstep(0.0, 0.58, uwCosI));

            float uwRim = exp(-pow((uwCosI - 0.65) / 0.055, 2.0)) * 0.16;

            blockColor.rgb = mix(windowColor, tirColor, outsideWindow) + vec3(0.35, 0.75, 0.90) * (uwRim * (0.4 + 0.6 * visibleSky));
            blockColor.a = 1.0;
        }
    #endif

    #ifdef DISTANT_HORIZONS
        float t = far - dhNearPlane;
        float sup = t * TRANSITION_DH_SUP;
        float inf = t * TRANSITION_DH_INF;
        float draw_umbral = (gl_FogFragCoord - (dhNearPlane + inf)) / (far - sup - inf - dhNearPlane);
        if(draw_umbral > dither) {
            discard;
            return;
        }
    #endif

    #include "/src/finalcolor.glsl"
    #include "/src/writebuffers.glsl"
}
