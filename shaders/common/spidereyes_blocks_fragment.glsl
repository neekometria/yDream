#include "/lib/config.glsl"

uniform sampler2D tex;
uniform int entityId;
uniform vec3 sunPosition;
uniform float dayNightMix;

varying vec2 texcoord;
varying vec4 tintColor;
varying vec3 eyeViewPos;

// Olhos/brilho do rosto do jogador (Punchy Moves): o brilho continua emissivo,
// mas escurece no lado sem sol, acompanhando o corpo. 1.0 = sem sombra.
#define PLAYER_EYE_SHADE_FLOOR 0.45

void main() {

    vec4 blockColor = texture2D(tex, texcoord) * tintColor;

    if (entityId == 10301 || entityId == 10302) {
        vec3 eyeN = cross(dFdx(eyeViewPos), dFdy(eyeViewPos));
        float eyeNLen = dot(eyeN, eyeN);
        if (eyeNLen > 0.0000001) {
            eyeN *= inversesqrt(eyeNLen);
            if (dot(eyeN, eyeViewPos) > 0.0) eyeN = -eyeN;
            float eyeAstro = dot(eyeN, normalize(sunPosition));
            float eyeSun = clamp(mix(-eyeAstro, eyeAstro, dayNightMix), 0.0, 1.0);
            blockColor.rgb *= mix(PLAYER_EYE_SHADE_FLOOR, 1.0, eyeSun);
        }
    }

    #include "/src/writebuffers.glsl"
}
