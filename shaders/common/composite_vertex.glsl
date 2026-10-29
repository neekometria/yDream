#include "/lib/config.glsl"

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;

#if (VOL_LIGHT == 1 && !defined NETHER) || (VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER)
    uniform int isEyeInWater;
#endif

#if VOL_LIGHT == 1 && !defined NETHER
    uniform float dayNightMix;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform mat4 gbufferProjection;
#endif

#if (VOL_LIGHT == 1 && !defined NETHER) || (VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER)
    uniform mat4 gbufferModelViewInverse;
    uniform mat4 gbufferProjectionInverse;
#endif

varying vec2 texcoord;
varying vec3 directLightColor;

#if (VOL_LIGHT == 1 && !defined NETHER) || (VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER)
    varying vec3 volumetricLightColor;
#endif

#if VOL_LIGHT == 1 && !defined NETHER
    varying vec2 lightpos;
    varying vec3 astroLightPos;
#endif

#if (VOL_LIGHT == 1 && !defined NETHER) || (VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER)
    varying mat4 modeli_times_projectioni;
#endif

#include "/lib/luma.glsl"

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texcoord = gl_MultiTexCoord0.xy;

    vec2 eyeBrightSmoothFloat = vec2(eyeBrightnessSmooth);

    directLightColor = dayBlend(LIGHT_SUNSET_COLOR, LIGHT_DAY_COLOR, LIGHT_NIGHT_COLOR);
    directLightColor = mix(directLightColor, ZENITH_SKY_RAIN_COLOR * luma(directLightColor), rainStrength);

    #if (VOL_LIGHT == 1 && !defined NETHER) || (VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER)
        float vol_attenuation;
        if(isEyeInWater == 0) {
            vol_attenuation = 1.0;
        } else {
            vol_attenuation = 0.1 + (eyeBrightSmoothFloat.y * 0.002);
        }

        volumetricLightColor = dayBlend(LIGHT_SUNSET_COLOR, LIGHT_DAY_COLOR, LIGHT_NIGHT_COLOR) * 1.2 * vol_attenuation;
    #endif

    #if VOL_LIGHT == 1 && !defined NETHER
        astroLightPos = sunPosition * step(0.5, dayNightMix) * 2.0 + moonPosition;
        vec4 tpos = vec4(astroLightPos, 1.0) * gbufferProjection;
        tpos = vec4(tpos.xyz / tpos.w, 1.0);
        vec2 pos1 = tpos.xy / tpos.z;
        lightpos = pos1 * 0.5 + 0.5;
    #endif

    #if (VOL_LIGHT == 1 && !defined NETHER) || (VOL_LIGHT == 2 && defined SHADOW_CASTING && !defined NETHER)
        modeli_times_projectioni = gbufferModelViewInverse * gbufferProjectionInverse;
    #endif
}
