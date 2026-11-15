#include "/lib/config.glsl"

// Volume de voxels do terreno, escrito em POSIÇÃO DE MUNDO pelo vertex shader
// dos gbuffers (common/voxel_voxelize.glsl) — método do Colorful Vanilla
// Lights. aescala: rgb = tint do emissor, a = 1.0 emissor / 0.2 opaco / 0 ar.
uniform usampler3D ydEmitSampler;

uniform sampler2D colortex8;
uniform sampler2D colortex11;
uniform float frameTime;

// Luz dinâmica na mão: semeia o campo colorido na célula do bloco da câmera.
uniform int heldItemId;
uniform int heldItemId2;

// Persistência do campo: por padrão o Iris limpa colortex8 a cada frame, o que
// mata o histórico da propagação (o debug ficava sempre preto). Declarado aqui
// além do final.fsh para não depender de um único ponto registrando a diretiva.
const bool colortex8Clear = false;

varying vec2 texcoord;

float vuMax3(vec3 v) {
    return max(v.r, max(v.g, v.b));
}

// Canal alpha do colortex8 = solidez do voxel (1.0 = dentro da geometria).
vec4 vuHistory(vec3 idx) {
    if (idx.x < 0.0 || idx.y < 0.0 || idx.z < 0.0 || idx.x >= 96.0 || idx.y >= 96.0 || idx.z >= 96.0) {
        return vec4(0.0);
    }
    float tileX = mod(idx.y, 7.0);
    float tileY = floor(idx.y / 7.0);
    vec2 texel = vec2(tileX * 96.0 + idx.x, tileY * 96.0 + idx.z) + 0.5;
    vec4 raw = texture2DLod(colortex8, texel / 672.0, 0.0);

    // Sanidade: o buffer é clear=false, então texels nunca escritos contêm
    // lixo indefinido. Alpha fora de {0,1} é lixo (a solidez que escrevemos é
    // sempre exatamente 1.0 ou 0.0) — trata como célula vazia.
    if (raw.a > 0.25 && raw.a < 0.75) {
        return vec4(0.0);
    }

    return raw;
}

// Voxel do mundo (escrito pelo vertex shader): rgb = tint, a = opacidade.
vec4 vuEmit(vec3 idx) {
    if (idx.x < 0.0 || idx.y < 0.0 || idx.z < 0.0 || idx.x >= 96.0 || idx.y >= 96.0 || idx.z >= 96.0) {
        return vec4(0.0);
    }
    return unpackUnorm4x8(texelFetch(ydEmitSampler, ivec3(idx), 0).r);
}

void vuAccumulate(vec3 candidate, float loss, inout vec3 bestHue, inout float bestStrength) {
    float strength = vuMax3(candidate);

    if (strength > loss) {
        strength -= loss;

        // A matiz vem da fonte DOMINANTE (maior força), não de uma média
        // ponderada: com média, duas tochas de cores diferentes se misturavam
        // em branco/rosa no meio do caminho. Aqui a cor mais forte vence e a
        // transição entre duas fontes fica no ponto onde as forças se igualam.
        if (strength > bestStrength) {
            bestStrength = strength;
            bestHue = candidate / vuMax3(candidate);
        }
    }
}

void main() {
    vec2 pixel = floor(gl_FragCoord.xy);
    float tileX = floor(pixel.x / 96.0);
    float tileY = floor(pixel.y / 96.0);
    float slice = tileY * 7.0 + tileX;
    vec3 idx = vec3(mod(pixel.x, 96.0), slice, mod(pixel.y, 96.0));

    vec3 best = vec3(0.0);
    vec3 bestHue = vec3(0.0);
    float bestStrength = 0.0;

    // Delta INTEIRO de blocos andados pela câmera, do bounce do deferred0 no
    // colortex11: rgb = (d + 4)/8 com alpha=1.0. Um bloco do mundo muda de
    // célula em -d quando a câmera anda d blocos, então o histórico precisa
    // ser lido em idx + d (o volume desliza; sem o shift a luz fica colada
    // na câmera e o padrão varre a cena a cada passo).
    vec3 ydDelta = floor(texture2DLod(colortex11, texcoord, 0.0).rgb * 8.0 + 0.5) - 4.0;
    vec3 prevIdx = idx + ydDelta;

    // Opacidade e seed vêm do volume voxelizado (posição de mundo) — que é
    // reconstruído TODO frame a partir da geometria renderizada. Ele é a fonte
    // autoritativa de solidez: nada de "stale" que ficava sólido para sempre
    // depois de quebrar um bloco.
    vec4 emitData = vuEmit(idx);
    float emitAlpha = emitData.a;
    float solidity = emitAlpha > 0.05 ? 1.0 : 0.0;

    if (slice < 96.0 && tileX < 7.0 && tileY < 7.0) {
        float stepLoss = 1.0 / COLORED_LIGHT_RADIUS;

        // Emissor: a célula carrega a própria cor. Nada de projeção de tela —
        // o tint vem do bloco (tabela mc_Entity do vertex shader), então
        // redstone torch continua vermelha e soul lantern azul.
        float seedStrength = 0.0;
        vec3 seedHue = vec3(0.0);

        if (emitAlpha > 0.9) {
            vec3 tint = vec3(emitData.r, emitData.g, emitData.b);
            float peak = vuMax3(tint);

            if (peak > 0.02) {
                seedStrength = 1.0;
                seedHue = tint / peak;
            }
        }

        if (solidity < 0.5) {
            // Persistência COM decaimento: a seed é reescrita todo frame pelo
            // SHADOW PASS (independente de view), então a luz não some ao
            // desviar o olhar. Mas com a fonte REMOVIDA o campo precisa cair:
            // sem decaimento o max-plus mantinha luz eterna onde a tocha foi
            // tirada. Decaimento ~exponencial por frame, escalado pelo tempo.
            float ft = frameTime > 1.0 ? frameTime * 0.001 : frameTime;
            float vuDecay = clamp(ft * 1.2, 0.01, 0.25);
            vuAccumulate(vuHistory(prevIdx).rgb, vuDecay, bestHue, bestStrength);

            for (int dx = -1; dx <= 1; dx++) {
                for (int dy = -1; dy <= 1; dy++) {
                    for (int dz = -1; dz <= 1; dz++) {
                        if (dx != 0 || dy != 0 || dz != 0) {
                            vec3 offset = vec3(float(dx), float(dy), float(dz));
                            vuAccumulate(vuHistory(prevIdx + offset).rgb, stepLoss * length(offset), bestHue, bestStrength);
                        }
                    }
                }
            }

            if (seedStrength > 0.0) {
                vuAccumulate(seedHue * seedStrength, 0.0, bestHue, bestStrength);
            }

            // Luz na mão (mesma tabela do item.properties): a célula do bloco
            // da câmera é (48,24,48). Semeando o CAMPO, a luz dinâmica ganha a
            // mesma curva/raio/cor do resto — antes ela só subia o candle
            // vanilla, que abria o add gated por candle e fazia as luzes
            // próximas "explodirem" e as de mão não acendiam em lugar escuro.
            if (idx.x == 48.0 && idx.y == 48.0 && idx.z == 48.0) {
                if (heldItemId == 11001 || heldItemId2 == 11001) {
                    vuAccumulate(vec3(1.0, 0.60, 0.26), 0.0, bestHue, bestStrength);
                } else if (heldItemId == 11002 || heldItemId2 == 11002) {
                    vuAccumulate(vec3(1.0, 0.16, 0.08), 0.0, bestHue, bestStrength);
                }
            }

            if (bestStrength > 0.0) {
                best = bestHue * bestStrength;
            }

            // Teto rígido: o campo nunca passa de 1.0 (a difusão já é limitada
            // pela seed, mas o RGBA16F aceitaria valores maiores).
            best = clamp(best, vec3(0.0), vec3(1.0));
        } else {
            // Voxel sólido: absorvedor — não acumula luz dos vizinhos (a luz
            // não atravessa geometria). Se for a célula do emissor, carrega a
            // seed; senão mantém o próprio valor (persistente).
            best = vuHistory(prevIdx).rgb;

            if (seedStrength > 0.0) {
                best = seedHue * seedStrength;
            }
        }
    }

    /* DRAWBUFFERS:8 */
    gl_FragData[0] = vec4(best, solidity);
}
