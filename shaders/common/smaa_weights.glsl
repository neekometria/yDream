#include "/lib/config.glsl"

// SMAA blending-weight calculation, ported to a single fullscreen pass.
// Edges come from the previous pass (composite4, colortex6); the area/search
// lookup textures are the standard SMAA 2.8 textures.
#define SMAA_AREATEX_MAX_DISTANCE 16.0
#define SMAA_AREATEX_MAX_DISTANCE_DIAG 20.0
#define SMAA_AREATEX_PIXEL_SIZE vec2(1.0 / 160.0, 1.0 / 560.0)
#define SMAA_AREATEX_SUBTEX_SIZE (1.0 / 7.0)
#define SMAA_SEARCHTEX_SIZE vec2(66.0, 33.0)
#define SMAA_SEARCHTEX_PACKED_SIZE vec2(64.0, 16.0)
#define SMAA_CORNER_ROUNDING_NORM 0.25
#define SMAA_MAX_SEARCH_STEPS 16
#define SMAA_MAX_SEARCH_STEPS_DIAG 8

// colortex0 is free at this point in the pipeline (the scene lives in
// colortex1), so the packed weights go there and colortex7 is left alone for
// the fog texture.
const bool colortex0Clear = false;

uniform sampler2D colortex6;
uniform sampler2D smaaAreaTex;
uniform sampler2D smaaSearchTex;
uniform float pixelSizeX;
uniform float pixelSizeY;
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;

varying vec2 texcoord;

// SMAA T2x alternates the area-LUT subpixel offsets every frame so that the
// two jitter phases resolve into one image after exactly two frames. The
// values must stay in sync with the taaOffset phases in shaders.properties.
vec4 smaaSubsampleIndices() {
    #if AA_MODE == 5
        return (mod(float(frameCounter), 2.0) < 0.5) ? vec4(1.0, 1.0, 1.0, 0.0) : vec4(2.0, 2.0, 2.0, 0.0);
    #else
        return vec4(0.0);
    #endif
}

vec2 vOffset0;
vec2 vOffset1;
vec4 vOffset2;
vec2 pixCoord;

#define mad(a, b, c) ((a) * (b) + (c))
#define saturate(a) clamp(a, 0.0, 1.0)
#define round(v) floor((v) + 0.5)
#define SMAASampleLevelZeroOffset(tex, coord, offset) texture2DLod(tex, (coord) + (offset) * vec2(pixelSizeX, pixelSizeY), 0.0)

void SMAAMovc(bvec2 cond, inout vec2 variable, vec2 value) {
    if (cond.x) variable.x = value.x;
    if (cond.y) variable.y = value.y;
}

void SMAAMovc(bvec4 cond, inout vec4 variable, vec4 value) {
    SMAAMovc(cond.xy, variable.xy, value.xy);
    SMAAMovc(cond.zw, variable.zw, value.zw);
}

vec2 SMAADecodeDiagBilinearAccess(vec2 e) {
    e.r = e.r * abs(5.0 * e.r - 5.0 * 0.75);
    return round(e);
}

vec4 SMAADecodeDiagBilinearAccess(vec4 e) {
    e.rb = e.rb * abs(5.0 * e.rb - 5.0 * 0.75);
    return round(e);
}

vec2 SMAASearchDiag1(vec2 start, vec2 dir, out vec2 e) {
    vec4 coord = vec4(start, -1.0, 1.0);
    vec3 t = vec3(pixelSizeX, pixelSizeY, 1.0);

    for (int i = 0; i < SMAA_MAX_SEARCH_STEPS_DIAG; i++) {
        if (!(coord.z < float(SMAA_MAX_SEARCH_STEPS_DIAG - 1) && coord.w > 0.9)) break;
        coord.xyz = mad(t, vec3(dir, 1.0), coord.xyz);
        e = texture2DLod(colortex6, coord.xy, 0.0).rg;
        coord.w = dot(e, vec2(0.5));
    }
    return coord.zw;
}

vec2 SMAASearchDiag2(vec2 start, vec2 dir, out vec2 e) {
    vec4 coord = vec4(start, -1.0, 1.0);
    coord.x += 0.25 * pixelSizeX;
    vec3 t = vec3(pixelSizeX, pixelSizeY, 1.0);

    for (int i = 0; i < SMAA_MAX_SEARCH_STEPS_DIAG; i++) {
        if (!(coord.z < float(SMAA_MAX_SEARCH_STEPS_DIAG - 1) && coord.w > 0.9)) break;
        coord.xyz = mad(t, vec3(dir, 1.0), coord.xyz);
        e = texture2DLod(colortex6, coord.xy, 0.0).rg;
        e = SMAADecodeDiagBilinearAccess(e);
        coord.w = dot(e, vec2(0.5));
    }
    return coord.zw;
}

vec2 SMAAAreaDiag(vec2 dist, vec2 e, float offset) {
    vec2 areaCoord = mad(vec2(SMAA_AREATEX_MAX_DISTANCE_DIAG), e, dist);
    areaCoord = mad(SMAA_AREATEX_PIXEL_SIZE, areaCoord, 0.5 * SMAA_AREATEX_PIXEL_SIZE);
    areaCoord.x += 0.5;
    areaCoord.y += SMAA_AREATEX_SUBTEX_SIZE * offset;
    return texture2DLod(smaaAreaTex, areaCoord, 0.0).rg;
}

vec2 SMAACalculateDiagWeights(vec2 uv, vec2 e, vec4 subsamples) {
    vec2 weights = vec2(0.0);

    vec4 d;
    vec2 end;
    if (e.r > 0.0) {
        d.xz = SMAASearchDiag1(uv, vec2(-1.0, 1.0), end);
        d.x += float(end.y > 0.9);
    } else {
        d.xz = vec2(0.0);
    }
    d.yw = SMAASearchDiag1(uv, vec2(1.0, -1.0), end);

    if (d.x + d.y > 2.0) {
        vec4 coords = mad(vec4(-d.x + 0.25, d.x, d.y, -d.y - 0.25), vec4(pixelSizeX, pixelSizeY, pixelSizeX, pixelSizeY), uv.xyxy);
        vec4 c;
        c.xy = SMAASampleLevelZeroOffset(colortex6, coords.xy, vec2(-1.0, 0.0)).rg;
        c.zw = SMAASampleLevelZeroOffset(colortex6, coords.zw, vec2(1.0, 0.0)).rg;
        c.yxwz = SMAADecodeDiagBilinearAccess(c.xyzw);

        vec2 cc = mad(vec2(2.0), c.xz, c.yw);
        SMAAMovc(bvec2(step(0.9, d.zw)), cc, vec2(0.0));
        weights += SMAAAreaDiag(d.xy, cc, subsamples.z);
    }

    d.xz = SMAASearchDiag2(uv, vec2(-1.0, -1.0), end);
    if (SMAASampleLevelZeroOffset(colortex6, uv, vec2(1.0, 0.0)).r > 0.0) {
        d.yw = SMAASearchDiag2(uv, vec2(1.0, 1.0), end);
        d.y += float(end.y > 0.9);
    } else {
        d.yw = vec2(0.0);
    }

    if (d.x + d.y > 2.0) {
        vec4 coords = mad(vec4(-d.x, -d.x, d.y, d.y), vec4(pixelSizeX, pixelSizeY, pixelSizeX, pixelSizeY), uv.xyxy);
        vec4 c;
        c.x = SMAASampleLevelZeroOffset(colortex6, coords.xy, vec2(-1.0, 0.0)).g;
        c.y = SMAASampleLevelZeroOffset(colortex6, coords.xy, vec2(0.0, -1.0)).r;
        c.zw = SMAASampleLevelZeroOffset(colortex6, coords.zw, vec2(1.0, 0.0)).gr;
        vec2 cc = mad(vec2(2.0), c.xz, c.yw);
        SMAAMovc(bvec2(step(0.9, d.zw)), cc, vec2(0.0));
        weights += SMAAAreaDiag(d.xy, cc, subsamples.w).gr;
    }

    return weights;
}

float SMAASearchLength(vec2 e, float offset) {
    vec2 scale = SMAA_SEARCHTEX_SIZE * vec2(0.5, -1.0);
    vec2 bias = SMAA_SEARCHTEX_SIZE * vec2(offset, 1.0);

    scale += vec2(-1.0, 1.0);
    bias += vec2(0.5, -0.5);

    scale *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;
    bias *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;

    return texture2DLod(smaaSearchTex, mad(scale, e, bias), 0.0).r;
}

float SMAASearchXLeft(vec2 uv, float end) {
    vec2 e = vec2(0.0, 1.0);
    for (int i = 0; i < SMAA_MAX_SEARCH_STEPS; i++) {
        if (!(uv.x > end && e.g > 0.8281 && e.r == 0.0)) break;
        e = texture2DLod(colortex6, uv, 0.0).rg;
        uv = mad(-vec2(2.0, 0.0), vec2(pixelSizeX, pixelSizeY), uv);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(e, 0.0), 3.25);
    return mad(pixelSizeX, offset, uv.x);
}

float SMAASearchXRight(vec2 uv, float end) {
    vec2 e = vec2(0.0, 1.0);
    for (int i = 0; i < SMAA_MAX_SEARCH_STEPS; i++) {
        if (!(uv.x < end && e.g > 0.8281 && e.r == 0.0)) break;
        e = texture2DLod(colortex6, uv, 0.0).rg;
        uv = mad(vec2(2.0, 0.0), vec2(pixelSizeX, pixelSizeY), uv);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(e, 0.5), 3.25);
    return mad(-pixelSizeX, offset, uv.x);
}

float SMAASearchYUp(vec2 uv, float end) {
    vec2 e = vec2(1.0, 0.0);
    for (int i = 0; i < SMAA_MAX_SEARCH_STEPS; i++) {
        if (!(uv.y > end && e.r > 0.8281 && e.g == 0.0)) break;
        e = texture2DLod(colortex6, uv, 0.0).rg;
        uv = mad(-vec2(0.0, 2.0), vec2(pixelSizeX, pixelSizeY), uv);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(e.gr, 0.0), 3.25);
    return mad(pixelSizeY, offset, uv.y);
}

float SMAASearchYDown(vec2 uv, float end) {
    vec2 e = vec2(1.0, 0.0);
    for (int i = 0; i < SMAA_MAX_SEARCH_STEPS; i++) {
        if (!(uv.y < end && e.r > 0.8281 && e.g == 0.0)) break;
        e = texture2DLod(colortex6, uv, 0.0).rg;
        uv = mad(vec2(0.0, 2.0), vec2(pixelSizeX, pixelSizeY), uv);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(e.gr, 0.5), 3.25);
    return mad(-pixelSizeY, offset, uv.y);
}

vec2 SMAAArea(vec2 dist, float e1, float e2, float offset) {
    vec2 areaCoord = mad(vec2(SMAA_AREATEX_MAX_DISTANCE), round(4.0 * vec2(e1, e2)), dist);
    areaCoord = mad(SMAA_AREATEX_PIXEL_SIZE, areaCoord, 0.5 * SMAA_AREATEX_PIXEL_SIZE);
    areaCoord.y = mad(SMAA_AREATEX_SUBTEX_SIZE, offset, areaCoord.y);
    return texture2DLod(smaaAreaTex, areaCoord, 0.0).rg;
}

void SMAADetectHorizontalCornerPattern(inout vec2 weights, vec4 coords, vec2 d) {
    vec2 leftRight = step(d.xy, d.yx);
    vec2 rounding = (1.0 - SMAA_CORNER_ROUNDING_NORM) * leftRight;
    rounding /= leftRight.x + leftRight.y;

    vec2 factor = vec2(1.0);
    factor.x -= rounding.x * SMAASampleLevelZeroOffset(colortex6, coords.xy, vec2(0.0, 1.0)).r;
    factor.x -= rounding.y * SMAASampleLevelZeroOffset(colortex6, coords.zw, vec2(1.0, 1.0)).r;
    factor.y -= rounding.x * SMAASampleLevelZeroOffset(colortex6, coords.xy, vec2(0.0, -2.0)).r;
    factor.y -= rounding.y * SMAASampleLevelZeroOffset(colortex6, coords.zw, vec2(1.0, -2.0)).r;

    weights *= saturate(factor);
}

void SMAADetectVerticalCornerPattern(inout vec2 weights, vec4 coords, vec2 d) {
    vec2 leftRight = step(d.xy, d.yx);
    vec2 rounding = (1.0 - SMAA_CORNER_ROUNDING_NORM) * leftRight;
    rounding /= leftRight.x + leftRight.y;

    vec2 factor = vec2(1.0);
    factor.x -= rounding.x * SMAASampleLevelZeroOffset(colortex6, coords.xy, vec2(1.0, 0.0)).g;
    factor.x -= rounding.y * SMAASampleLevelZeroOffset(colortex6, coords.zw, vec2(1.0, 1.0)).g;
    factor.y -= rounding.x * SMAASampleLevelZeroOffset(colortex6, coords.xy, vec2(-2.0, 0.0)).g;
    factor.y -= rounding.y * SMAASampleLevelZeroOffset(colortex6, coords.zw, vec2(-2.0, 1.0)).g;

    weights *= saturate(factor);
}

void main() {
    vec2 texel = vec2(pixelSizeX, pixelSizeY);
    float searchX = 2.0 * float(SMAA_MAX_SEARCH_STEPS) * pixelSizeX;
    float searchY = 2.0 * float(SMAA_MAX_SEARCH_STEPS) * pixelSizeY;
    vec4 subsampleIndices = smaaSubsampleIndices();

    vOffset0 = mad(texel, vec2(-0.25, -0.125), texcoord);
    vOffset1 = mad(texel, vec2(-0.125, -0.25), texcoord);

    vOffset2.x = vOffset0.x - searchX;
    vOffset2.y = vOffset0.x + 1.5 * pixelSizeX + searchX;
    vOffset2.z = vOffset1.y - searchY;
    vOffset2.w = vOffset1.y + 1.5 * pixelSizeY + searchY;

    pixCoord = gl_FragCoord.xy;

    vec4 weights = vec4(0.0);
    vec2 e = texture2DLod(colortex6, texcoord, 0.0).rg;

    if (e.g > 0.0) {
        weights.rg = SMAACalculateDiagWeights(texcoord, e, subsampleIndices);

        if (weights.r == -weights.g) {
            vec3 coords;
            coords.x = SMAASearchXLeft(vOffset0, vOffset2.x);
            coords.y = texcoord.y - 0.25 * pixelSizeY;
            coords.z = SMAASearchXRight(vOffset0 + vec2(1.5, 0.0) * texel, vOffset2.y);

            vec2 d = abs(round(mad(vec2(viewWidth), vec2(coords.x, coords.z), -vec2(pixCoord.x))));
            vec2 sqrtD = sqrt(d);

            float e1 = texture2DLod(colortex6, coords.xy, 0.0).r;
            float e2 = SMAASampleLevelZeroOffset(colortex6, coords.zy, vec2(1.0, 0.0)).r;

            weights.rg = SMAAArea(sqrtD, e1, e2, subsampleIndices.y);

            vec4 cornerCoords = vec4(coords.x, texcoord.y, coords.z, texcoord.y);
            SMAADetectHorizontalCornerPattern(weights.rg, cornerCoords, d);
        } else {
            e.r = 0.0;
        }
    }

    if (e.r > 0.0) {
        vec3 coords;
        coords.y = SMAASearchYUp(vOffset1, vOffset2.z);
        coords.x = texcoord.x - 0.25 * pixelSizeX;
        coords.z = SMAASearchYDown(vOffset1 + vec2(0.0, 1.5) * texel, vOffset2.w);

        vec2 d = abs(round(mad(vec2(viewHeight), vec2(coords.y, coords.z), -vec2(pixCoord.y))));
        vec2 sqrtD = sqrt(d);

        float e1 = texture2DLod(colortex6, coords.xy, 0.0).g;
        float e2 = SMAASampleLevelZeroOffset(colortex6, coords.xz, vec2(0.0, 1.0)).g;

        weights.ba = SMAAArea(sqrtD, e1, e2, subsampleIndices.x);

        vec4 cornerCoords = vec4(texcoord.x, coords.y, texcoord.x, coords.z);
        SMAADetectVerticalCornerPattern(weights.ba, cornerCoords, d);
    }

    weights = clamp(weights, 0.0, 1.0);

    // The whole weight set is packed in one RGBA texture so the blend pass can
    // gather left/top/bottom/right from the canonical SMAA offsets.
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = weights;
}
