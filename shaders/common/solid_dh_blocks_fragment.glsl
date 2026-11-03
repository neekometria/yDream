#include "/lib/config.glsl"

uniform float dayNightMix;
uniform float nightVision;
uniform float rainStrength;
uniform float pixelSizeX;
uniform float pixelSizeY;
// The fog/sky colour is written by the prepare program into colortex7. In the
// gbuffers pass that buffer is also exposed as gaux4, but the DH programs have
// their own sampler namespace, so they must read colortex7 explicitly.
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
// Passed from light_vertex_dh.glsl: the sky visibility and a flag for materials
// whose light comes from the vertex shader (lava, illuminated blocks).
varying float dhVisibleSky;
varying float dhSpecialLight;

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

    // Recover the real face normal from the fragment position. DH does not
    // always provide vertex normals, and when it does not every face ends up
    // lit like an up-facing one, which is the main reason the LOD terrain looks
    // flat next to the real chunks. The screenspace derivatives give exact
    // per-face normals for the voxel LOD geometry. This runs before the discard
    // so the derivatives are still valid across the whole 2x2 quad.
    #if DH_TERRAIN_NORMALS == 1
    vec3 geoCross = cross(dFdx(position.xyz), dFdy(position.xyz));
    float geoLength = length(geoCross);
    vec3 geoNormal = geoLength > 1e-8 ? geoCross / geoLength : vec3(0.0, 1.0, 0.0);

    // Visible faces must point towards the camera. position.xyz goes from
    // the camera to the fragment, so a positive dot means the normal is
    // flipped and has to be inverted.
    if (dot(geoNormal, position.xyz) > 0.0) {
        geoNormal = -geoNormal;
    }
    #endif

    float t = far - dhNearPlane;
    float inf = t * TRANSITION_DH_INF;
    float visibleDistance = length(position.xyz);
    if(visibleDistance < dhNearPlane + inf) {
        discard;
        return;
    }

    vec4 blockColor = tintColor;

    vec3 synthesisPosition = (position.xyz + cameraPosition) * 6.0;
    synthesisPosition = floor(synthesisPosition + 0.01);
    float syntheticNoise = (hash13(synthesisPosition) - 0.5) * 0.1;
    blockColor.rgb += vec3(syntheticNoise);
    blockColor.rgb = clamp(blockColor.rgb, vec3(0.0), vec3(1.0));

    vec3 finalCandleColor = candleColor;

    float directStrength = directLightStrength;

    #if DH_TERRAIN_NORMALS == 1 && !defined NETHER && !defined THE_END
        // Reproduce the light_vertex_dh.glsl directional term with the exact
        // fragment normal instead of the (often missing) vertex normal.
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

    // Lava and illuminated blocks keep the vertex-shader override.
    if (dhSpecialLight < 0.5) {
        directStrength = geoStrength;
    }
    #endif

    // Cloud shadows on the LOD terrain. The real chunks get the same pattern in
    // their vertex stage, so a cloud bank darkens near and far terrain together
    // instead of stopping at the LOD transition.
    #if defined CLOUD_SHADOWS_ON && DH_CLOUD_SHADOWS == 1 && !defined NETHER && !defined THE_END
        if (dhSpecialLight < 0.5) {
            // sunPosition is view-space: convert to world-space before projecting
            // the cloud shadow on the ground, otherwise the shadow rotates with
            // the camera and never matches the clouds drawn in the sky.
            vec3 sunDirWorld = normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
            vec3 cloudLightDir = sunDirWorld * mix(-1.0, 1.0, step(0.5, dayNightMix));
            directStrength *= 1.0 - cloud_shadow_amount(position.xyz + cameraPosition, cloudLightDir);
        }
    #endif

    float shadowValue = abs((dayNightMix * 2.0) - 1.0);

    #if DH_SHADOWS == 1 && defined SHADOW_CASTING && !defined NETHER
        // The LODs are not rendered into the shadow map, but they can still
        // receive the shadows cast by the real chunks around the player. This
        // is what makes the near LODs sit in the same sunlight as the real
        // terrain. The range is clamped to the shadow map coverage and faded
        // out at its edge so no hard cutoff appears.
    float dhShadowRange = min(float(DH_SHADOW_DISTANCE), shadowDistance);
    float shadowFade = 1.0 - smoothstep(dhShadowRange * 0.75, dhShadowRange, visibleDistance);
    if (shadowFade > 0.001 && directStrength > 0.002) {
        float nightShadowAmount = 1.0 - smoothstep(0.0, 0.35, dayNightMix);
        vec3 shadowPosition = position.xyz;
            #if DH_TERRAIN_NORMALS == 1
            // Nudge the sample off the surface. The real chunks around the
            // LOD are in the shadow map; without a small bias the shared
            // boundary can pick up shadow acne.
        shadowPosition += geoNormal * 0.06;
            #endif
        float shadowSample = get_shadow(get_shadow_pos(shadowPosition), dither);
        shadowSample = mix(shadowSample, 1.0, nightShadowAmount * NIGHT_SHADOW_SOFTEN);
        shadowValue = mix(1.0, shadowSample, shadowFade);
    }
    #endif

    vec3 realLight =
        omniLight +
        (shadowValue * directLightColor * directStrength) * (1.0 - (rainStrength * 0.55)) +
        finalCandleColor;

    blockColor.rgb *= mix(realLight, vec3(1.0), nightVision * 0.125);
    blockColor.rgb *= mix(vec3(1.0, 1.0, 1.0), vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B), nightVision);

    #if DH_COLOR_MATCH == 1
        // DH stores a single averaged palette colour per LOD cell, which is
        // brighter and more saturated than the textured real terrain. Pull it
        // towards its own luminance and dim it slightly so the transition is
        // much harder to spot.
    float dhAlbedoLuma = luma(blockColor.rgb);
    blockColor.rgb = mix(blockColor.rgb, vec3(dhAlbedoLuma), DH_COLOR_DESATURATE);
    blockColor.rgb *= DH_COLOR_BRIGHTNESS;
    #endif

    blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));

    #include "/src/finalcolor_dh.glsl"
    #include "/src/writebuffers.glsl"
}
