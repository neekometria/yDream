// ============================================================================
// composite6 desativado: o reflexo da água agora é inline no passe dela.
// Este passe só limpa a saída para manter o programa válido se for habilitado.
// ============================================================================
#include "/lib/config.glsl"

varying vec2 texcoord;

void main() {
    /* RENDERTARGETS: 10 */
    gl_FragData[0] = vec4(0.0);
}
