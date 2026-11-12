#include "/lib/config.glsl"

uniform float dayNightMix;
uniform float nightVision;
uniform float rainStrength;
uniform float pixelSizeX;
uniform float pixelSizeY;
uniform sampler2D colortex7;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform float far;
uniform vec3 cameraPosition;
uniform int dhRenderDistance;

uniform int isEyeInWater;
uniform float blindness;

#if DH_TERRAIN_NORMALS == 1 && !defined NETHER && !defined THE_END
uniform vec3 sunPosition;
uniform mat4 gbufferModelView;
#endif

#if defined CLOUD_SHADOWS_ON && DH_CLOUD_SHADOWS == 1 && !defined NETHER && !defined THE_END
uniform sampler2D gaux2;
uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;
    #if DH_TERRAIN_NORMALS != 1
uniform vec3 sunPosition;
    #endif
#endif

#if DH_SHADOWS == 1 && defined SHADOW_CASTING && !defined NETHER
// lib/shadow_frag.glsl usa shadowtex0/shadowcolor0 nos detectores de sombra;
// sem estas declarações o dh_terrain falha com "undefined variable".
uniform sampler2DShadow shadowtex0;
uniform sampler2D shadowcolor0;
uniform sampler2DShadow shadowtex1;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
#endif

#if MC_VERSION >= 11900
uniform float darknessFactor;
uniform float darknessLightFactor;
#endif

#ifdef NETHER
uniform vec3 fogColor;
#endif

varying vec2 texcoord;
varying vec4 tintColor;
varying vec3 directLightColor;
varying vec3 candleColor;
varying float directLightStrength;
varying vec3 omniLight;
varying vec4 position;
varying float frogAdjust;
varying float fogSunScatter;
varying float dhVisibleSky;
varying float dhSpecialLight;
varying float terrainWorldY;

#include "/lib/luma.glsl"
#include "/lib/dither.glsl"
#include "/lib/fog_blend.glsl"

#if defined CLOUD_SHADOWS_ON && DH_CLOUD_SHADOWS == 1 && !defined NETHER && !defined THE_END
    #include "/lib/cloud_shadow.glsl"
#endif

#if DH_SHADOWS == 1 && defined SHADOW_CASTING && !defined NETHER
    #include "/lib/shadow_vertex.glsl"
    #include "/lib/shadow_frag.glsl"
#endif

void main() {
    #if AA_TYPE > 0
    float dither = shiftedRDither(gl_FragCoord.xy);
    #else
    float dither = rDither(gl_FragCoord.xy);
    #endif

    #if DH_TERRAIN_NORMALS == 1
    vec3 geoCross = cross(dFdx(position.xyz), dFdy(position.xyz));
    float geoLength = length(geoCross);
    vec3 geoNormal = geoLength > 1e-8 ? geoCross / geoLength : vec3(0.0, 1.0, 0.0);

    if (dot(geoNormal, position.xyz) > 0.0) {
        geoNormal = -geoNormal;
    }
    #endif

    // Quando dhNearPlane >= far (override de altitude do DH) nao existe janela de
    // crossfade. Clampar o span em zero evita threshold negativo/instavel e deixa
    // o proprio near plane do DH cuidar do corte.
    float dhSpan = max(far - dhNearPlane, 0.0);
    float inf = dhSpan * TRANSITION_DH_INF;
    float visibleDistance = length(position.xyz);
    if(visibleDistance < dhNearPlane + inf) {
        discard;
        return;
    }

    // Pega a altura do bloco e calcula a chuva para ele
    float dhWorldY = position.xyz.y + cameraPosition.y;
    float terrainRain = getTerrainRain(dhWorldY);

    vec4 blockColor = tintColor;

    vec3 synthesisPosition = (position.xyz + cameraPosition) * 6.0;
    synthesisPosition = floor(synthesisPosition + 0.01);

    float syntheticNoise = (hash13(synthesisPosition) - 0.5) * 0.1;
    syntheticNoise *= terrainRain; // Remove o ruído se o bloco estiver acima das nuvens
    blockColor.rgb += vec3(syntheticNoise);
    blockColor.rgb = clamp(blockColor.rgb, vec3(0.0), vec3(1.0));

    vec3 finalCandleColor = candleColor;

    float directStrength = directLightStrength;

    #if DH_TERRAIN_NORMALS == 1 && !defined NETHER && !defined THE_END
    vec3 viewNormal = normalize(mat3(gbufferModelView) * geoNormal);
    vec3 astroVector = normalize(sunPosition);
    float astroStrength = dot(viewNormal, astroVector);
    float geoStrength = clamp(mix(-astroStrength, astroStrength, dayNightMix), 0.0, 1.0);

    if (isEyeInWater == 0) {
        float visSky2 = dhVisibleSky * dhVisibleSky;
        float visSky4 = visSky2 * visSky2;
        float visSky8 = visSky4 * visSky4;
        geoStrength *= visSky8 * visSky2;
    } else {
        geoStrength *= dhVisibleSky;
    }

    if (dhSpecialLight < 0.5) {
        directStrength = geoStrength;
    }
    #endif

    #if defined CLOUD_SHADOWS_ON && DH_CLOUD_SHADOWS == 1 && !defined NETHER && !defined THE_END
        if (dhSpecialLight < 0.5) {
            vec3 sunDirWorld = normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
            vec3 cloudLightDir = sunDirWorld * mix(-1.0, 1.0, step(0.5, dayNightMix));
            directStrength *= 1.0 - cloud_shadow_amount(position.xyz + cameraPosition, cloudLightDir);
        }
    #endif

    float shadowValue = abs((dayNightMix * 2.0) - 1.0);

    #if DH_SHADOWS == 1 && defined SHADOW_CASTING && !defined NETHER
    float dhShadowRange = min(float(DH_SHADOW_DISTANCE), shadowDistance);
    float shadowFade = 1.0 - smoothstep(dhShadowRange * 0.75, dhShadowRange, visibleDistance);
    if (shadowFade > 0.001 && directStrength > 0.002) {
        float nightShadowAmount = 1.0 - smoothstep(0.0, 0.35, dayNightMix);
        vec3 shadowPosition = position.xyz;
            #if DH_TERRAIN_NORMALS == 1
        // O bias do vanilla cresce com a distancia. Sem isso a pegada de um texel
        // do shadow map fica maior que o bias no LOD distante e aparecem blocos
        // de auto-sombra falsa no chao.
        float dhBias = min(SHADOW_FIX_FACTOR + visibleDistance * 0.005, 0.5);
        shadowPosition += geoNormal * max(DH_SHADOW_NORMAL_BIAS, dhBias);
            #endif
        vec3 shadowUV = get_shadow_pos(shadowPosition);
        // Mesmo fade de borda do terreno vanilla (shadowDiffuse). Fora do frustum
        // do shadow map a amostra e clampada/repetida e viraria sombra falsa em
        // blocos. Fade para 1 (iluminado) nas bordas.
        float shadowEdge = length(shadowUV.xy * 2.0 - 1.0);
        shadowEdge = clamp(pow(shadowEdge, 10.0), 0.0, 1.0);
        float shadowSample = get_shadow(shadowUV, dither);
        shadowSample = mix(shadowSample, 1.0, shadowEdge);
        shadowSample = mix(shadowSample, 1.0, nightShadowAmount * NIGHT_SHADOW_SOFTEN);
        // DH_SHADOW_STRENGTH é graduado pela distância: perto do jogador (e do
        // terreno LOD próximo) a sombra fica 100%; longe, onde as montanhas LOD
        // escondidas pela névoa projetam as sombras longas, a força é reduzida.
        float dhShadowStrength = mix(1.0, DH_SHADOW_STRENGTH, smoothstep(48.0, float(int(shadowDistance)), visibleDistance));
        shadowSample = mix(1.0, shadowSample, dhShadowStrength);
        shadowValue = mix(1.0, shadowSample, shadowFade);
    }
    #endif

    vec3 realLight =
        omniLight +
        (shadowValue * directLightColor * directStrength) * (1.0 - (terrainRain * 0.55)) +
        finalCandleColor;

    blockColor.rgb *= mix(realLight, vec3(1.0), nightVision * 0.125);
    blockColor.rgb *= mix(vec3(1.0, 1.0, 1.0), vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B), nightVision);

    #if DH_COLOR_MATCH == 1
    float dhAlbedoLuma = luma(blockColor.rgb);
    blockColor.rgb = mix(blockColor.rgb, vec3(dhAlbedoLuma), DH_COLOR_DESATURATE);
    blockColor.rgb *= DH_COLOR_BRIGHTNESS;
    #endif

    blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));

    // Correção da Fog ao olhar de cima para baixo (Específico para DH)
    #if !defined THE_END && !defined NETHER
        float blockY = position.xyz.y + cameraPosition.y;

        if (cameraPosition.y > CLOUD_PLANE_SUP && blockY < CLOUD_PLANE) {
            // Em vez de ler colortex7 (que pode falhar no DH), 
            // usamos uma cor de névoa de chuva fixa e escura.
            vec3 rainFog = ZENITH_SKY_RAIN_COLOR * 0.35;
            
            // Escurece o terreno também para não parecer que está no sol
            blockColor.rgb *= 0.4;
            
            blockColor.rgb = mix(blockColor.rgb, rainFog, frogAdjust);
        }
    #endif

    #include "/src/finalcolor_dh.glsl"
    #include "/src/writebuffers.glsl"
}