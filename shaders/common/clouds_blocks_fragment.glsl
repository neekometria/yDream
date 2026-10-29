#include "/lib/config.glsl"

uniform sampler2D tex;
uniform float far;
uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
    uniform float darknessLightFactor;
#endif

uniform float pixelSizeX;
uniform float pixelSizeY;
uniform sampler2D gaux4;

#if MC_VERSION < 12106 || defined UNKNOWN_DIM
    varying vec2 texcoord;
#endif

#ifdef UNKNOWN_DIM
    varying vec4 tintColor;
#endif

varying vec3 cloudFinalColor;
varying float meshAlpha;
varying float cloudFacing;
varying vec3 cloudWorldXZY;
varying vec3 cloudFaceNormalV;
varying float cloudUpFacingV;

void main() {
    #if defined CLOUDS_OFF || defined THE_END || defined NETHER || (V_CLOUDS != 0 && !defined UNKNOWN_DIM && !defined THE_END && !defined NETHER)
        discard;
    #elif defined UNKNOWN_DIM
        vec4 blockColor = texture2D(tex, texcoord) * tintColor;
        #include "/src/cloudfinalcolor.glsl"
        #include "/src/writebuffers.glsl"
    #else
        #if MC_VERSION >= 12106
            float cloudAlpha = meshAlpha;
        #else
            float cloudAlpha = texture2D(tex, texcoord).a * meshAlpha;
        #endif

        if (cloudAlpha < 0.004) {
            discard;
        }

        cloudAlpha *= mix(0.55, 1.0, smoothstep(0.0, 0.30, cloudFacing));

        vec3 cloudPuffColor = cloudFinalColor;
        #if defined THE_END
            cloudPuffColor *= vec3(1.0, 0.62, 0.34);
        #elif defined NETHER
            cloudPuffColor *= vec3(1.0, 0.48, 0.24);
        #endif

        if (VANILLA_CLOUD_ROUNDNESS > 0.001) {
            vec2 cloudCellXZ = fract(cloudWorldXZY.xy / VANILLA_CLOUD_CELL_SIZE) - 0.5;
            float cloudCellY = clamp((cloudWorldXZY.z - VANILLA_CLOUD_BASE_Y) / VANILLA_CLOUD_CELL_HEIGHT, 0.0, 1.0) - 0.5;

            vec2 cloudRoundUV;
            if (abs(cloudUpFacingV) > 0.5) {
                cloudRoundUV = cloudCellXZ * 2.0;
            } else if (abs(cloudFaceNormalV.x) > abs(cloudFaceNormalV.z)) {
                cloudRoundUV = vec2(cloudCellXZ.y, cloudCellY) * 2.0;
            } else {
                cloudRoundUV = vec2(cloudCellXZ.x, cloudCellY) * 2.0;
            }

            vec2 cloudRectQ = abs(cloudRoundUV) - (1.0 - VANILLA_CLOUD_ROUNDNESS);
            float cloudRoundSdf = length(max(cloudRectQ, vec2(0.0))) +
                min(max(cloudRectQ.x, cloudRectQ.y), 0.0) - VANILLA_CLOUD_ROUNDNESS;

            float cloudEdgeWidth = 0.16 * VANILLA_CLOUD_SOFTNESS;
            float cloudRoundMask = 1.0 - smoothstep(-cloudEdgeWidth, cloudEdgeWidth, cloudRoundSdf);
            cloudAlpha *= cloudRoundMask;

            float cloudPuffShade = smoothstep(-0.7, 0.05, cloudRoundSdf);
            cloudPuffColor *= mix(1.0, mix(1.08, 0.82, cloudPuffShade), VANILLA_CLOUD_ROUNDNESS * 0.7);

            float cloudRimGlow = (1.0 - smoothstep(-cloudEdgeWidth * 2.2, -cloudEdgeWidth * 0.1, cloudRoundSdf)) *
                smoothstep(-cloudEdgeWidth * 3.4, -cloudEdgeWidth * 2.2, cloudRoundSdf);
            cloudPuffColor += cloudPuffColor * cloudRimGlow * 0.18;
        }

        vec4 blockColor = vec4(cloudPuffColor, cloudAlpha * VANILLA_CLOUD_OPACITY);

        float cloudGrazeRim = 1.0 - clamp(cloudFacing * 1.6, 0.0, 1.0);
        blockColor.rgb += blockColor.rgb * (cloudGrazeRim * cloudGrazeRim * 0.10);

        #include "/src/cloudfinalcolor.glsl"
        #include "/src/writebuffers.glsl"
    #endif
}
