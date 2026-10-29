#include "/lib/config.glsl"

uniform sampler2D colortex2;
uniform sampler2D colortex8;
uniform sampler2D depthtex0;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform float frameTime;
uniform float near;
uniform float far;

varying vec2 texcoord;

float vuMax3(vec3 v) {
    return max(v.r, max(v.g, v.b));
}

vec3 vuHistory(vec3 idx) {
    if (idx.x < 0.0 || idx.y < 0.0 || idx.z < 0.0 || idx.x >= 96.0 || idx.y >= 48.0 || idx.z >= 96.0) {
        return vec3(0.0);
    }
    float tileX = mod(idx.y, 7.0);
    float tileY = floor(idx.y / 7.0);
    vec2 texel = vec2(tileX * 96.0 + idx.x, tileY * 96.0 + idx.z) + 0.5;
    return texture2DLod(colortex8, texel / 672.0, 0.0).rgb;
}

void vuAccumulate(vec3 candidate, float loss, inout vec3 hueSum, inout float weightSum, inout float bestStrength) {
    float strength = vuMax3(candidate);

    if (strength > loss) {
        strength -= loss;
        float weight = strength * strength;
        weight *= weight;
        hueSum += (candidate / vuMax3(candidate)) * weight;
        weightSum += weight;
        bestStrength = max(bestStrength, strength);
    }
}

void main() {
    vec2 pixel = floor(gl_FragCoord.xy);
    float tileX = floor(pixel.x / 96.0);
    float tileY = floor(pixel.y / 96.0);
    float slice = tileY * 7.0 + tileX;
    vec3 idx = vec3(mod(pixel.x, 96.0), slice, mod(pixel.y, 96.0));

    vec3 best = vec3(0.0);
    vec3 hueSum = vec3(0.0);
    float weightSum = 0.0;
    float bestStrength = 0.0;

    if (slice < 48.0 && tileX < 7.0 && tileY < 7.0) {
        vec3 delta = floor(cameraPosition) - floor(previousCameraPosition);
        float shift = max(abs(delta.x), max(abs(delta.y), abs(delta.z)));
        float stepLoss = 1.0 / COLORED_LIGHT_RADIUS;

        if (shift < 24.0) {
            vec3 prevIdx = idx + delta;
            float decay = exp(-frameTime / 120.0);

            vuAccumulate(vuHistory(prevIdx) * decay, 0.0, hueSum, weightSum, bestStrength);

            for (int dx = -1; dx <= 1; dx++) {
                for (int dy = -1; dy <= 1; dy++) {
                    for (int dz = -1; dz <= 1; dz++) {
                        if (dx != 0 || dy != 0 || dz != 0) {
                            vec3 offset = vec3(float(dx), float(dy), float(dz));
                            vuAccumulate(vuHistory(prevIdx + offset), stepLoss * length(offset), hueSum, weightSum, bestStrength);
                        }
                    }
                }
            }
        }

        vec3 rel = (idx - vec3(48.0, 24.0, 48.0)) + 0.5 - fract(cameraPosition);

        if (dot(rel, rel) < 576.0) {
            vec4 viewPos = gbufferModelView * vec4(rel, 1.0);

            if (viewPos.z < -0.3) {
                vec4 clipPos = gbufferProjection * viewPos;
                vec2 baseUV = clipPos.xy / clipPos.w * 0.5 + 0.5;
                vec2 perBlock = vec2(gbufferProjection[0][0], gbufferProjection[1][1]) * 0.5 / (-viewPos.z);
                float voxelDistance = -viewPos.z;

                for (int i = 0; i < 3; i++) {
                    for (int j = 0; j < 3; j++) {
                        vec2 tapUV = baseUV + vec2(float(i) - 1.0, float(j) - 1.0) * 0.4 * perBlock;

                        if (tapUV.x > 0.002 && tapUV.x < 0.998 && tapUV.y > 0.002 && tapUV.y < 0.998) {
                            vec3 tint = texture2DLod(colortex2, tapUV, 0.0).rgb;

                            if (vuMax3(tint) > 0.05) {
                                float sceneDepth = texture2DLod(depthtex0, tapUV, 0.0).r;
                                float sceneDistance = 2.0 * near * far / (far + near - (sceneDepth * 2.0 - 1.0) * (far - near));

                                float seedGap = voxelDistance - sceneDistance;

                                if (seedGap > -0.2 && seedGap < 0.95) {
                                    vuAccumulate(tint / vuMax3(tint) * 1.0, 0.0, hueSum, weightSum, bestStrength);
                                }
                            }
                        }
                    }
                }
            }
        }

        if (weightSum > 0.0) {
            vec3 hue = hueSum / weightSum;
            best = hue / vuMax3(hue) * bestStrength;
        }
    }

    /* DRAWBUFFERS:8 */
    gl_FragData[0] = vec4(best, 1.0);
}
