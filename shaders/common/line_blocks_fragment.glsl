#include "/lib/config.glsl"

varying vec4 tintColor;

void main() {
    vec4 blockColor = tintColor;

    #include "/src/writebuffers.glsl"
}
