#include "/lib/config.glsl"

uniform sampler2D tex;

varying vec2 texcoord;

void main() {
    vec4 blockColor = texture2D(tex, texcoord);

    #include "/src/writebuffers.glsl"
}
