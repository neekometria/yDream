// ============================================================
// Uma imagem 3D r32ui (96×96×96, limpa TODO frame) recebe um CÓDIGO por
// célula, escrito por imageAtomicMax no vertex shader. A prioridade evita que
// água/folhas sobrescrevam um bloco sólido quando duas geometrias ocupam a
// mesma célula e são rasterizadas em ordem variável.
// O compute shadowcomp (common/vx_floodfill.csh) lê essa imagem logo após o
// shadow pass e difunde a luz colorida.
//
// Códigos:
//   0        = ar (célula nunca escrita neste frame)
//   1        = transmissivo (água, vidro e vegetação)
//   2        = opaco
//   32..151  = 8 famílias de cor × 15 níveis de emissão (1..15)
//              quente, soul, redstone, sea, ochre, verdant, pearl, void
//
// Imagem (shaders.properties):
//   image.ydVoxel = ydVoxelSampler r r32ui unsigned_int true false 96 96 96
//   - "true" = limpa a cada frame (reconstruída no shadow pass);
//     células NUNCA escritas = ar. A geometria opaca vista no shadow frustum
//     bloqueia a propagação; as superfícies transparentes fora do volume não
//     podem ser tratadas como paredes sólidas.
// ============================================================

layout (r32ui) coherent uniform uimage3D ydVoxel;

// Atributo do Iris (offsets do vértice até o centro do bloco, em 1/64).
in vec4 at_midBlock;

// Códigos compartilhados com o compute e o leitor.
const uint YD_VOXEL_OPAQUE = 2u;
const uint YD_VOXEL_EMITTER_BASE = 32u;

float ydreamSourceLevel(float fallbackLevel) {
    float sourceLevel = fallbackLevel;
    #ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
        float irisLevel = floor(at_midBlock.w + 0.5);
        if (irisLevel >= 1.0) {
            sourceLevel = irisLevel;
        }
    #endif
    return clamp(sourceLevel, 1.0, 15.0);
}

uint ydreamEmitterCode(uint tintIndex, float fallbackLevel) {
    uint sourceLevel = uint(floor(ydreamSourceLevel(fallbackLevel) + 0.5));
    return YD_VOXEL_EMITTER_BASE + tintIndex * 15u + sourceLevel - 1u;
}

void ydreamVoxelize(vec4 vertexPosition, vec4 midBlock, uint code) {
    // at_midBlock is expressed in model space. Transform it before adding it
    // to the camera-relative world position; adding it directly in world space
    // rotates the offset incorrectly as the camera/model-view basis changes.
    vec3 modelCenter = vertexPosition.xyz + midBlock.xyz / 64.0;
    vec3 viewCenter = mat3(gl_ModelViewMatrix) * modelCenter + gl_ModelViewMatrix[3].xyz;
    vec3 worldCenter = mat3(shadowModelViewInverse) * viewCenter + shadowModelViewInverse[3].xyz;

    // A voxel index is world-block-relative, not view-direction-relative.
    vec3 cellPosition = worldCenter + fract(cameraPosition) + vec3(48.0, 48.0, 48.0);
    ivec3 voxel = ivec3(floor(cellPosition));

    if (any(lessThan(voxel, ivec3(0))) ||
        any(greaterThanEqual(voxel, ivec3(96, 96, 96)))) {
        return;
    }

    // Opaque blocks (2) always win over transmissive overlays (1), no matter
    // which render stage reaches this cell last. Emitters (32..151) remain
    // floodable and therefore take priority over their own solid material.
    imageAtomicMax(ydVoxel, voxel, code);
}
