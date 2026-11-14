// ============================================================
// yDream colored-light propagation — Iris 1.8+ compute shader.
//
// Each RGB channel propagates independently with exponential distance loss.
// This lets different source hues combine without turning the brightest
// source into the only surviving color. A 2-cell axial step accelerates
// convergence, but is accepted only when the intermediate voxel is open.
// Source voxels keep their own seed while remaining solid to material taps.
// ============================================================

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
const ivec3 workGroups = ivec3(12, 6, 12); // 96/8, 48/8, 96/8

#include "/lib/config.glsl"
#include "/lib/voxel_world_id.glsl"

uniform usampler3D ydVoxelSampler;
layout (rgba16f) writeonly uniform image3D ydField;
layout (rgba16f) writeonly uniform image3D ydFieldCopy;
uniform sampler3D ydFieldSampler;
uniform sampler3D ydFieldCopySampler;

uniform int frameCounter;
uniform vec3 ydCameraPosition;
uniform vec3 ydCameraPrev;

uniform int heldItemId;
uniform int heldItemId2;

const uint YD_VOXEL_OPAQUE = 2u;
const uint YD_VOXEL_EMITTER_BASE = 32u;
const uint YD_VOXEL_EMITTER_END = 151u;

bool ydIsEmitter(uint code) {
    return code >= YD_VOXEL_EMITTER_BASE && code <= YD_VOXEL_EMITTER_END;
}

float ydEmitterLevel(uint code) {
    uint packedLevel = (code - YD_VOXEL_EMITTER_BASE) % 15u;
    return float(packedLevel + 1u) / 15.0;
}

vec3 ydEmitterTint(uint code) {
    uint tintIndex = (code - YD_VOXEL_EMITTER_BASE) / 15u;
    if (tintIndex == 0u) { return vec3(1.00, 0.60, 0.26); } // warm
    if (tintIndex == 1u) { return vec3(0.22, 0.70, 1.00); } // soul
    if (tintIndex == 2u) { return vec3(1.00, 0.16, 0.08); } // redstone
    if (tintIndex == 3u) { return vec3(0.55, 0.95, 1.00); } // sea
    if (tintIndex == 4u) { return vec3(1.00, 0.78, 0.28); } // ochre
    if (tintIndex == 5u) { return vec3(0.45, 1.00, 0.38); } // verdant
    if (tintIndex == 6u) { return vec3(1.00, 0.52, 0.88); } // pearl
    if (tintIndex == 7u) { return vec3(0.62, 0.38, 1.00); } // void
    return vec3(1.0, 0.60, 0.26);
}

// Força por família de fonte, multiplicando o seed (tint * nivel/15) antes da
// propagação. A família warm (tocha/lanterna/glowstone/velas) é a referência
// em 1.0 e NÃO é alterada; as coloridas eram percebidas bem mais fracas que o
// nível vanilla sugere, então recebem ganho (e soul/redstone com folga).
// O ganho também estende o alcance: o material recupera a distância a partir
// do pico do campo, então seed maior = raio efetivo maior.
float ydEmitterBoost(uint tintIndex) {
    if (tintIndex == 0u) { return 1.0; }  // warm — tocha normal, referência
    if (tintIndex == 1u) { return 1.6; }  // soul
    if (tintIndex == 2u) { return 2.0; }  // redstone
    return 1.3;                           // sea/ochre/verdant/pearl/void
}

bool ydIsOpen(uint code) {
    return code == 0u || code == 1u;
}

bool ydCanSupply(uint code) {
    return ydIsOpen(code) || ydIsEmitter(code);
}

bool ydInVolume(ivec3 p) {
    return all(greaterThanEqual(p, ivec3(0))) && all(lessThan(p, ivec3(96, 48, 96)));
}

uint ydVoxelAt(ivec3 p) {
    if (!ydInVolume(p)) {
        return YD_VOXEL_OPAQUE;
    }
    return texelFetch(ydVoxelSampler, p, 0).r;
}

vec3 ydFieldAt(sampler3D field, ivec3 p) {
    if (!ydInVolume(p)) {
        return vec3(0.0);
    }

    vec4 sampleValue = texelFetch(field, p, 0);
    float sampleWorldId = mod(sampleValue.a, 16.0);
    if (abs(sampleWorldId - YD_WORLD_ID) > 0.25) {
        return vec3(0.0);
    }

    return max(sampleValue.rgb, vec3(0.0));
}

vec3 ydPropagate(sampler3D field, ivec3 previousPos, ivec3 currentPos, float attenuation) {
    const ivec3 directions[6] = ivec3[6](
        ivec3( 1, 0, 0), ivec3(-1, 0, 0),
        ivec3( 0, 1, 0), ivec3( 0,-1, 0),
        ivec3( 0, 0, 1), ivec3( 0, 0,-1)
    );

    vec3 best = vec3(0.0);
    float attenuation2 = attenuation * attenuation;

    for (int i = 0; i < 6; i++) {
        ivec3 direction = directions[i];
        ivec3 adjacent = currentPos + direction;
        uint adjacentCode = ydVoxelAt(adjacent);

        // One-cell contribution. Emitters may supply light to adjacent air,
        // but their cells are never accepted as a two-cell corridor.
        if (ydCanSupply(adjacentCode)) {
            vec3 candidate = ydFieldAt(field, previousPos + direction) * attenuation;
            best = max(best, candidate);
        }

        ivec3 destination = currentPos + direction * 2;
        uint destinationCode = ydVoxelAt(destination);

        // A two-cell leap is valid only through an open middle voxel. This is
        // the critical guard against skipping a wall during fast propagation.
        if (ydIsOpen(adjacentCode) && ydCanSupply(destinationCode)) {
            vec3 candidate = ydFieldAt(field, previousPos + direction * 2) * attenuation2;
            best = max(best, candidate);
        }
    }

    return best;
}

void main() {
    ivec3 pos = ivec3(gl_GlobalInvocationID);
    ivec3 previousPos = pos
        - ivec3(floor(ydCameraPrev))
        + ivec3(floor(ydCameraPosition));

    uint code = ydVoxelAt(pos);
    vec3 light = vec3(0.0);

    // Radius is measured in world blocks. exp(-1/R) gives one-block loss;
    // the material pass converts this intensity back into a vanilla-like
    // 0..15 block-light level before applying yDream's existing response curve.
    float radius = max(COLORED_LIGHT_RADIUS, 1.0);
    float attenuation = exp(-1.0 / radius);

    if (ydIsOpen(code) && frameCounter > 0) {
        if ((frameCounter & 1) == 0) {
            light = ydPropagate(ydFieldSampler, previousPos, pos, attenuation);
        } else {
            light = ydPropagate(ydFieldCopySampler, previousPos, pos, attenuation);
        }
    }

    // Emissive blocks are solid blockers for interpolation, but their stored
    // seed is still readable by the neighboring open voxels during propagation.
    if (ydIsEmitter(code)) {
        uint emitterTintIndex = (code - YD_VOXEL_EMITTER_BASE) / 15u;
        light = ydEmitterTint(code) * ydEmitterLevel(code) * ydEmitterBoost(emitterTintIndex);
    }

    // Held lights seed the camera-centred voxel with a block-light-equivalent
    // strength; the next frames propagate them through the same field.
    if (all(equal(pos, ivec3(48, 24, 48))) && ydIsOpen(code)) {
        if (heldItemId == 11001 || heldItemId2 == 11001) {
            light = vec3(1.0, 0.60, 0.26) * (14.0 / 15.0);
        } else if (heldItemId == 11002 || heldItemId2 == 11002) {
            // Mesmo ganho da redstone colocada no mundo (ydEmitterBoost).
            light = vec3(1.0, 0.16, 0.08) * (7.0 / 15.0) * 2.0;
        }
    }

    // Alpha stores the dimension id (1..13), plus 16 for solid voxels.
    // The compute shader ignores the solid bit when reading a source; material
    // filtering excludes those cells so light cannot interpolate through walls.
    bool isSolid = code == YD_VOXEL_OPAQUE || ydIsEmitter(code);
    float fieldTag = YD_WORLD_ID + (isSolid ? 16.0 : 0.0);
    vec4 result = vec4(light, fieldTag);

    if ((frameCounter & 1) == 0) {
        imageStore(ydFieldCopy, pos, result);
    } else {
        imageStore(ydField, pos, result);
    }
}
