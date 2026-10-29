#include "/lib/config.glsl"

uniform float dayNightMix;
uniform float nightVision;
uniform float rainStrength;
uniform float pixelSizeX;
uniform float pixelSizeY;
uniform sampler2D gaux4;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform float far;
uniform vec3 cameraPosition;
uniform int dhRenderDistance;

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

#include "/lib/luma.glsl"
#include "/lib/dither.glsl"

void main() {
    #if AA_TYPE > 0
        float dither = shiftedRDither(gl_FragCoord.xy);
    #else
        float dither = rDither(gl_FragCoord.xy);
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

    float block_luma = luma(tintColor.rgb);

    vec3 finalCandleColor = candleColor;

    float shadowValue = abs((dayNightMix * 2.0) - 1.0);

    vec3 realLight =
        omniLight +
        (shadowValue * directLightColor * directLightStrength) * (1.0 - (rainStrength * 0.55)) +
        finalCandleColor;

    blockColor.rgb *= mix(realLight, vec3(1.0), nightVision * 0.125);
    blockColor.rgb *= mix(vec3(1.0, 1.0, 1.0), vec3(NV_COLOR_R, NV_COLOR_G, NV_COLOR_B), nightVision);

    blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));

    #include "/src/finalcolor_dh.glsl"
    #include "/src/writebuffers.glsl"
}
