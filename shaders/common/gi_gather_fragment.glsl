#include "/lib/config.glsl"

#define GI_PASS_GATHER


uniform sampler2D depthtex0;
// Usado só como repasse quando o GI RSM está desligado (ver final do main).
uniform sampler2D colortex2;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform vec3 sunPosition;
uniform float pixelSizeX;
uniform float pixelSizeY;

varying vec2 texcoord;

#if YDREAM_RSM_GI > 0
    #include "/lib/gi_light.glsl"
#endif

void main() {
    vec4 result = vec4(0.0);

    #if YDREAM_RSM_GI > 0
        float depth = texture2DLod(depthtex0, texcoord, 0.0).r;

        if (depth < 0.99999 && depth > 0.56) {
            result = giGather(texcoord, depth, giNoise(gl_FragCoord.xy));
        }
    #endif

    #if YDREAM_RSM_GI > 0
        /* DRAWBUFFERS:2 */
        gl_FragData[0] = result;
    #else
        // GI RSM desligado: repassa colortex2 sem alterar. O passe nem deveria
        // rodar (program.deferred2.enabled fica false no shaders.properties),
        // mas se rodar não deve apagar o conteúdo do buffer.
        /* DRAWBUFFERS:2 */
        gl_FragData[0] = texture2DLod(colortex2, texcoord, 0.0);
    #endif
}
