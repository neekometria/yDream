#include "/lib/config.glsl"

// SMAA edge detection (composite4). The two channels are horizontal (west)
// and vertical (north) edges. The result is consumed by the weight pass.
#define SMAA_THRESHOLD 0.07
#define SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR 2.0
#define SMAA_MAX_SEARCH_STEPS 16

const bool colortex6Clear = false;

uniform sampler2D colortex1;
uniform float pixelSizeX;
uniform float pixelSizeY;

varying vec2 texcoord;

#include "/lib/luma.glsl"

// SMAA runs before tonemapping, so the raw luma can reach ~50 and the absolute
// edge threshold would stop meaning anything: a smooth bright sky would look
// like a hard edge. Compressing to a display-like range first keeps the
// reference threshold behaviour without touching the blended colours.
float smaaLuma(vec2 uv) {
    float l = luma(texture2DLod(colortex1, uv, 0.0).rgb);
    return l / (1.0 + l);
}

vec2 smaaEdges() {
    vec2 texel = vec2(pixelSizeX, pixelSizeY);

    vec2 uvLeft = texcoord + vec2(-0.25, -0.125) * texel;
    vec2 uvTop = texcoord + vec2(1.25, -0.125) * texel;
    vec2 uvRight = texcoord + vec2(-0.125, -0.25) * texel;
    vec2 uvBottom = texcoord + vec2(-0.125, 1.25) * texel;
    // Two-pixel taps for the local contrast adaptation, exactly like the
    // reference SMAA 1x edge pass.
    vec2 uvLeftLeft = texcoord + vec2(-2.0, 0.0) * texel;
    vec2 uvTopTop = texcoord + vec2(0.0, -2.0) * texel;

    float center = smaaLuma(texcoord);
    float left = smaaLuma(uvLeft);
    float top = smaaLuma(uvTop);
    float right = smaaLuma(uvRight);
    float bottom = smaaLuma(uvBottom);
    float leftLeft = smaaLuma(uvLeftLeft);
    float topTop = smaaLuma(uvTopTop);

    vec2 delta = abs(vec2(center) - vec2(left, top));
    vec2 edges = step(vec2(SMAA_THRESHOLD), delta);

    if (dot(edges, vec2(1.0)) < 0.5) {
        return vec2(0.0);
    }

    vec2 deltaRightBottom = abs(vec2(center) - vec2(right, bottom));
    vec2 maxDelta = max(delta, deltaRightBottom);

    vec2 deltaEnds = abs(vec2(left, top) - vec2(leftLeft, topTop));
    maxDelta = max(maxDelta, deltaEnds);
    float finalDelta = max(maxDelta.x, maxDelta.y);

    edges *= step(vec2(finalDelta), SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR * delta);
    return edges;
}

void main() {
    vec2 edges = smaaEdges();
    /* DRAWBUFFERS:6 */
    gl_FragData[0] = vec4(edges, 0.0, 1.0);
}
