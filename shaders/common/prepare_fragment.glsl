#include "/lib/config.glsl"

#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform float pixelSizeX;
uniform float pixelSizeY;
uniform float frameTimeCounter;

#if defined THE_END || defined NETHER
    uniform vec3 cameraPosition;
#endif

#if !defined THE_END && !defined NETHER
    uniform float rainStrength;
    #if RAINBOW == 1
        uniform float wetness;
    #endif
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
#endif

varying vec3 upVector;
varying vec3 zenithSkyColor;
varying vec3 horizonSkyColor;

#include "/lib/luma.glsl"
#include "/lib/dither.glsl"

#if !defined UNKNOWN_DIM
    #include "/lib/sky.glsl"
#endif

#if defined THE_END
    #include "/lib/end_sky.glsl"
#endif

#if defined NORTHSTAR_VENUS || defined NORTHSTAR_MARS
    #include "/lib/planet_atmosphere.glsl"
#endif

void main() {
    #if AA_TYPE > 0
        float dither = shiftedRDither(gl_FragCoord.xy);
    #else
        float dither = dither13(gl_FragCoord.xy);
    #endif

    vec4 fragpos =
        gbufferProjectionInverse *
        (vec4(gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY), gl_FragCoord.z, 1.0) * 2.0 - 1.0);
    vec3 nfragpos = normalize(fragpos.xyz);
    float skyElevation = dot(nfragpos, upVector);

    vec3 fogSky;
    vec3 fullSky;

    #if defined THE_END
        vec3 worldDir = normalize((gbufferModelViewInverse * vec4(nfragpos, 0.0)).xyz);
        float endPixelAngle = 2.0 * pixelSizeY * gbufferProjectionInverse[1].y;

        // Altitude shifts the atmosphere a little: cooler low down, hotter high up.
        float endAltitudeHeat = smoothstep(END_COLD_Y, max(END_HOT_Y, END_COLD_Y + 1.0), cameraPosition.y);
        vec3 endAtmosphereTint = mix(vec3(0.72, 0.84, 1.04), vec3(1.18, 0.58, 0.30), endAltitudeHeat);

        vec3 endSky = endSkyGradient(worldDir);
        endSky *= mix(vec3(1.0), endAtmosphereTint, clamp(END_VERTICAL_HEAT * 0.5, 0.0, 1.0));

        // Fog uses the sky without the core, so distant terrain does not get a disc in it.
        fogSky = endSky;

        vec3 endFull = endSky;
        #ifdef END_CORE
            endFull += endCoreLayer(worldDir, endPixelAngle, frameTimeCounter);
        #endif
        fullSky = endFull;
    #elif defined NETHER
        vec3 worldDir = normalize((gbufferModelViewInverse * vec4(nfragpos, 0.0)).xyz);

        vec3 blockColor = xyzToRgb(mix(horizonSkyColor, zenithSkyColor, clamp(skyElevation * 0.5 + 0.5, 0.0, 1.0)));

        float netherPixelAngle = 2.0 * pixelSizeY * gbufferProjectionInverse[1].y;

        vec3 emberDir = worldDir + vec3(0.0, frameTimeCounter * 0.015, 0.0);
        float emberTheta = atan(emberDir.z, emberDir.x);
        float emberPhi = asin(clamp(fract(emberDir.y * 0.5 + 0.5) * 2.0 - 1.0, -1.0, 1.0));
        vec2 emberCoord = vec2(emberTheta, emberPhi) * 50.0;
        vec2 emberCell = floor(emberCoord);
        float emberHash = hash12(emberCell);
        vec2 emberLocal = fract(emberCoord) - 0.5;
        float emberDist = length(emberLocal);
        float ember = (1.0 - smoothstep(0.0, 0.20, emberDist)) * step(0.975, emberHash);
        blockColor += NETHER_EMBER_COLOR * ember * 0.38;

        float netherGlow = pow(1.0 - clamp(abs(skyElevation), 0.0, 1.0), 4.0);
        blockColor += NETHER_GLOW_COLOR * (netherGlow * 0.05 * NETHER_HAZE_GLOW);

        fogSky = blockColor;
        #if CUSTOM_DIMENSION_STARS == 1
            // The Overworld night-sky star system (clusters, hero stars, constellations, dust),
            // always visible in the Nether. Clouds are added later in deferred.
            blockColor += nightSkyLayer(worldDir, netherPixelAngle, frameTimeCounter, 0.0) * NETHER_STAR_BRIGHTNESS;
        #endif
        fullSky = blockColor;
    #elif defined NORTHSTAR_MOON || defined NORTHSTAR_MARS || defined NORTHSTAR_MERCURY || defined NORTHSTAR_VENUS || defined NORTHSTAR_ORBIT
        vec3 worldDir = normalize((gbufferModelViewInverse * vec4(nfragpos, 0.0)).xyz);
        vec3 blockColor = xyzToRgb(mix(horizonSkyColor, zenithSkyColor,
            clamp(skyElevation * 0.5 + 0.5, 0.0, 1.0)));
        vec3 northstarSky = blockColor;
        vec3 northstarSunVector = (gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz;
        float northstarSunVectorLength = length(northstarSunVector);
        vec3 northstarSunDir = northstarSunVectorLength > 1.0e-4
            ? northstarSunVector / northstarSunVectorLength
            : vec3(0.0, 1.0, 0.0);
        float northstarSunElevation = dot(northstarSunDir, vec3(0.0, 1.0, 0.0));
        float northstarDaylight = smoothstep(-0.10, 0.16, northstarSunElevation);
        float northstarNight = 1.0 - northstarDaylight;
        float northstarStarDensity = 0.24;
        float northstarStarBrightness = 0.9;
        vec3 northstarSunColor = vec3(1.0, 0.88, 0.66);
        float northstarSunSize = 0.0047;

        #if defined NORTHSTAR_MOON
            // Airless lunar sky: black-blue above a very faint horizon scatter.
            northstarSky = mix(vec3(NORTHSTAR_MOON_ZENITH_R, NORTHSTAR_MOON_ZENITH_G, NORTHSTAR_MOON_ZENITH_B),
                vec3(NORTHSTAR_MOON_HORIZON_R, NORTHSTAR_MOON_HORIZON_G, NORTHSTAR_MOON_HORIZON_B),
                pow(1.0 - max(skyElevation, 0.0), 5.0) * NORTHSTAR_MOON_HAZE);
            northstarStarDensity = 0.32;
            // The airless Moon keeps a black sky even in daylight, so its
            // stars remain visible except for the immediate solar glare.
            northstarStarBrightness = 0.85;
            northstarSunSize = NORTHSTAR_MOON_SUN_SIZE;
        #elif defined NORTHSTAR_MARS
            // Mars: thin CO2 air (about 0.6 % of Earth's pressure) carrying fine iron-rich dust.
            // The tawny day sky and the blue sun glow come from the dust optical depth.
            vec3 marsSky = marsSkyColor(worldDir, skyElevation, northstarSunDir, northstarDaylight,
                vec3(NORTHSTAR_MARS_ZENITH_R, NORTHSTAR_MARS_ZENITH_G, NORTHSTAR_MARS_ZENITH_B),
                vec3(NORTHSTAR_MARS_HORIZON_R, NORTHSTAR_MARS_HORIZON_G, NORTHSTAR_MARS_HORIZON_B),
                NORTHSTAR_MARS_DUST_TAU, NORTHSTAR_MARS_HAZE);
            vec3 marsNightSky = vec3(0.003, 0.004, 0.012);
            northstarSky = mix(marsNightSky, marsSky, mix(0.10, 1.0, northstarDaylight));
            northstarStarDensity = 0.16;
            northstarStarBrightness = 0.58 * northstarNight;
            // Dust in the thin air dims stars low on the horizon.
            northstarStarBrightness *= mix(1.0 - NORTHSTAR_MARS_STAR_DUST_FADE, 1.0, smoothstep(0.0, 0.35, skyElevation));
            northstarSunSize = NORTHSTAR_MARS_SUN_SIZE;
            northstarSunColor = vec3(0.98, 0.97, 1.0);
        #elif defined NORTHSTAR_MERCURY
            // Almost airless: a visible deep-space vault, with a thin sodium
            // glow near the horizon rather than an Earth-like blue atmosphere.
            float mercuryHaze = pow(1.0 - abs(skyElevation), 7.0) * NORTHSTAR_MERCURY_HAZE;
            northstarSky = mix(vec3(NORTHSTAR_MERCURY_HORIZON_R, NORTHSTAR_MERCURY_HORIZON_G, NORTHSTAR_MERCURY_HORIZON_B),
                vec3(NORTHSTAR_MERCURY_ZENITH_R, NORTHSTAR_MERCURY_ZENITH_G, NORTHSTAR_MERCURY_ZENITH_B),
                smoothstep(0.0, 1.0, max(skyElevation, 0.0)));
            northstarSky += vec3(0.18, 0.075, 0.024) * mercuryHaze;
            northstarSky = mix(vec3(0.002, 0.003, 0.012), northstarSky, mix(0.55, 1.0, northstarDaylight));
            northstarStarDensity = 0.30;
            northstarStarBrightness = 0.80;
            northstarSunSize = NORTHSTAR_MERCURY_SUN_SIZE;
            northstarSunColor = vec3(1.0, 0.86, 0.58);
        #elif defined NORTHSTAR_VENUS
            // Venus: about 92 bar of CO2 under an opaque sulfuric-acid cloud deck (45 to 70 km).
            // Ground light is a diffuse, dim yellow-orange glow, and no stars show through.
            northstarSky = venusSkyColor(worldDir, skyElevation, northstarSunDir, northstarDaylight,
                vec3(NORTHSTAR_VENUS_ZENITH_R, NORTHSTAR_VENUS_ZENITH_G, NORTHSTAR_VENUS_ZENITH_B),
                vec3(NORTHSTAR_VENUS_HORIZON_R, NORTHSTAR_VENUS_HORIZON_G, NORTHSTAR_VENUS_HORIZON_B),
                NORTHSTAR_VENUS_HAZE * NORTHSTAR_VENUS_OPACITY);
            northstarStarDensity = 0.0;
            northstarStarBrightness = 0.0;
            northstarSunSize = NORTHSTAR_VENUS_SUN_SIZE;
            northstarSunColor = vec3(1.0, 0.80, 0.50);
        #else
            // Planetary orbits: vacuum black with a clear, dense star field.
            northstarSky = mix(vec3(NORTHSTAR_ORBIT_ZENITH_R, NORTHSTAR_ORBIT_ZENITH_G, NORTHSTAR_ORBIT_ZENITH_B),
                vec3(NORTHSTAR_ORBIT_HORIZON_R, NORTHSTAR_ORBIT_HORIZON_G, NORTHSTAR_ORBIT_HORIZON_B),
                pow(1.0 - max(skyElevation, 0.0), 12.0));
            northstarStarDensity = 0.36;
            northstarStarBrightness = 1.1;
            // Sun radius (0.00465 rad from 1 AU) divided by this orbit's radius, times the visual scale.
            #ifdef NORTHSTAR_ORBIT_REALISTIC_SUN
                // Mercury orbit: the true angular size of the Sun from this distance.
                northstarSunSize = 0.00465 / NORTHSTAR_ORBIT_RADIUS;
            #else
                northstarSunSize = 0.00465 * NORTHSTAR_ORBIT_SUN_SCALE / NORTHSTAR_ORBIT_RADIUS;
            #endif
            // Inverse-square law: sunlight is brighter closer to the Sun.
            northstarSunColor = vec3(1.0, 0.88, 0.66) * clamp(1.0 / (NORTHSTAR_ORBIT_RADIUS * NORTHSTAR_ORBIT_RADIUS), 0.35, 3.0);
        #endif

        #ifndef NORTHSTAR_ATMOSPHERE
            northstarSky = blockColor;
        #endif
        northstarStarBrightness *= NORTHSTAR_STAR_BRIGHTNESS;

        // Distant-horizon terrain blends with atmosphere only; stars and the
        // sun disk stay in the sky layer and cannot shine through terrain.
        fogSky = northstarSky;
        float northstarSunAngle = acos(clamp(dot(worldDir, northstarSunDir), -1.0, 1.0));

        #if NORTHSTAR_SUNS == 1
            float northstarSunDisk = 1.0 - smoothstep(northstarSunSize * 0.985,
                northstarSunSize * 1.015, northstarSunAngle);
            float northstarSunHalo = exp(-northstarSunAngle / max(northstarSunSize * 1.8, 0.0001));
            #if defined NORTHSTAR_VENUS
                // The cloud deck absorbs most sunlight: the disk is faint and dims toward the horizon.
                northstarSky += northstarSunColor * (northstarSunDisk * venusSunTransmittance(northstarSunElevation, NORTHSTAR_VENUS_OPACITY) * 2.4 + northstarSunHalo * 0.02) * NORTHSTAR_SUN_BRIGHTNESS;
            #else
                northstarSky += northstarSunColor * (northstarSunDisk * 5.0 + northstarSunHalo * 0.08) * NORTHSTAR_SUN_BRIGHTNESS;
            #endif
        #endif

        #if CUSTOM_DIMENSION_STARS == 1
        if (northstarStarDensity > 0.0) {
            float northstarPixelAngle = 2.0 * pixelSizeY * gbufferProjectionInverse[1].y;
            float airlessStarVisibility = 1.0;
            #if defined NORTHSTAR_MOON || defined NORTHSTAR_MERCURY
                airlessStarVisibility = smoothstep(0.025, 0.16, northstarSunAngle);
            #endif
            northstarSky += customStarsLayer(worldDir, northstarPixelAngle, frameTimeCounter,
                northstarStarDensity / 0.18) * northstarStarBrightness * airlessStarVisibility;
        }
        #endif
        fullSky = northstarSky;
    #elif defined UNKNOWN_DIM
        float n_u = clamp(skyElevation + dither * 0.0625 - 0.03125, 0.0, 1.0);
        float hazeExp = clamp(0.333 / (GLEAM_HAZE * GLEAM_STYLE_HAZE_MULT), 0.15, 0.7);
        vec3 blockColor =
            xyzToRgb(mix(horizonSkyColor, zenithSkyColor, smoothstep(0.0, 1.0, pow(n_u, hazeExp))));

        fogSky = blockColor;
        fullSky = blockColor;
    #else
        float rainAmount = clamp(rainStrength * RAIN_ATMOSPHERE_STRENGTH, 0.0, 1.0);

        vec3 sunDir = normalize(sunPosition);
        vec3 moonDir = normalize(moonPosition);
        float sunAltitude = dot(sunDir, upVector);
        float moonAltitude = dot(moonDir, upVector);
        float cosSun = dot(nfragpos, sunDir);
        float cosMoon = dot(nfragpos, moonDir);
        vec3 worldDir = normalize((gbufferModelViewInverse * vec4(nfragpos, 0.0)).xyz);

        float n_u = clamp(skyElevation + dither * 0.0625 - 0.03125, 0.0, 1.0);
        float hazeExp = clamp(0.333 / (GLEAM_HAZE * GLEAM_STYLE_HAZE_MULT), 0.15, 0.7);
        vec3 sky = xyzToRgb(mix(horizonSkyColor, zenithSkyColor, smoothstep(0.0, 1.0, pow(n_u, hazeExp))));

        #if STYLE_SKY_MODEL == 1
            float dayWeight = smoothstep(-0.02, 0.28, sunAltitude) * (1.0 - rainAmount);
            if (dayWeight > 0.001) {
                vec3 physical = atmosphericSky(skyElevation, cosSun, sunAltitude, 1.0 + GLEAM_HAZE * 0.6);
                physical = pow(max(physical * 8.0, vec3(0.0)), vec3(0.4545));
                float physicalWeight = dayWeight * mix(0.55, 1.0, smoothstep(0.0, 0.25, skyElevation));
                sky = mix(sky, physical, physicalWeight);
            }
        #endif

        float sunSideElevation = max(skyElevation, 0.0);
        vec3 horizontalView = nfragpos - upVector * skyElevation;
        vec3 horizontalSun = sunDir - upVector * sunAltitude;
        float azimuthCos = dot(horizontalView, horizontalSun) /
            max(length(horizontalView) * length(horizontalSun), 0.0001);

        float twilight = TWILIGHT_INTENSITY * STYLE_TWILIGHT *
            (1.0 - smoothstep(0.0, 0.45, abs(sunAltitude + 0.04))) * (1.0 - rainAmount);

        float horizonBand = exp(-sunSideElevation * 5.5);
        float sunSide = pow(clamp(azimuthCos * 0.5 + 0.5, 0.0, 1.0), 2.4);
        sky += HORIZON_SUNSET_COLOR * (sunSide * horizonBand * twilight * 0.62);

        float oppositeSide = pow(clamp(0.5 - azimuthCos * 0.5, 0.0, 1.0), 2.0);
        float beltHeight = smoothstep(0.0, 0.10, skyElevation) * (1.0 - smoothstep(0.10, 0.42, skyElevation));
        float beltAmount = twilight * (1.0 - smoothstep(-0.10, 0.10, sunAltitude));
        sky += vec3(0.72, 0.45, 0.58) * (oppositeSide * beltHeight * beltAmount * 0.20);

        #if GLEAM_COLOR_STYLE == 1
            float fantasyDay = smoothstep(0.05, 0.35, sunAltitude) * (1.0 - rainAmount) * DAY_SKY_ENHANCE;
            float zenithDeep = smoothstep(0.15, 0.85, skyElevation);
            sky *= mix(vec3(1.0), vec3(0.90, 0.96, 1.08), zenithDeep * fantasyDay * 0.8);
            float hazeGlow = exp(-sunSideElevation * 4.0);
            sky += vec3(0.55, 0.40, 0.90) * (hazeGlow * (1.0 - sunSide) * fantasyDay * 0.020);
        #endif

        #if GLEAM_COLOR_STYLE == 6
            float naturalDay = smoothstep(0.05, 0.35, sunAltitude) * (1.0 - rainAmount) * DAY_SKY_ENHANCE;
            sky = mix(sky, sky * vec3(0.96, 0.99, 1.04) + vec3(0.035, 0.050, 0.060), exp(-sunSideElevation * 3.5) * naturalDay * 0.6);
        #endif

        float sunVisibility = smoothstep(-0.16, 0.02, sunAltitude);
        float lowSun = 1.0 - smoothstep(0.05, 0.45, max(sunAltitude, 0.0));
        vec3 glowTint = mix(vec3(1.0, 0.90, 0.72), vec3(1.0, 0.58, 0.30), lowSun);

        float sunAngle = 3.0;
        float sunGlow = 0.0;
        if (cosSun > 0.0) {
            sunAngle = acos(clamp(cosSun, -1.0, 1.0));
            sunGlow = exp(-sunAngle * 9.0) * 0.50 + exp(-sunAngle * 3.2) * 0.22 + exp(-sunAngle * 1.1) * 0.06;
        }
        sunGlow += hgPhase(cosSun, 0.42) * 0.16;
        sunGlow = sunGlow / (1.0 + sunGlow * 0.55);

        float glowScale = SUN_GLOW * STYLE_SUN_GLOW * sunVisibility * (1.0 - rainAmount * 0.85) * (1.0 + 0.40 * lowSun);
        sky += glowTint * (sunGlow * glowScale * 0.44 * mix(1.0, SUNSET_GLOW, 1.0 - smoothstep(0.05, 0.45, max(sunAltitude, 0.0))));

        float moonFullness = abs(4.0 - float(MOON_PHASE_USED)) * 0.25;
        float moonVisibility = smoothstep(-0.10, 0.05, moonAltitude);
        float moonGlow = hgPhase(cosMoon, 0.60) * 0.08 + hgPhase(cosMoon, 0.30) * 0.05;
        float moonScale = MOON_GLOW * STYLE_MOON_GLOW * moonVisibility * (0.35 + 0.65 * moonFullness) *
            skyNightAmount() * (1.0 - rainAmount);
        #if GLEAM_NIGHT_LOOK == 2
            float moonAngle = acos(clamp(cosMoon, -1.0, 1.0));
            moonGlow += exp(-moonAngle * 11.0) * 0.17 + exp(-moonAngle * 4.2) * 0.075 + exp(-moonAngle * 1.6) * 0.022;
            moonGlow += (1.0 - smoothstep(0.0, 0.040, abs(moonAngle - 0.384))) * 0.014;
            moonGlow += (1.0 - smoothstep(0.0, 0.090, abs(moonAngle - 0.803))) * 0.0055;
        #endif
        sky += MOON_GLOW_COLOR * (moonGlow * moonScale * NIGHT_BRIGHT_PHASE);

        sky = mix(vec3(luma(sky)), sky, SKY_SATURATION);

        float nightTintAmount = clamp(skyNightAmount() * (1.0 - rainAmount) * NIGHT_SKY_GLOW, 0.0, 1.5);
        sky *= max(mix(vec3(1.0), NIGHT_SKY_MULT, nightTintAmount), vec3(0.0));
        fogSky = sky;
        fullSky = sky;

        float nightVisibility = smoothstep(0.25, 0.85, skyNightAmount()) * (1.0 - rainAmount);


        #if GLEAM_SUN_DISK == 1
            float diskAngle = sunAngle;
            if (sunDir.z < -0.05 && nfragpos.z < -0.05) {
                vec2 diskDelta = nfragpos.xy / -nfragpos.z - sunDir.xy / -sunDir.z;
                diskAngle = -sunDir.z * length(diskDelta);
            }

            float diskRadius = radians(STYLE_SUN_RADIUS) * SUN_SIZE;
            float diskEdge = 1.0 - smoothstep(diskRadius * 0.62, diskRadius * 1.18, diskAngle);
            float diskVisibility = smoothstep(-0.02, 0.03, sunAltitude) * (1.0 - rainAmount * 0.9);
            vec3 diskEdgeColor = mix(vec3(1.0, 0.92, 0.74), vec3(1.0, 0.60, 0.30), lowSun);
            vec3 diskColor = mix(vec3(1.0, 0.985, 0.95), diskEdgeColor, smoothstep(0.25, 1.0, diskAngle / diskRadius));
            fullSky += diskColor * (diskEdge * diskVisibility * 3.4 * SUN_DISK_BRIGHTNESS * STYLE_SUN_CORE);
        #endif

        #if GLEAM_SUN_HALO == 1
            if (cosSun > 0.55 && sunAltitude > -0.03) {
                float haloVisibility = smoothstep(-0.03, 0.22, sunAltitude) * (1.0 - rainAmount) * smoothstep(0.0, 0.10, skyElevation);
                fullSky += sunHaloLayer(sunAngle, worldDir, frameTimeCounter) * (haloVisibility * 0.17 * SUN_HALO_STRENGTH * STYLE_HALO_MULT);
            }
        #endif

        #if RAINBOW == 1
            float rainbowAmount = smoothstep(0.02, 0.10, sunAltitude) * (1.0 - smoothstep(0.55, 0.75, sunAltitude)) *
                smoothstep(0.0, 0.5, wetness) * (1.0 - rainAmount) * smoothstep(-0.02, 0.06, skyElevation);

            if (rainbowAmount > 0.001) {
                vec4 rainbow = rainbowArc(nfragpos, -sunDir);
                fullSky = mix(fullSky, rainbow.rgb * (luma(fullSky) * 1.5 + 0.10), rainbow.a * rainbowAmount * 0.6);
            }
        #endif

        #if GLEAM_MOON_DISK == 1
            fullSky += moonDiskLayer(nfragpos, moonDir, upVector, cosMoon, moonAltitude, skyElevation, rainAmount);
        #endif

        #if GLEAM_STARS == 1 || GLEAM_AURORA == 1 || GLEAM_SHOOTING == 1
            if (nightVisibility > 0.002 && skyElevation > -0.02) {
                float horizonFade = smoothstep(-0.02, 0.10, skyElevation);
                float pixelAngle = 2.0 * pixelSizeY * gbufferProjectionInverse[1].y;

                float auroraReveal = smoothstep(0.0, 1.0, AURORA_BIOME == 0 ? auroraBiomeFade : 1.0);
                vec3 nightLayer = nightSkyLayer(worldDir, pixelAngle, frameTimeCounter, auroraReveal);

                fullSky += nightLayer * (nightVisibility * horizonFade);
            }
        #endif
    #endif

    fogSky = clamp(fogSky, vec3(0.0), vec3(50.0));
    fullSky = clamp(fullSky, vec3(0.0), vec3(50.0));

    /* DRAWBUFFERS:167 */
    gl_FragData[0] = vec4(fullSky, 1.0);
    gl_FragData[1] = vec4(fullSky, 1.0);
    gl_FragData[2] = vec4(fogSky, 1.0);
}
