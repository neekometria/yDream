// ============================================================
// yDream voxel colored lighting — Iris 1.8+.
//
// The radiance field is camera-relative and dimension-tagged. Filtering is
// performed explicitly over the 8 texels of the trilinear footprint; opaque
// cells are excluded and the remaining weights are renormalized. This avoids
// sampling radiance through a wall while retaining smooth transitions in air,
// water, glass and foliage.
// ============================================================

uniform sampler3D ydFieldSampler;
uniform sampler3D ydFieldCopySampler;

#include "/lib/voxel_world_id.glsl"

const ivec3 VLF_VOLUME_SIZE = ivec3(96, 48, 96);
const vec3 VLF_VOLUME_CENTER = vec3(48.0, 24.0, 48.0);

bool vlfInsideVolume(ivec3 cell) {
    return all(greaterThanEqual(cell, ivec3(0))) &&
           all(lessThan(cell, VLF_VOLUME_SIZE));
}

vec4 vlfSampleLatest(vec3 uvw) {
    vec4 value;
    if (mod(float(frameCounter), 2.0) < 0.5) {
        value = texture3DLod(ydFieldCopySampler, uvw, 0.0);
    } else {
        value = texture3DLod(ydFieldSampler, uvw, 0.0);
    }

    if (abs(mod(value.a, 16.0) - YD_WORLD_ID) > 0.25) {
        return vec4(0.0);
    }

    return value;
}

vec3 vlfVoxelPosition(vec3 worldRel) {
    return worldRel + fract(ydCameraPosition) + VLF_VOLUME_CENTER;
}

vec3 vlfSampleFiltered(vec3 voxelPosition) {
    // GLSL normalized 3D texture coordinates put texel centers at i + 0.5.
    // Convert the continuous voxel coordinate to the lower texel corner.
    vec3 texelPosition = voxelPosition - vec3(0.5);
    ivec3 baseCell = ivec3(floor(texelPosition));
    vec3 fraction = fract(texelPosition);

    vec3 accumulated = vec3(0.0);
    float totalWeight = 0.0;

    for (int z = 0; z <= 1; z++) {
        for (int y = 0; y <= 1; y++) {
            for (int x = 0; x <= 1; x++) {
                ivec3 offset = ivec3(x, y, z);
                ivec3 cell = baseCell + offset;

                float wx = (x == 0) ? 1.0 - fraction.x : fraction.x;
                float wy = (y == 0) ? 1.0 - fraction.y : fraction.y;
                float wz = (z == 0) ? 1.0 - fraction.z : fraction.z;
                float weight = wx * wy * wz;

                if (weight > 0.00001 && vlfInsideVolume(cell)) {
                    vec3 cellUV = (vec3(cell) + vec3(0.5)) / vec3(VLF_VOLUME_SIZE);
                    vec4 cellValue = vlfSampleLatest(cellUV);
                    // Alpha >= 16 marks an opaque voxel; mismatched dimensions
                    // are already returned as zero by vlfSampleLatest.
                    if (cellValue.a > 0.0 && cellValue.a < 16.0) {
                        accumulated += cellValue.rgb * weight;
                        totalWeight += weight;
                    }
                }
            }
        }
    }

    return totalWeight > 0.00001 ? accumulated / totalWeight : vec3(0.0);
}

float vlfPeak(vec3 value) {
    return max(value.r, max(value.g, value.b));
}

float vlfLuminance(vec3 value) {
    return dot(value, vec3(0.2126, 0.7152, 0.0722));
}

#ifdef VLF_MATERIAL_LIGHT
float vlfBlockLightCurve(float level) {
    level = clamp(level, 0.0, 1.0);
    float level2 = level * level;
    float level4 = level2 * level2;
    float level6 = level4 * level2;

    float curve = level * sqrt(level);
    curve += level6 * 2.5651642;
    curve += 0.45 * level4;
    curve /= 1.0 + BLOCKLIGHT_CONTRAST * (1.0 - level);
    return curve * BLOCKLIGHT_INTENSITY;
}

// Replace only the vanilla block-light component. Solar/direct lighting,
// ambient illumination, emissive materials, alpha coverage and shadowing are
// deliberately independent of this path.
vec3 vlfApplyBlockLight(vec3 vanillaBlockLight, vec3 worldRel, vec3 worldNormal) {
    vec3 normal = worldNormal;
    float normalLength = dot(normal, normal);
    if (normalLength < 0.0001) {
        normal = vec3(0.0, 1.0, 0.0);
    } else {
        normal *= inversesqrt(normalLength);
    }

    // Query the air side of the surface. This selects the correct side of a
    // wall without deriving normals from the screen depth buffer.
    vec3 samplePosition = worldRel + normal * 0.55;
    vec3 voxelPosition = vlfVoxelPosition(samplePosition);

    if (any(lessThan(voxelPosition, vec3(0.0))) ||
        any(greaterThanEqual(voxelPosition, vec3(VLF_VOLUME_SIZE)))) {
        return vanillaBlockLight;
    }

    vec3 radiance = max(vlfSampleFiltered(voxelPosition), vec3(0.0));
    float peak = clamp(vlfPeak(radiance), 0.0, 1.0);
    if (peak <= 0.001) {
        return vanillaBlockLight;
    }

    // The compute field decays as exp(-distance / radius). Recover distance,
    // then map it to the same 0..15 light-level domain used by Minecraft.
    float radius = max(COLORED_LIGHT_RADIUS, 1.0);
    float distanceBlocks = -radius * log(max(peak, 0.0001));
    float lightLevel = clamp((15.0 - distanceBlocks) / 15.0, 0.0, 1.0);
    if (lightLevel <= 0.001) {
        return vanillaBlockLight;
    }

    // Independent RGB channel propagation allows separate sources to mix.
    // Normalize by the strongest channel so hue and intensity remain distinct.
    vec3 sourceTint = radiance / max(peak, 0.0001);
    vec3 blockLightShift = mix(
        vec3(1.06, 0.92, 0.70),
        vec3(1.0, 1.04, 1.10),
        smoothstep(0.85, 1.0, lightLevel)
    );
    #if BLOCKLIGHT_TEMP == 4
        blockLightShift = vec3(1.0);
    #endif

    vec3 blockLightBase = CANDLE_BASELIGHT * blockLightShift;
    #ifdef NETHER
        blockLightBase *= 1.4;
    #endif

    vec3 coloredLight = sourceTint * blockLightBase * vlfBlockLightCurve(lightLevel);
    coloredLight *= COLORED_LIGHT_STRENGTH;
    coloredLight = clamp(coloredLight, vec3(0.0), vec3(4.0));

    // Keep vanilla block-light energy wherever the voxel approximation is
    // weaker. This avoids dark seams at the edge of the voxel volume or range.
    float coloredLuma = vlfLuminance(coloredLight);
    float vanillaLuma = vlfLuminance(max(vanillaBlockLight, vec3(0.0)));
    if (coloredLuma <= 0.0001) {
        return vanillaBlockLight;
    }

    if (coloredLuma >= vanillaLuma) {
        return coloredLight;
    }

    vec3 sameLuminanceTint = coloredLight * (vanillaLuma / coloredLuma);
    float tintConfidence = clamp(coloredLuma / max(vanillaLuma, 0.0001), 0.0, 1.0);
    return mix(vanillaBlockLight, sameLuminanceTint, tintConfidence);
}
#endif // VLF_MATERIAL_LIGHT
