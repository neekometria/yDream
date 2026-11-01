// SMAA neighbourhood blending, applied straight from `final`.
//
// The blending weights are produced by the weight pass (composite5) and packed
// into colortex0; the scene stays in colortex1. Doing the blend here instead of
// in its own composite pass means the colour buffer is only ever read, never
// read *and* written in the same draw - which silently turns the blend into a
// no-op on most drivers because every pixel mostly samples its own, still
// unwritten, value.

#ifndef SMAA_BLEND_INCLUDED
#define SMAA_BLEND_INCLUDED

void SMAABlendMovc(bvec2 cond, inout vec2 variable, vec2 value) {
    if (cond.x) variable.x = value.x;
    if (cond.y) variable.y = value.y;
}

void SMAABlendMovc(bvec4 cond, inout vec4 variable, vec4 value) {
    SMAABlendMovc(cond.xy, variable.xy, value.xy);
    SMAABlendMovc(cond.zw, variable.zw, value.zw);
}

vec3 smaaBlend(vec2 uv) {
    vec2 texel = vec2(pixelSizeX, pixelSizeY);

    // Gather the weights of this pixel and the ones it blends towards. The
    // channel layout is the canonical SMAA packing: .a of the right neighbour,
    // .g of the top neighbour, and .xz of this pixel.
    vec4 a;
    a.x = texture2DLod(colortex0, uv + vec2(texel.x, 0.0), 0.0).a;
    a.y = texture2DLod(colortex0, uv + vec2(0.0, texel.y), 0.0).g;
    a.wz = texture2DLod(colortex0, uv, 0.0).xz;

    vec3 center = texture2DLod(colortex1, uv, 0.0).rgb;

    if (dot(a, vec4(1.0)) < 1e-5) {
        return center;
    }

    bool horizontal = max(a.x, a.z) > max(a.y, a.w);

    vec4 blendingOffset = vec4(0.0, a.y, 0.0, a.w);
    vec2 blendingWeight = a.yw;
    SMAABlendMovc(bvec4(horizontal), blendingOffset, vec4(a.x, 0.0, a.z, 0.0));
    SMAABlendMovc(bvec2(horizontal), blendingWeight, a.xz);
    blendingWeight /= max(dot(blendingWeight, vec2(1.0)), 1e-5);

    vec4 blendingCoord = uv.xyxy + blendingOffset * vec4(texel.x, texel.y, -texel.x, -texel.y);
    vec3 color = blendingWeight.x * texture2DLod(colortex1, blendingCoord.xy, 0.0).rgb;
    color += blendingWeight.y * texture2DLod(colortex1, blendingCoord.zw, 0.0).rgb;

    // Blend towards the neighbours, but keep the centre colour where the
    // weights are degenerate so the pass can never produce a wrong pixel.
    return mix(center, color, step(1e-5, dot(blendingWeight, vec2(1.0))));
}

#endif
