#include "/lib/config.glsl"

uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

#if YDREAM_VOXEL_LIGHT > 0
    // Voxelização no SHADOW PASS (método do Colorful Vanilla Lights):
    // o shadow frustum cobre o volume inteiro (shadowDistance 75 > raio 48)
    // INDEPENDENTE de para onde a câmera olha. É isto que mata o "pisca ao
    // andar": a solidez/emissores deixam de existir só onde a tela olhou.
    // A uniform padrão cameraPosition é confiável nos passes shadow/vertex
    // (o problema de garbage era dos passes deferred). TEM que vir ANTES do
    // include: o corpo de ydreamVoxelize usa cameraPosition, e GLSL exige a
    // declaração antes da definição da função (senão C1503).
    uniform vec3 cameraPosition;
    #include "/common/voxel_voxelize.glsl"
    uniform int renderStage;
#endif

varying vec2 texcoord;
varying float is_noshadow;

#if YDREAM_RSM_GI > 0
    varying vec4 tintColor;
    varying vec3 worldRelPos;
#endif

#ifdef COLORED_SHADOW
    varying float is_water;
#endif

attribute vec4 mc_Entity;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    #if YDREAM_RSM_GI > 0
        tintColor = gl_Color;
    #endif

    vec4 position = shadowModelViewInverse * shadowProjectionInverse * gl_ModelViewProjectionMatrix * gl_Vertex;
    gl_Position = shadowProjection * shadowModelView * position;

    #if YDREAM_RSM_GI > 0
        worldRelPos = position.xyz;
    #endif

    #if YDREAM_VOXEL_LIGHT > 0
        // Ocupância vem de um único passe independente da câmera: shadow pass.
        // Inclui sólidos, cutout, cutout-mipped e translúcidos; entidades e mão
        // ficam de fora porque at_midBlock não representa sua ocupância.
        if (renderStage == MC_RENDER_STAGE_TERRAIN_SOLID ||
            renderStage == MC_RENDER_STAGE_TERRAIN_TRANSLUCENT ||
            renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT ||
            renderStage == MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED) {
            uint ydCode = YD_VOXEL_OPAQUE;

            if (mc_Entity.x == ENTITY_EMMISIVE || mc_Entity.x == ENTITY_S_EMMISIVE || mc_Entity.x == ENTITY_NO_SHADOW_FIRE) {
                ydCode = ydreamEmitterCode(0u, 14.0);
            } else if (mc_Entity.x == ENTITY_E_SOUL || mc_Entity.x == ENTITY_F_EMMISIVE) {
                ydCode = ydreamEmitterCode(1u, 13.0);
            } else if (mc_Entity.x == ENTITY_E_REDSTONE) {
                ydCode = ydreamEmitterCode(2u, 11.0);
            } else if (mc_Entity.x == ENTITY_E_SEA) {
                ydCode = ydreamEmitterCode(3u, 15.0);
            } else if (mc_Entity.x == ENTITY_E_OCHRE) {
                ydCode = ydreamEmitterCode(4u, 15.0);
            } else if (mc_Entity.x == ENTITY_E_VERDANT) {
                ydCode = ydreamEmitterCode(5u, 15.0);
            } else if (mc_Entity.x == ENTITY_E_PEARL) {
                ydCode = ydreamEmitterCode(6u, 15.0);
            } else if (mc_Entity.x == ENTITY_E_VOID) {
                ydCode = ydreamEmitterCode(7u, 15.0);
            } else if (mc_Entity.x == ENTITY_WATER || mc_Entity.x == ENTITY_STAINED ||
                       mc_Entity.x == ENTITY_LEAVES || mc_Entity.x == ENTITY_VINES ||
                       mc_Entity.x == ENTITY_SMALLGRASS || mc_Entity.x == ENTITY_LOWERGRASS ||
                       mc_Entity.x == ENTITY_UPPERGRASS || mc_Entity.x == ENTITY_SMALLENTS ||
                       mc_Entity.x == ENTITY_SMALLENTS_NW) {
                // Cutout vegetation transmits light instead of filling an
                // entire voxel as an opaque wall.
                ydCode = 1u;
            } else {
                // Iris 1.7+ supplies the block's own emission (0..15) in w;
                // preserve it instead of assigning every unknown emitter level 14.
                #ifdef IRIS_FEATURE_BLOCK_EMISSION_ATTRIBUTE
                    float sourceLevel = floor(at_midBlock.w + 0.5);
                    if (sourceLevel >= 1.0) {
                        ydCode = ydreamEmitterCode(0u, sourceLevel);
                    }
                #endif
            }

            // The four vertices of a quad share one block center and code.
            // Emit one imageStore per quad instead of racing four identical writes.
            if ((gl_VertexID & 3) == 0) {
                ydreamVoxelize(gl_Vertex, at_midBlock, ydCode);
            }
        }
    #endif

    float dist = length(gl_Position.xy);
    float distortFactor = dist * SHADOW_DIST + (1.0 - SHADOW_DIST);

    gl_Position.xy *= 1.0 / distortFactor;
    gl_Position.z = gl_Position.z * 0.2;

    is_noshadow = 0.0;
    // O tapete de neve (camadas de 1/16) projeta sombra na propria superficie
    // logo abaixo e vira manchas/bandas em neve; a sombra real dele e
    // desprezivel. A neve continua RECEBENDO sombra normalmente.
    if (mc_Entity.x == ENTITY_NO_SHADOW_FIRE || mc_Entity.x == ENTITY_F_EMMISIVE || mc_Entity.x == ENTITY_SNOW_LAYER) {
        is_noshadow = 1.0;
    }

    #ifdef COLORED_SHADOW
        is_water = 0.0;

        if(mc_Entity.x == ENTITY_WATER) {
            is_water = 1.0;
        }
    #endif
}
