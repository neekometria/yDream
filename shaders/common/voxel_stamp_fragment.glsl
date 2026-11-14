#include "/lib/config.glsl"

uniform sampler2D colortex8;
uniform sampler2D colortex11;
uniform sampler2D depthtex0;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform vec3 cameraPosition;
uniform float near;
uniform float far;

varying vec2 texcoord;

float vsMax3(vec3 v) {
    return max(v.r, max(v.g, v.b));
}

// Canal alpha do colortex8 = solidez do voxel (mesma convenção do voxel_update).
vec4 vsHistory(vec3 idx) {
    float tileX = mod(idx.y, 7.0);
    float tileY = floor(idx.y / 7.0);
    vec2 texel = vec2(tileX * 96.0 + idx.x, tileY * 96.0 + idx.z) + 0.5;
    return texture2DLod(colortex8, texel / 672.0, 0.0);
}

void main() {
    vec2 pixel = floor(gl_FragCoord.xy);
    float tileX = floor(pixel.x / 96.0);
    float tileY = floor(pixel.y / 96.0);
    float slice = tileY * 7.0 + tileX;
    vec3 idx = vec3(mod(pixel.x, 96.0), slice, mod(pixel.y, 96.0));

    vec3 best = vec3(0.0);
    float solidity = vsHistory(idx).a;

    if (slice < 48.0 && tileX < 7.0 && tileY < 7.0) {
        vec3 rel = (idx - vec3(48.0, 24.0, 48.0)) + 0.5 - fract(cameraPosition);

        // Marcação de solidez com o depth do frame atual (este passe roda
        // depois da geometria, ao contrário do voxel_update).
        if (dot(rel, rel) < 576.0) {
            vec4 viewPos = gbufferModelView * vec4(rel, 1.0);

            if (viewPos.z < -0.3) {
                vec4 clipPos = gbufferProjection * viewPos;
                vec2 baseUV = clipPos.xy / clipPos.w * 0.5 + 0.5;

                if (baseUV.x > 0.002 && baseUV.x < 0.998 && baseUV.y > 0.002 && baseUV.y < 0.998) {
                    float sceneDepth = texture2DLod(depthtex0, baseUV, 0.0).r;
                    float sceneDistance = 2.0 * near * far / (far + near - (sceneDepth * 2.0 - 1.0) * (far - near));
                    float gap = (-viewPos.z) - sceneDistance;

                    solidity = (gap > 0.0 && gap < 1.55) ? 1.0 : 0.0;
                }
            }
        }

        best = vsHistory(idx).rgb;

        if (dot(rel, rel) < 576.0) {
            vec4 viewPos = gbufferModelView * vec4(rel, 1.0);

            if (viewPos.z < -0.3) {
                vec4 clipPos = gbufferProjection * viewPos;
                vec2 baseUV = clipPos.xy / clipPos.w * 0.5 + 0.5;
                vec2 perBlock = vec2(gbufferProjection[0][0], gbufferProjection[1][1]) * 0.5 / (-viewPos.z);
                float voxelDistance = -viewPos.z;

                vec3 hueSum = vec3(0.0);

                for (int i = 0; i < 3; i++) {
                    for (int j = 0; j < 3; j++) {
                        vec2 tapUV = baseUV + vec2(float(i) - 1.0, float(j) - 1.0) * 0.4 * perBlock;

                        if (tapUV.x > 0.002 && tapUV.x < 0.998 && tapUV.y > 0.002 && tapUV.y < 0.998) {
                            vec4 tint = texture2DLod(colortex11, tapUV, 0.0);

                            if (tint.a > 0.5) {
                                float sceneDepth = texture2DLod(depthtex0, tapUV, 0.0).r;
                                float sceneDistance = 2.0 * near * far / (far + near - (sceneDepth * 2.0 - 1.0) * (far - near));

                                float seedGap = voxelDistance - sceneDistance;

                                // Mesmo gate do voxel_update: -0.85 alcança o voxel do próprio
                                // emissor e o voxel de ar adjacente (gap -0.375..-0.5).
                                if (seedGap > -0.85 && seedGap < 0.95) {
                                    hueSum += tint.rgb;
                                }
                            }
                        }
                    }
                }

                if (vsMax3(hueSum) > 0.0) {
                    best = hueSum / vsMax3(hueSum);
                }
            }
        }
    }

    /* DRAWBUFFERS:8 */
    gl_FragData[0] = vec4(best, solidity);
}
