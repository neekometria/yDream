#include "/lib/config.glsl"

uniform float viewHeight;
uniform float viewWidth;

varying vec4 tintColor;

#if AA_TYPE > 0
    #include "/src/taa_offset.glsl"
#endif

#include "/lib/mu_ftransform.glsl"

void main() {
    tintColor = gl_Color;
    gl_Position = muFtransform();

    #if AA_TYPE > 0
        gl_Position.xy += taaOffset * gl_Position.w;
    #endif
}
