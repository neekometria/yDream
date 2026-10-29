#include "/lib/config.glsl"

varying vec4 tintColor;
varying vec2 texcoord;
varying vec3 basicLight;

void main() {
    vec4 blockColor = tintColor;
    blockColor.rgb *= basicLight;

    #include "/src/writebuffers.glsl"
}
