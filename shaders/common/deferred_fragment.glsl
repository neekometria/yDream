#include "/lib/config.glsl"
#ifdef THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

uniform sampler2D colortex1;
uniform ivec2 eyeBrightnessSmooth;
uniform int isEyeInWater;
uniform sampler2D depthtex0;
uniform float far;
uniform float near;
uniform float blindness;
uniform float rainStrength;
uniform int frameCounter;

#if V_CLOUDS != 0
    uniform sampler2D gaux2;
#endif

#if AO == 1
    uniform float aspectRatioInverse;
    uniform float fovYInverse;
#endif

#if V_CLOUDS != 0 && !defined UNKNOWN_DIM
    uniform sampler2D noisetex;
    uniform vec3 cameraPosition;
    uniform vec3 sunPosition;
#elif YDREAM_VOXEL_LIGHT > 0
    uniform vec3 cameraPosition;
#endif

#ifdef YDREAM_LIGHT_BUFFERS
    uniform sampler2D colortex9;
#endif

#if YDREAM_VOXEL_LIGHT > 0
    uniform sampler2D colortex8;
#endif

#if defined DISTANT_HORIZONS
    uniform sampler2D dhDepthTex0;
    uniform float dhNearPlane;
    uniform float dhFarPlane;
    uniform mat4 dhProjectionInverse;
#endif

#if defined DISTANT_HORIZONS && V_CLOUDS != 0 && !defined UNKNOWN_DIM
    uniform float viewWidth;
    uniform float viewHeight;
#endif

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform float pixelSizeX;
uniform float pixelSizeY;



#if AA_TYPE > 0
    uniform vec2 taaOffset;
#endif

#if AO == 1 || (V_CLOUDS != 0 && !defined UNKNOWN_DIM) || defined YDREAM_SS_ANY
    uniform mat4 gbufferProjection;
    uniform float frameTimeCounter;
    uniform sampler2D colortex2;
#endif

varying vec2 texcoord;
varying vec3 upVector;

#if (V_CLOUDS != 0 && !defined UNKNOWN_DIM) && !defined NO_CLOUDY_SKY
    varying float umbral;
    varying vec3 cloudColor;
    varying vec3 darkCloudColor;
    varying float cloudLightSign;
#endif

#if AO == 1
    varying float fogDensityCoeff;
#endif

#include "/lib/depth.glsl"
#include "/lib/luma.glsl"

#ifdef DISTANT_HORIZONS
    #include "/lib/depth_dh.glsl"
#endif

#if AO == 1 || (V_CLOUDS != 0 && !defined UNKNOWN_DIM) || defined YDREAM_SS_ANY
    #include "/lib/dither.glsl"
#endif

#if AO == 1
    #include "/lib/ao.glsl"
#endif

#ifdef YDREAM_SS_ANY
    #include "/lib/screen_light.glsl"
#endif

#if (V_CLOUDS != 0 && !defined UNKNOWN_DIM)
    #include "/lib/projection_utils.glsl"

    #ifndef THE_END
        #include "/lib/volumetric_clouds.glsl"
    #endif
#endif


void main() {
    vec4 blockColor = texture2DLod(colortex1, texcoord, 0);
    float depth = texture2DLod(depthtex0, texcoord, 0).r;
    float linearDepth = ld(depth);

    // Amount of cloud composited over the scene. Stored in colortex6 so the
    // translucent water (drawn after this pass) can fade by the real opacity.
    // colortex5 is not usable here: it is aliased to the custom cloud-noise
    // texture bound as gaux2 in this same pass.
    float cloudCoverage = 0.0;

    vec2 eyeBrightSmoothFloat = vec2(eyeBrightnessSmooth);

    vec3 eyeDirection = vec3(1.0);

    #if AO == 1 || (V_CLOUDS != 0 && !defined UNKNOWN_DIM) || defined YDREAM_SS_ANY
        #if AA_TYPE > 0
            float dither = shiftedSemiblue(gl_FragCoord.xy);
        #else
            float dither = semiblue(gl_FragCoord.xy);
        #endif
    #endif

    #if (V_CLOUDS != 0 && !defined UNKNOWN_DIM) && !defined NO_CLOUDY_SKY
        {
            vec2 sampleNdc = texcoord * 2.0 - 1.0;
            #if AA_TYPE > 0
                sampleNdc -= taaOffset;
            #endif

            vec4 farPlaneClipPos = gbufferModelViewInverse * gbufferProjectionInverse * vec4(sampleNdc, 1.0, 1.0);
            eyeDirection = normalize(farPlaneClipPos.xyz);

            // Distance to the visible surface along this ray (sky = unlimited).
            float sceneDist = 1e9;
            if (linearDepth <= 0.9999) {
                vec4 scenePos = gbufferProjectionInverse * vec4(sampleNdc, depth * 2.0 - 1.0, 1.0);
                sceneDist = length(scenePos.xyz / scenePos.w);
            }

            #ifdef DISTANT_HORIZONS
                float dhDepth = texture2DLod(dhDepthTex0, texcoord, 0.0).r;
                if (dhDepth < 0.999999) {
                    vec4 dhPosition = dhProjectionInverse * vec4(sampleNdc, dhDepth * 2.0 - 1.0, 1.0);
                    if (abs(dhPosition.w) > 0.000001) {
                        sceneDist = min(sceneDist, length(dhPosition.xyz / dhPosition.w));
                    }
                }
            #endif

            #ifdef THE_END
                float bright = dot(eyeDirection, vec3(0.0, 0.89442719, 0.4472136));
                bright = clamp((bright * 2.0) - 1.0, 0.0, 1.0);
                bright *= bright * bright * bright;
            #else
                float bright = dot(eyeDirection, normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz));
                bright = clamp(bright * bright * bright, 0.0, 1.0);
            #endif

            #ifndef THE_END
                if (isEyeInWater == 0) {
                    vec3 cloudLightDir = normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz) * cloudLightSign;

                    // Calcula o fade da atmosfera baseado na altitude
                    float atmosphereFade = 1.0;
                    #if defined ATMOSPHERE_LAYER
                        float atmosphereAltitude = max(cameraPosition.y, 0.0);
                        float atmosphereLayer = smoothstep(float(ATMOSPHERE_START), float(ATMOSPHERE_END), atmosphereAltitude);
                        atmosphereLayer = pow(atmosphereLayer, max(ATMOSPHERE_DENSITY, 0.001));
                        atmosphereFade = mix(1.0, 0.05, atmosphereLayer);
                    #endif

                    #if !defined NORTHSTAR_CLOUDS_OFF
                        float northstarCloudUmbral = umbral;
                        #if defined NORTHSTAR_MARS
                            // Mars' clouds are thin and high: low density means a higher noise cutoff.
                            northstarCloudUmbral = max(umbral, 0.84 - 0.34 * clamp(NORTHSTAR_MARS_CLOUD_DENSITY, 0.05, 0.50));
                        #endif
                        blockColor.rgb = get_cloud(eyeDirection, blockColor.rgb, bright, dither, cameraPosition, CLOUD_STEPS_AVG, northstarCloudUmbral, cloudColor, darkCloudColor, cloudLightDir, sceneDist, atmosphereFade, cloudCoverage);
                    #endif
                }
            #endif
        }

    #else
        #if defined NETHER
            // The Nether sky and stars come from prepare; keep them.
        #elif !defined NETHER && !defined THE_END
            if(linearDepth > 0.9999 && isEyeInWater == 1) {
                vec4 screen_pos = vec4(gl_FragCoord.xy * vec2(pixelSizeX, pixelSizeY), gl_FragCoord.z, 1.0);
                vec4 fragposition = gbufferProjectionInverse * (screen_pos * 2.0 - 1.0);

                vec4 farPlaneClipPos = gbufferModelViewInverse * vec4(fragposition.xyz, 0.0);
                eyeDirection = normalize(farPlaneClipPos.xyz);
            }
        #endif
    #endif

    #if YDREAM_VOXEL_LIGHT > 0
        vec3 colorLightSurface = vec3(0.0);
        vec3 colorLightGlow = vec3(0.0);
    #endif

    #ifdef YDREAM_SS_ANY
        if (linearDepth < 0.9999 && depth > 0.56) {
            vec3 slOriginal = blockColor.rgb;
            vec3 vlFieldDebug = vec3(0.0);

            #if YDREAM_VOXEL_LIGHT > 0
                colorLightSurface = vlApply(blockColor.rgb, texcoord, slViewPos(texcoord, depth), vlFieldDebug) - blockColor.rgb;
            #endif

            #if SS_DEBUG == 2 && YDREAM_VOXEL_LIGHT > 0
                blockColor.rgb = abs(colorLightSurface) * 10.0;
                colorLightSurface = vec3(0.0);
            #elif SS_DEBUG == 3 && YDREAM_VOXEL_LIGHT > 0
                blockColor.rgb = texture2DLod(colortex2, texcoord, 0.0).rgb;
            #elif SS_DEBUG == 4 && YDREAM_VOXEL_LIGHT > 0
                blockColor.rgb = vlFieldDebug;
            #endif
        }
    #endif

    #ifdef YDREAM_VL_GLOW
        if (depth > 0.56) {
            colorLightGlow = vlGlow(texcoord, depth, fract(fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715)))) + float(frameCounter) * 0.6180339887));
        }
    #endif

    #if AO == 1

        #if defined NETHER
            if(NETHER_FOG_DISTANCE == 0) {
                linearDepth = sqrt(linearDepth);
            } else {
                float screen_distance = 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
                linearDepth = screen_distance / NETHER_SIGHT;
            }
        #endif
        float ao_att =
            pow(clamp(linearDepth * 1.6, 0.0, 1.0), mix(fogDensityCoeff, 1.0, rainStrength));

        float final_ao = 1.0;
        if (ao_att < 0.999) {
            final_ao = mix(dbao(dither), 1.0, ao_att);
        }

        // Desliga o AO se a câmera estiver dentro da camada de nuvens
        float inCloudLayer = smoothstep(CLOUD_PLANE - 10.0, CLOUD_PLANE + 10.0, cameraPosition.y) * 
                            (1.0 - smoothstep(CLOUD_PLANE_SUP - 10.0, CLOUD_PLANE_SUP + 10.0, cameraPosition.y));
        final_ao = mix(final_ao, 1.0, inCloudLayer);

        blockColor.rgb *= final_ao;
        #if YDREAM_VOXEL_LIGHT > 0
            colorLightSurface *= final_ao;
        #endif
    #endif

    if(isEyeInWater == 1) {
        if(linearDepth > 0.9999) {
            vec3 waterSkyLight = dayBlend(LIGHT_SUNSET_COLOR, LIGHT_DAY_COLOR, LIGHT_NIGHT_COLOR);
            vec3 underwaterSky = underwaterFogColor(waterSkyLight, eyeBrightSmoothFloat.y * 0.004166666666666667);
            float windowMix = max(smoothstep(0.30, 0.78, eyeDirection.y), rainStrength * 0.6);
            vec3 windowSky = blockColor.rgb * vec3(0.60, 0.84, 1.0);

            blockColor.rgb = mix(underwaterSky, windowSky, windowMix);
        }
    }

    blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));

    #if YDREAM_VOXEL_LIGHT > 0
        vec4 colorLightOut = vec4(0.0);

        if (depth > 0.56) {
            float colorLightDistance = 220.0;

            if (depth < 0.99999) {
                colorLightDistance = length(slViewPos(texcoord, depth));
            }

            colorLightOut = vec4(clamp(colorLightSurface + colorLightGlow, vec3(-4.0), vec3(8.0)), colorLightDistance);
        }

        /* RENDERTARGETS: 1,4,6,12 */
        gl_FragData[0] = vec4(blockColor.rgb, depth);
        gl_FragData[1] = blockColor;
        gl_FragData[2] = vec4(cloudCoverage, 0.0, 0.0, 1.0);
        gl_FragData[3] = colorLightOut;
    #else
        /* DRAWBUFFERS:146 */
        gl_FragData[0] = vec4(blockColor.rgb, depth);
        gl_FragData[1] = blockColor;
        gl_FragData[2] = vec4(cloudCoverage, 0.0, 0.0, 1.0);
    #endif
}
