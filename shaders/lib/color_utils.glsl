uniform float dayMoment;
uniform float dayMixer;
uniform float nightMixer;
uniform int moonPhase;

#ifdef UNKNOWN_DIM
    uniform vec3 fogColor;
    uniform vec3 skyColor;
#endif

#define NIGHT_BRIGHT_PHASE (NIGHT_BRIGHT + (NIGHT_BRIGHT * (abs(4.0 - moonPhase) * 0.25)))

#if YDREAM_COLOR_STYLE == 0
    #define OMNI_TINT 0.42
    #define _LIGHT_SUNSET_COLOR vec3(0.98, 0.66, 0.44)
    #define _LIGHT_DAY_COLOR vec3(0.93, 0.88, 0.82)
    #define _LIGHT_NIGHT_COLOR vec3(0.078, 0.088, 0.115)

    #define _ZENITH_SUNSET_COLOR vec3(0.200, 0.300, 0.550)
    #define _ZENITH_DAY_COLOR vec3(0.260, 0.460, 0.920)
    #define _ZENITH_NIGHT_COLOR vec3(0.020, 0.030, 0.062)

    #define _HORIZON_SUNSET_COLOR vec3(0.980, 0.620, 0.380)
    #define _HORIZON_DAY_COLOR vec3(0.660, 0.800, 0.980)
    #define _HORIZON_NIGHT_COLOR vec3(0.042, 0.060, 0.105)
#elif YDREAM_COLOR_STYLE == 2
    #define OMNI_TINT 0.32
    #define _LIGHT_SUNSET_COLOR vec3(0.94, 0.52, 0.28)
    #define _LIGHT_DAY_COLOR vec3(0.94, 0.91, 0.86)
    #define _LIGHT_NIGHT_COLOR vec3(0.050, 0.066, 0.105)

    #define _ZENITH_SUNSET_COLOR vec3(0.110, 0.150, 0.300)
    #define _ZENITH_DAY_COLOR vec3(0.200, 0.370, 0.720)
    #define _ZENITH_NIGHT_COLOR vec3(0.010, 0.016, 0.034)

    #define _HORIZON_SUNSET_COLOR vec3(0.900, 0.500, 0.300)
    #define _HORIZON_DAY_COLOR vec3(0.620, 0.750, 0.900)
    #define _HORIZON_NIGHT_COLOR vec3(0.024, 0.034, 0.060)
#elif YDREAM_COLOR_STYLE == 3
    #define OMNI_TINT 0.30
    #define _LIGHT_SUNSET_COLOR vec3(0.90, 0.50, 0.30)
    #define _LIGHT_DAY_COLOR vec3(0.89, 0.885, 0.865)
    #define _LIGHT_NIGHT_COLOR vec3(0.064, 0.075, 0.102)

    #define _ZENITH_SUNSET_COLOR vec3(0.135, 0.165, 0.295)
    #define _ZENITH_DAY_COLOR vec3(0.095, 0.205, 0.465)
    #define _ZENITH_NIGHT_COLOR vec3(0.014, 0.022, 0.038)

    #define _HORIZON_SUNSET_COLOR vec3(0.920, 0.565, 0.385)
    #define _HORIZON_DAY_COLOR vec3(0.490, 0.710, 0.950)
    #define _HORIZON_NIGHT_COLOR vec3(0.029, 0.040, 0.066)
#elif YDREAM_COLOR_STYLE == 99
    #define OMNI_TINT OMNI_TINT_CUSTOM
    #define _LIGHT_SUNSET_COLOR vec3(LIGHT_SUNSET_COLOR_R, LIGHT_SUNSET_COLOR_G, LIGHT_SUNSET_COLOR_B)
    #define _LIGHT_DAY_COLOR vec3(LIGHT_DAY_COLOR_R, LIGHT_DAY_COLOR_G, LIGHT_DAY_COLOR_B)
    #define _LIGHT_NIGHT_COLOR vec3(LIGHT_NIGHT_COLOR_R, LIGHT_NIGHT_COLOR_G, LIGHT_NIGHT_COLOR_B)

    #define _ZENITH_SUNSET_COLOR vec3(ZENITH_SUNSET_COLOR_R, ZENITH_SUNSET_COLOR_G, ZENITH_SUNSET_COLOR_B)
    #define _ZENITH_DAY_COLOR vec3(ZENITH_DAY_COLOR_R, ZENITH_DAY_COLOR_G, ZENITH_DAY_COLOR_B)
    #define _ZENITH_NIGHT_COLOR vec3(ZENITH_NIGHT_COLOR_R, ZENITH_NIGHT_COLOR_G, ZENITH_NIGHT_COLOR_B)

    #define _HORIZON_SUNSET_COLOR vec3(HORIZON_SUNSET_COLOR_R, HORIZON_SUNSET_COLOR_G, HORIZON_SUNSET_COLOR_B)
    #define _HORIZON_DAY_COLOR vec3(HORIZON_DAY_COLOR_R, HORIZON_DAY_COLOR_G, HORIZON_DAY_COLOR_B)
    #define _HORIZON_NIGHT_COLOR vec3(HORIZON_NIGHT_COLOR_R, HORIZON_NIGHT_COLOR_G, HORIZON_NIGHT_COLOR_B)
#else
    #define OMNI_TINT 0.46
    #define _LIGHT_SUNSET_COLOR vec3(0.95, 0.51, 0.26)
    #define _LIGHT_DAY_COLOR vec3(0.94, 0.89, 0.82)
    #define _LIGHT_NIGHT_COLOR vec3(0.085, 0.119, 0.213)

    #define _ZENITH_SUNSET_COLOR vec3(0.240, 0.100, 0.380)
    #define _ZENITH_DAY_COLOR vec3(0.105, 0.335, 0.705)
    #define _ZENITH_NIGHT_COLOR vec3(0.031, 0.048, 0.128)

    #define _HORIZON_SUNSET_COLOR vec3(0.95, 0.41, 0.31)
    #define _HORIZON_DAY_COLOR vec3(0.52, 0.775, 0.965)
    #define _HORIZON_NIGHT_COLOR vec3(0.068, 0.085, 0.162)
#endif

#if YDREAM_NIGHT_LOOK == 2 && COLOR_SCHEME == 0 && YDREAM_COLOR_STYLE != 99
    #undef _LIGHT_NIGHT_COLOR
    #undef _ZENITH_NIGHT_COLOR
    #undef _HORIZON_NIGHT_COLOR
    #define _LIGHT_NIGHT_COLOR vec3(0.150, 0.212, 0.385)
    #define _ZENITH_NIGHT_COLOR vec3(0.0011, 0.0020, 0.0085)
    #define _HORIZON_NIGHT_COLOR vec3(0.0160, 0.0290, 0.0720)
#endif

#if COLOR_SCHEME > 0 && YDREAM_COLOR_STYLE != 99
    #undef _LIGHT_SUNSET_COLOR
    #undef _LIGHT_DAY_COLOR
    #undef _LIGHT_NIGHT_COLOR
    #undef _ZENITH_SUNSET_COLOR
    #undef _ZENITH_DAY_COLOR
    #undef _ZENITH_NIGHT_COLOR
    #undef _HORIZON_SUNSET_COLOR
    #undef _HORIZON_DAY_COLOR
    #undef _HORIZON_NIGHT_COLOR
    #if COLOR_SCHEME == 1
        #define _LIGHT_SUNSET_COLOR vec3(1.0, 0.58, 0.30)
        #define _LIGHT_DAY_COLOR vec3(1.0, 0.90, 0.72)
        #define _LIGHT_NIGHT_COLOR vec3(0.09, 0.11, 0.20)
        #define _ZENITH_SUNSET_COLOR vec3(0.30, 0.16, 0.42)
        #define _ZENITH_DAY_COLOR vec3(0.16, 0.38, 0.78)
        #define _ZENITH_NIGHT_COLOR vec3(0.030, 0.040, 0.120)
        #define _HORIZON_SUNSET_COLOR vec3(1.0, 0.50, 0.28)
        #define _HORIZON_DAY_COLOR vec3(0.88, 0.80, 0.68)
        #define _HORIZON_NIGHT_COLOR vec3(0.080, 0.090, 0.180)
        #define AURORA_LOW_COLOR vec3(1.0, 0.72, 0.22)
        #define AURORA_HIGH_COLOR vec3(1.0, 0.28, 0.42)
        #define AURORA_MID_COLOR vec3(1.0, 0.50, 0.30)
        #define AURORA_LIGHT_COLOR vec3(0.90, 0.55, 0.20)
    #endif
    #if COLOR_SCHEME == 2
        #define _LIGHT_SUNSET_COLOR vec3(0.85, 0.60, 0.62)
        #define _LIGHT_DAY_COLOR vec3(0.86, 0.92, 1.0)
        #define _LIGHT_NIGHT_COLOR vec3(0.08, 0.12, 0.24)
        #define _ZENITH_SUNSET_COLOR vec3(0.20, 0.25, 0.50)
        #define _ZENITH_DAY_COLOR vec3(0.22, 0.44, 0.84)
        #define _ZENITH_NIGHT_COLOR vec3(0.020, 0.050, 0.140)
        #define _HORIZON_SUNSET_COLOR vec3(0.85, 0.62, 0.72)
        #define _HORIZON_DAY_COLOR vec3(0.74, 0.86, 0.96)
        #define _HORIZON_NIGHT_COLOR vec3(0.060, 0.110, 0.220)
        #define AURORA_LOW_COLOR vec3(0.30, 0.95, 1.0)
        #define AURORA_HIGH_COLOR vec3(0.50, 0.62, 1.0)
        #define AURORA_MID_COLOR vec3(0.38, 0.80, 1.0)
        #define AURORA_LIGHT_COLOR vec3(0.30, 0.65, 0.85)
    #endif
    #if COLOR_SCHEME == 3
        #define _LIGHT_SUNSET_COLOR vec3(1.0, 0.35, 0.55)
        #define _LIGHT_DAY_COLOR vec3(0.98, 0.92, 0.95)
        #define _LIGHT_NIGHT_COLOR vec3(0.16, 0.10, 0.34)
        #define _ZENITH_SUNSET_COLOR vec3(0.30, 0.05, 0.55)
        #define _ZENITH_DAY_COLOR vec3(0.10, 0.35, 0.85)
        #define _ZENITH_NIGHT_COLOR vec3(0.060, 0.020, 0.200)
        #define _HORIZON_SUNSET_COLOR vec3(1.0, 0.30, 0.55)
        #define _HORIZON_DAY_COLOR vec3(0.55, 0.72, 0.98)
        #define _HORIZON_NIGHT_COLOR vec3(0.200, 0.060, 0.360)
        #define AURORA_LOW_COLOR vec3(1.0, 0.20, 0.85)
        #define AURORA_HIGH_COLOR vec3(0.25, 0.60, 1.0)
        #define AURORA_MID_COLOR vec3(0.70, 0.35, 0.95)
        #define AURORA_LIGHT_COLOR vec3(0.75, 0.30, 0.85)
    #endif
    #if COLOR_SCHEME == 4
        #define _LIGHT_SUNSET_COLOR vec3(1.0, 0.34, 0.18)
        #define _LIGHT_DAY_COLOR vec3(1.0, 0.82, 0.62)
        #define _LIGHT_NIGHT_COLOR vec3(0.16, 0.07, 0.09)
        #define _ZENITH_SUNSET_COLOR vec3(0.25, 0.05, 0.12)
        #define _ZENITH_DAY_COLOR vec3(0.46, 0.28, 0.44)
        #define _ZENITH_NIGHT_COLOR vec3(0.060, 0.020, 0.050)
        #define _HORIZON_SUNSET_COLOR vec3(1.0, 0.36, 0.20)
        #define _HORIZON_DAY_COLOR vec3(0.98, 0.62, 0.42)
        #define _HORIZON_NIGHT_COLOR vec3(0.180, 0.060, 0.080)
        #define AURORA_LOW_COLOR vec3(1.0, 0.38, 0.12)
        #define AURORA_HIGH_COLOR vec3(0.80, 0.10, 0.38)
        #define AURORA_MID_COLOR vec3(0.95, 0.24, 0.22)
        #define AURORA_LIGHT_COLOR vec3(0.85, 0.28, 0.12)
    #endif
    #if COLOR_SCHEME == 5
        #define _LIGHT_SUNSET_COLOR vec3(1.0, 0.72, 0.66)
        #define _LIGHT_DAY_COLOR vec3(1.0, 0.95, 0.90)
        #define _LIGHT_NIGHT_COLOR vec3(0.13, 0.12, 0.26)
        #define _ZENITH_SUNSET_COLOR vec3(0.48, 0.36, 0.66)
        #define _ZENITH_DAY_COLOR vec3(0.40, 0.62, 0.95)
        #define _ZENITH_NIGHT_COLOR vec3(0.060, 0.060, 0.200)
        #define _HORIZON_SUNSET_COLOR vec3(1.0, 0.70, 0.72)
        #define _HORIZON_DAY_COLOR vec3(0.90, 0.86, 0.98)
        #define _HORIZON_NIGHT_COLOR vec3(0.120, 0.120, 0.280)
        #define AURORA_LOW_COLOR vec3(0.55, 1.0, 0.85)
        #define AURORA_HIGH_COLOR vec3(0.85, 0.62, 1.0)
        #define AURORA_MID_COLOR vec3(0.70, 0.82, 1.0)
        #define AURORA_LIGHT_COLOR vec3(0.55, 0.75, 0.85)
    #endif
    #if COLOR_SCHEME == 6
        #define _LIGHT_SUNSET_COLOR vec3(1.0, 0.62, 0.40)
        #define _LIGHT_DAY_COLOR vec3(1.0, 0.94, 0.82)
        #define _LIGHT_NIGHT_COLOR vec3(0.08, 0.12, 0.22)
        #define _ZENITH_SUNSET_COLOR vec3(0.30, 0.22, 0.52)
        #define _ZENITH_DAY_COLOR vec3(0.08, 0.52, 0.92)
        #define _ZENITH_NIGHT_COLOR vec3(0.020, 0.050, 0.130)
        #define _HORIZON_SUNSET_COLOR vec3(1.0, 0.55, 0.40)
        #define _HORIZON_DAY_COLOR vec3(0.62, 0.92, 0.96)
        #define _HORIZON_NIGHT_COLOR vec3(0.060, 0.110, 0.190)
        #define AURORA_LOW_COLOR vec3(0.20, 1.0, 0.80)
        #define AURORA_HIGH_COLOR vec3(0.30, 0.55, 1.0)
        #define AURORA_MID_COLOR vec3(0.20, 0.85, 0.95)
        #define AURORA_LIGHT_COLOR vec3(0.20, 0.80, 0.80)
    #endif
    #if COLOR_SCHEME == 7
        #define _LIGHT_SUNSET_COLOR vec3(1.0, 0.50, 0.62)
        #define _LIGHT_DAY_COLOR vec3(0.97, 0.92, 1.0)
        #define _LIGHT_NIGHT_COLOR vec3(0.12, 0.10, 0.28)
        #define _ZENITH_SUNSET_COLOR vec3(0.34, 0.14, 0.52)
        #define _ZENITH_DAY_COLOR vec3(0.28, 0.32, 0.78)
        #define _ZENITH_NIGHT_COLOR vec3(0.050, 0.030, 0.170)
        #define _HORIZON_SUNSET_COLOR vec3(1.0, 0.46, 0.58)
        #define _HORIZON_DAY_COLOR vec3(0.80, 0.72, 0.96)
        #define _HORIZON_NIGHT_COLOR vec3(0.110, 0.080, 0.250)
        #define AURORA_LOW_COLOR vec3(0.65, 0.45, 1.0)
        #define AURORA_HIGH_COLOR vec3(1.0, 0.35, 0.80)
        #define AURORA_MID_COLOR vec3(0.80, 0.40, 0.95)
        #define AURORA_LIGHT_COLOR vec3(0.60, 0.40, 0.90)
    #endif
    #if COLOR_SCHEME == 8
        #define _LIGHT_SUNSET_COLOR vec3(0.98, 0.68, 0.46)
        #define _LIGHT_DAY_COLOR vec3(0.92, 0.94, 0.88)
        #define _LIGHT_NIGHT_COLOR vec3(0.07, 0.10, 0.14)
        #define _ZENITH_SUNSET_COLOR vec3(0.22, 0.28, 0.42)
        #define _ZENITH_DAY_COLOR vec3(0.30, 0.48, 0.62)
        #define _ZENITH_NIGHT_COLOR vec3(0.015, 0.030, 0.050)
        #define _HORIZON_SUNSET_COLOR vec3(0.94, 0.62, 0.44)
        #define _HORIZON_DAY_COLOR vec3(0.76, 0.84, 0.80)
        #define _HORIZON_NIGHT_COLOR vec3(0.040, 0.065, 0.090)
        #define AURORA_LOW_COLOR vec3(0.40, 1.0, 0.55)
        #define AURORA_HIGH_COLOR vec3(0.25, 0.75, 0.85)
        #define AURORA_MID_COLOR vec3(0.30, 0.90, 0.70)
        #define AURORA_LIGHT_COLOR vec3(0.30, 0.80, 0.55)
    #endif
    #if COLOR_SCHEME == 9
        #define _LIGHT_SUNSET_COLOR vec3(1.0, 0.52, 0.24)
        #define _LIGHT_DAY_COLOR vec3(1.0, 0.89, 0.68)
        #define _LIGHT_NIGHT_COLOR vec3(0.10, 0.10, 0.18)
        #define _ZENITH_SUNSET_COLOR vec3(0.34, 0.20, 0.40)
        #define _ZENITH_DAY_COLOR vec3(0.28, 0.50, 0.84)
        #define _ZENITH_NIGHT_COLOR vec3(0.030, 0.040, 0.110)
        #define _HORIZON_SUNSET_COLOR vec3(1.0, 0.48, 0.24)
        #define _HORIZON_DAY_COLOR vec3(0.96, 0.84, 0.64)
        #define _HORIZON_NIGHT_COLOR vec3(0.090, 0.085, 0.160)
        #define AURORA_LOW_COLOR vec3(1.0, 0.82, 0.30)
        #define AURORA_HIGH_COLOR vec3(0.95, 0.35, 0.35)
        #define AURORA_MID_COLOR vec3(1.0, 0.58, 0.32)
        #define AURORA_LIGHT_COLOR vec3(0.95, 0.65, 0.30)
    #endif
    #if COLOR_SCHEME == 10
        #define _LIGHT_SUNSET_COLOR vec3(0.90, 0.55, 0.40)
        #define _LIGHT_DAY_COLOR vec3(0.88, 0.92, 1.0)
        #define _LIGHT_NIGHT_COLOR vec3(0.05, 0.08, 0.20)
        #define _ZENITH_SUNSET_COLOR vec3(0.12, 0.16, 0.40)
        #define _ZENITH_DAY_COLOR vec3(0.07, 0.20, 0.54)
        #define _ZENITH_NIGHT_COLOR vec3(0.008, 0.014, 0.050)
        #define _HORIZON_SUNSET_COLOR vec3(0.88, 0.50, 0.40)
        #define _HORIZON_DAY_COLOR vec3(0.38, 0.58, 0.86)
        #define _HORIZON_NIGHT_COLOR vec3(0.030, 0.050, 0.130)
        #define AURORA_LOW_COLOR vec3(0.30, 0.70, 1.0)
        #define AURORA_HIGH_COLOR vec3(0.55, 0.45, 1.0)
        #define AURORA_MID_COLOR vec3(0.40, 0.58, 1.0)
        #define AURORA_LIGHT_COLOR vec3(0.30, 0.55, 0.95)
    #endif
#else
    #define AURORA_LOW_COLOR vec3(0.12, 1.0, 0.50)
    #define AURORA_HIGH_COLOR vec3(0.58, 0.28, 1.0)
    #define AURORA_LIGHT_COLOR vec3(0.16, 0.80, 0.52)
#endif

#if AURORA_PALETTE == 1
    #undef AURORA_LIGHT_COLOR
    #define AURORA_LIGHT_COLOR vec3(0.40, 0.58, 0.95)
#elif AURORA_PALETTE == 2
    #undef AURORA_LIGHT_COLOR
    #define AURORA_LIGHT_COLOR vec3(0.55, 0.35, 0.90)
#elif AURORA_PALETTE == 3
    #undef AURORA_LIGHT_COLOR
    #define AURORA_LIGHT_COLOR vec3(0.90, 0.55, 0.40)
#elif AURORA_PALETTE == 4
    #undef AURORA_LIGHT_COLOR
    #define AURORA_LIGHT_COLOR vec3(0.25, 0.85, 0.50)
#elif AURORA_PALETTE == 5
    #undef AURORA_LIGHT_COLOR
    #define AURORA_LIGHT_COLOR vec3(0.55, 0.85, 0.40)
#elif AURORA_PALETTE == 6
    #undef AURORA_LIGHT_COLOR
    #define AURORA_LIGHT_COLOR vec3(0.45, 0.78, 0.95)
#elif AURORA_PALETTE == 7
    #undef AURORA_LIGHT_COLOR
    #define AURORA_LIGHT_COLOR vec3(0.90, 0.55, 0.75)
#elif AURORA_PALETTE == 8
    #undef AURORA_LIGHT_COLOR
    #define AURORA_LIGHT_COLOR vec3(0.95, 0.60, 0.30)
#elif AURORA_PALETTE == 9
    #undef AURORA_LIGHT_COLOR
    #define AURORA_LIGHT_COLOR (vec3(AURORA_CUSTOM_LOW_R + AURORA_CUSTOM_HIGH_R, AURORA_CUSTOM_LOW_G + AURORA_CUSTOM_HIGH_G, AURORA_CUSTOM_LOW_B + AURORA_CUSTOM_HIGH_B) * 0.4)
#endif

#define LIGHT_SUNSET_COLOR (_LIGHT_SUNSET_COLOR * YDREAM_SUN_INTENSITY * YDREAM_STYLE_SUN_MULT)
#define LIGHT_DAY_COLOR (_LIGHT_DAY_COLOR * YDREAM_SUN_INTENSITY * YDREAM_STYLE_SUN_MULT)
#define LIGHT_NIGHT_COLOR (mix(vec3(dot(_LIGHT_NIGHT_COLOR, vec3(0.3333333))), _LIGHT_NIGHT_COLOR, NIGHT_COLOR_RICHNESS) * NIGHT_BRIGHT_PHASE * YDREAM_MOON_INTENSITY * YDREAM_STYLE_MOON_MULT)

#define ZENITH_SUNSET_COLOR _ZENITH_SUNSET_COLOR
#define ZENITH_DAY_COLOR _ZENITH_DAY_COLOR
#define ZENITH_NIGHT_COLOR (((mix(vec3(dot(_ZENITH_NIGHT_COLOR, vec3(0.3333333))), _ZENITH_NIGHT_COLOR, NIGHT_COLOR_RICHNESS) * NIGHT_BRIGHT_PHASE * YDREAM_MOON_INTENSITY * YDREAM_STYLE_MOON_MULT)) / NIGHT_SKY_DARKNESS)

#define HORIZON_SUNSET_COLOR _HORIZON_SUNSET_COLOR
#define HORIZON_DAY_COLOR _HORIZON_DAY_COLOR
#define HORIZON_NIGHT_COLOR (((mix(vec3(dot(_HORIZON_NIGHT_COLOR, vec3(0.3333333))), _HORIZON_NIGHT_COLOR, NIGHT_COLOR_RICHNESS) * NIGHT_BRIGHT_PHASE * YDREAM_MOON_INTENSITY * YDREAM_STYLE_MOON_MULT)) / NIGHT_SKY_DARKNESS)

#define NV_COLOR vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B)

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

#if VOL_LIGHT == 1 || (VOL_LIGHT == 2 && defined SHADOW_CASTING) || defined UNKNOWN_DIM
    #define FOG_DENSITY 3.0
#else
    #define FOG_DAY 3.0
    #define FOG_SUNSET 2.0
    #define FOG_NIGHT 3.0
#endif

#include "/lib/color_conversion.glsl"

#include "/lib/water_color.glsl"
