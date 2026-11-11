#ifndef DH_WATER_F
    #define DH_WATER_F
#endif

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
uniform sampler2D colortex4;
uniform sampler2D colortex7;
#define gaux1 colortex4
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D dhDepthTex1;
uniform float frameTimeCounter;
uniform int isEyeInWater;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int worldTime;
uniform float nightVision;
uniform float rainStrength;
uniform float dayNightMix;
uniform ivec2 eyeBrightnessSmooth;
uniform float viewWidth;
uniform float viewHeight;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform int dhRenderDistance;

#if defined SHADOW_CASTING && !defined NETHER
uniform sampler2DShadow shadowtex1;
    #if defined COLORED_SHADOW
uniform sampler2DShadow shadowtex0;
uniform sampler2D shadowcolor0;
    #endif
#endif

uniform float blindness;

#if MC_VERSION >= 11900
uniform float darknessFactor;
uniform float darknessLightFactor;
#endif

varying vec2 texcoord;
varying vec4 tintColor;
varying vec3 directLightColor;
varying vec3 candleColor;
varying float directLightStrength;
varying vec3 omniLight;
varying vec4 position;
varying vec3 fragposition;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 waterNormal;
varying vec3 zenithSkyColor;
varying vec3 horizonSkyColor;
varying vec3 upVector;
varying float visibleSky;
varying vec2 lmcoord;
varying float blockType;
varying float frogAdjust;
varying float fogSunScatter;

#include "/lib/projection_utils.glsl"
#include "/lib/basic_utils.glsl"
#include "/lib/dither.glsl"
#include "/lib/water_dh.glsl"
#include "/lib/depth.glsl"
#include "/lib/luma.glsl"
#include "/lib/fog_blend.glsl"

#if (V_CLOUDS != 0 && !defined UNKNOWN_DIM) && !defined NO_CLOUDY_SKY
uniform sampler2D gaux2;
    #include "/lib/cloud_noise.glsl"

float dh_water_cloud_coverage(vec3 waterPos) {
    vec3 ray = waterPos - cameraPosition;
    if (ray.y > -0.001) {
        return 0.0;
    }

    if (cameraPosition.y > CLOUD_PLANE && cameraPosition.y < CLOUD_PLANE_SUP) {
        float camField = cloud_field(cameraPosition.xz);
        if (camField > 0.4) {
            return 1.0;
        }
    }

    float coverage = 0.0;
    const int WATER_CLOUD_SAMPLES = 8;
    for (int i = 0; i < WATER_CLOUD_SAMPLES; i++) {
        float height = mix(CLOUD_PLANE + 4.0, CLOUD_PLANE_SUP - 4.0,
                           (float(i) + 0.5) / float(WATER_CLOUD_SAMPLES));
        float tRay = (height - cameraPosition.y) / ray.y;
        if (tRay > 0.0 && tRay < 1.0) {
            vec3 samplePos = cameraPosition + ray * tRay;
            float detailNoise = texture2D(gaux2,
                (samplePos.xz * 0.0016) - (frameTimeCounter * CLOUD_HI_FACTOR * 1.6)).r;
            float fieldValue = mix(cloud_field(samplePos.xz), detailNoise, CLOUD_DETAIL_WEIGHT);
            
            // Proteção contra NaN
            if (fieldValue != fieldValue) fieldValue = 0.0;
            
            coverage = max(coverage, smoothstep(0.1, 0.3, fieldValue));
        }
    }
    return coverage;
}
#endif


void main() {
    vec2 eyeBrightSmoothFloat = vec2(eyeBrightnessSmooth);
    vec3 realLight;
    #if AA_TYPE > 0
    float dither = shiftedRDither(gl_FragCoord.xy);
    #else
    float dither = rDither(gl_FragCoord.xy);
    #endif

    float dhSpan = far - dhNearPlane;
    // Mesma distancia que a agua vanilla usa no gl_FogFragCoord (view-space).
    // Precisa bater exatamente para o dither complementar nao deixar costura.
    // Obs.: nao usar `position` aqui porque a agua DH aplica position.y -= 0.125.
    float fogDistance = length(fragposition.xyz);

    // O depthtex0 contem a cena opaca principal (pode ser a frame anterior no
    // passe DH, mas serve de aproximacao). O check antigo (`linearDepth < 0.9999`)
    // descartava a agua DH sempre que existia QUALQUER geometria opaca no pixel,
    // inclusive o leito atras da superficie. No anel de transicao a agua vanilla
    // ja foi removida pelo dither, entao sobrava um buraco mostrando o LOD do DH.
    // Com a comparacao correta (cena NA FRENTE da agua) a tolerancia pode ser
    // pequena: 0.5 bloco deixava a agua DH desenhar por cima de terreno vanilla
    // fino, e a borda do LOD aparecia "atraves" da agua e do terreno.
    float d = texture2DLod(depthtex0, vec2(gl_FragCoord.x / viewWidth, gl_FragCoord.y / viewHeight), 0.0).r;
    float linearDepth = ld(d);
    if(linearDepth < 0.9999) {
        float sceneViewDepth = linearDepth * far / max(2.0 - linearDepth, 1e-4);
        float waterViewDepth = abs(fragposition.z);
        if(sceneViewDepth < waterViewDepth - max(0.05, waterViewDepth * 0.02)) {
            discard;
            return;
        }
    }

    // Crossfade complementar ao da agua vanilla (water_blocks_fragment.glsl):
    // a vanilla desenha quando draw_umbral <= dither, entao a agua DH so pode
    // desenhar quando draw_umbral > dither. Assim cada pixel e coberto por
    // exatamente uma das duas superficies (sem double-blend e sem buracos).
    if(dhRenderDistance > 0 && dhNearPlane > 0.0 && dhSpan > 1.0) {
        float sup = dhSpan * TRANSITION_DH_SUP;
        float inf = dhSpan * TRANSITION_DH_INF;
        float fadeSpan = max(far - sup - inf - dhNearPlane, 1.0);
        float dhUmbral = (fogDistance - (dhNearPlane + inf)) / fadeSpan;
        if(dhUmbral <= dither) {
            discard;
            return;
        }
    } else if(fogDistance < dhNearPlane) {
        // Sem janela de crossfade o near plane do DH ja cuida do corte.
        discard;
        return;
    }

    // NÃO descartar back-face aqui: o DH entrega as faces da água com winding
    // não garantido; descartar !gl_FrontFacing esconde a água DH inteira.
    // A face vista de baixo continua necessária para a janela de Snell.

    #ifdef VANILLA_WATER
    vec3 waterNormalBase = vec3(0.0, 0.0, 1.0);
    #else
    vec3 mapPos = position.xyz + cameraPosition;
    vec3 waterNormalBase = normal_waves_dh(mapPos.xzy);
    #endif

    vec3 surfaceNormal;
    if(blockType < DH_BLOCK_WATER + 0.5 && blockType > DH_BLOCK_WATER - 0.5) {
        surfaceNormal = get_normals(waterNormalBase, fragposition);
        // Acima da água a face de trás (winding invertido no DH) espelha a
        // normal, senão o reflexo sai para o lado errado.
        if (isEyeInWater == 0 && !gl_FrontFacing) surfaceNormal = -surfaceNormal;
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

    
    #if !defined VANILLA_WATER && WATER_TEXTURE == 1
    vec4 blockColor = vec4(0.1);

    vec3 synthesisPosition = (position.xyz + cameraPosition) * 8.0;
    synthesisPosition = floor(synthesisPosition + 0.01);
    float noise = hash13(synthesisPosition);
    noise *= noise;
    noise *= noise;
    noise *= noise;
    float syntheticNoise = (noise * 0.3) + 0.5;
    blockColor.rgb += vec3(syntheticNoise);
    #elif defined VANILLA_WATER
    // Mesma amostra do atlas do caminho Vanilla: cor e alfa vêm da textura.
    vec4 blockColor = texture2D(tex, texcoord);
    #else
    vec4 blockColor;
    #endif

    if(blockType < DH_BLOCK_WATER + 0.5 && blockType > DH_BLOCK_WATER - 0.5) {
    #ifdef VANILLA_WATER
        float shadowValue = abs((dayNightMix * 2.0) - 1.0);

        float fresnelTex = luma(blockColor.rgb);

        realLight = omniLight +
            (directLightStrength * shadowValue * directLightColor) * (1.0 - rainStrength * 0.55) +
            candleColor;

        realLight *= (fresnelTex * 2.0) - 0.25;

        blockColor.rgb *= mix(realLight, vec3(1.0), nightVision * .125) * tintColor.rgb;

        blockColor.rgb = water_shader_dh(fragposition, surfaceNormal, blockColor.rgb, skyColorReflect, normalizedReflectWaterVector, fresnel, visibleSky, dither, directLightColor);
        blockColor.a = 1.0; // Alfa 1: a refracao ja inclui o fundo; alfa da textura vazaria o cenario nao refratado.
    #else
        #if WATER_TEXTURE == 1
        float waterTexture = luma(blockColor.rgb);
        #else
        float waterTexture = 1.0;
        #endif

        realLight = omniLight +
            (directLightStrength * visibleSky * directLightColor) * (1.0 - rainStrength * 0.55) +
            candleColor;

        #if WATER_COLOR_SOURCE == 0
        blockColor.rgb = waterTexture * realLight * WATER_COLOR;
        #elif WATER_COLOR_SOURCE == 1
        blockColor.rgb = 0.3 * waterTexture * realLight * tintColor.rgb;
        #endif


        #if WATER_TEXTURE == 1
        fresnel = clamp(fresnel * (waterTexture * waterTexture + 0.5), 0.0, 1.0);
        #endif

        blockColor.rgb = water_shader_dh(fragposition, surfaceNormal, blockColor.rgb, skyColorReflect, normalizedReflectWaterVector, fresnel, visibleSky, dither, directLightColor);
        // blockColor é declarado sem inicialização neste ramo: sem alfa
        // definido o blend do dh_water usa lixo e a água some. O reflexo
        // inline já embute o fundo, então a superfície é opaca.
        blockColor.a = 1.0;
    #endif

    } else {

        blockColor = tintColor;

        float shadowValue = abs((dayNightMix * 2.0) - 1.0);

        realLight = omniLight +
            (directLightStrength * shadowValue * directLightColor) * (1.0 - getAltitudeRain() * 0.55) +
            candleColor;

        blockColor.rgb *= mix(realLight, vec3(1.0), nightVision * .125);
    }

    #if !defined NETHER && !defined THE_END
        if (isEyeInWater == 1 &&
            blockType < DH_BLOCK_WATER + 0.5 && blockType > DH_BLOCK_WATER - 0.5) {
            blockColor.a = 1.0;
        }
    #endif

    #include "/src/finalcolor_dh.glsl"
    #include "/src/writebuffers.glsl"
}