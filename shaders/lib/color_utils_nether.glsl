uniform float dayMoment;
uniform float dayMixer;
uniform float nightMixer;

uniform vec3 fogColor;

vec3 netherHue(vec3 rawFog) {
    float rawLuma = max(dot(rawFog, vec3(0.2126, 0.7152, 0.0722)), 0.004);
    return clamp(rawFog / rawLuma, vec3(0.20), vec3(4.0));
}

vec3 netherLightHue(vec3 rawFog) {
    return mix(vec3(1.0), netherHue(rawFog), 0.46);
}

vec3 netherAmbientHue(vec3 rawFog) {
    return mix(vec3(1.0), netherHue(rawFog), 0.62);
}

#if GLEAM_COLOR_STYLE == 0
    #define OMNI_TINT 0.45
    #define NETHER_LIGHT_LUMA 0.130
    #define NETHER_AMBIENT_LUMA 0.100
    #define NETHER_FOG_LUMA 0.075
#elif GLEAM_COLOR_STYLE == 2 || GLEAM_COLOR_STYLE == 3
    #define OMNI_TINT 0.42
    #define NETHER_LIGHT_LUMA 0.150
    #define NETHER_AMBIENT_LUMA 0.120
    #define NETHER_FOG_LUMA 0.080
#else
    #define OMNI_TINT 0.52
    #define NETHER_LIGHT_LUMA 0.205
    #define NETHER_AMBIENT_LUMA 0.175
    #define NETHER_FOG_LUMA 0.105
#endif

#define NETHER_FILL 0.09

vec3 netherFog(vec3 rawFog) {
    return mix(vec3(1.0), netherHue(rawFog), 0.80) * NETHER_FOG_LUMA;
}

#define LIGHT_SUNSET_COLOR (netherLightHue(fogColor) * NETHER_LIGHT_LUMA)
#define LIGHT_DAY_COLOR (netherLightHue(fogColor) * NETHER_LIGHT_LUMA)
#define LIGHT_NIGHT_COLOR (netherLightHue(fogColor) * NETHER_LIGHT_LUMA)

#define ZENITH_SUNSET_COLOR (netherAmbientHue(fogColor) * NETHER_AMBIENT_LUMA)
#define ZENITH_DAY_COLOR (netherAmbientHue(fogColor) * NETHER_AMBIENT_LUMA)
#define ZENITH_NIGHT_COLOR (netherAmbientHue(fogColor) * NETHER_AMBIENT_LUMA)

#define HORIZON_SUNSET_COLOR netherFog(fogColor)
#define HORIZON_DAY_COLOR netherFog(fogColor)
#define HORIZON_NIGHT_COLOR netherFog(fogColor)

#if BLOCKLIGHT_TEMP == 0
    #define CANDLE_BASELIGHT vec3(0.29975, 0.15392353, 0.0799)
#elif BLOCKLIGHT_TEMP == 1
    #define CANDLE_BASELIGHT vec3(0.27475, 0.17392353, 0.0899)
#elif BLOCKLIGHT_TEMP == 2
    #define CANDLE_BASELIGHT vec3(0.24975, 0.19392353, 0.0999)
#elif BLOCKLIGHT_TEMP == 3
    #define CANDLE_BASELIGHT vec3(0.22, 0.19, 0.14)
#else
    #define CANDLE_BASELIGHT vec3(0.19, 0.19, 0.19)
#endif

#include "/lib/day_blend.glsl"

#define FOG_DAY (1.0 * GLEAM_HAZE)
#define FOG_SUNSET (1.0 * GLEAM_HAZE)
#define FOG_NIGHT (1.0 * GLEAM_HAZE)

#include "/lib/color_conversion.glsl"

#include "/lib/water_color.glsl"
