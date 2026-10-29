#include "/lib/config.glsl"

/*
const int noisetexFormat = RG8;
const int colortex0Format = R11F_G11F_B10F;
*/
#ifdef DOF
/*
const int colortex1Format = RGBA16F;
*/
#else
/*
const int colortex1Format = R11F_G11F_B10F;
*/
#endif
#ifdef GLEAM_LIGHT_BUFFERS
/*
const int colortex2Format = RGBA16F;
const int colortex9Format = RGBA8;
*/
const bool colortex9Clear = true;
#if GLEAM_RSM_GI > 0
/*
const int colortex10Format = RGBA16F;
const int colortex14Format = RGBA16F;
*/
const bool colortex10Clear = false;
const bool colortex14Clear = true;
#endif
#if GLEAM_VOXEL_LIGHT > 0
/*
const int colortex11Format = RGBA8;
const int colortex12Format = RGBA16F;
const int colortex13Format = RGBA16F;
const int colortex15Format = RGBA16F;
*/
const bool colortex11Clear = true;
const bool colortex12Clear = true;
const bool colortex13Clear = false;
const bool colortex15Clear = true;
#endif
#if GLEAM_VOXEL_LIGHT > 0
/*
const int colortex8Format = RGBA16F;
*/
const bool colortex8Clear = false;
#endif
#else
/*
const int colortex2Format = R8;
*/
#endif
#ifdef DOF
/*
const int colortex3Format = RGBA16F;
*/
#else
/*
const int colortex3Format = R11F_G11F_B10F;
*/
#endif
/*
const int gaux1Format = R11F_G11F_B10F;
const int gaux2Format = R8;
const int gaux3Format = R11F_G11F_B10F;
const int gaux4Format = R11F_G11F_B10F;
const int shadowcolor0Format = RGBA8;
*/

const bool colortex0Clear = false;
const bool colortex1Clear = false;
#ifdef GLEAM_LIGHT_BUFFERS
const bool colortex2Clear = true;
#else
const bool colortex2Clear = false;
#endif
const bool colortex3Clear = false;
const bool gaux1Clear = false;
const bool gaux2Clear = false;
const bool gaux3Clear = false;
const bool gaux4Clear = false;

#ifdef DEBUG_MODE
    uniform sampler2D shadowtex1;
    uniform sampler2D shadowcolor0;
    uniform sampler2D colortex3;
#endif

uniform sampler2D colortex1;
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;

#if GLEAM_LETTERBOX == 1
    uniform float letterboxAmount;
#endif

#if GLEAM_OUTLINES == 1 || GLEAM_CEL == 1
    uniform sampler2D depthtex0;
    uniform float near;
    uniform float far;

    #if !(AA_TYPE == 3 || defined IMAGE_SHARPENING)
        uniform float pixelSizeX;
        uniform float pixelSizeY;
    #endif
#endif

#if AA_TYPE == 3 || defined IMAGE_SHARPENING
    uniform float pixelSizeX;
    uniform float pixelSizeY;
#endif

varying vec2 texcoord;

#if PIXELATION > 0
    vec2 pixelTexcoord;
    #define texcoord pixelTexcoord
#endif

#include "/lib/luma.glsl"

#if AA_TYPE == 3
    #include "/lib/fxaa.glsl"
#endif

#include "/lib/basic_utils.glsl"
#include "/lib/tone_maps.glsl"

#ifdef COLOR_BLINDNESS
    #include "/lib/color_blindness.glsl"
#endif

#if CHROMA_ABER == 1
    #include "/lib/aberration.glsl"
#endif

#ifdef IMAGE_SHARPENING
    #include "/lib/cas.glsl"
#endif

float grainHash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

#if GLEAM_OUTLINES == 1
    float outlineInverseDepth(vec2 uv) {
        float d = texture2D(depthtex0, uv).r;
        return (far - d * (far - near)) / (near * far);
    }

    float outlineMask(vec2 uv, float widthScale) {
        float centerInv = outlineInverseDepth(uv);
        float centerDist = 1.0 / max(centerInv, 0.000001);

        float fadeEnd = far * OUTLINE_DISTANCE;
        float distanceFade = 1.0 - smoothstep(fadeEnd * 0.45, fadeEnd, centerDist);

        if (distanceFade <= 0.001) {
            return 0.0;
        }

        float resolutionScale = max(viewHeight / 1080.0, 1.0) * 1.15;
        vec2 px = vec2(pixelSizeX, pixelSizeY) * (OUTLINE_THICKNESS * widthScale * resolutionScale * mix(1.0, 0.6, 1.0 - distanceFade));
        vec2 dg = px * 0.7071068;

        float sE = outlineInverseDepth(uv + vec2(px.x, 0.0));
        float sW = outlineInverseDepth(uv - vec2(px.x, 0.0));
        float sN = outlineInverseDepth(uv + vec2(0.0, px.y));
        float sS = outlineInverseDepth(uv - vec2(0.0, px.y));
        float sNE = outlineInverseDepth(uv + dg);
        float sSW = outlineInverseDepth(uv - dg);
        float sNW = outlineInverseDepth(uv + vec2(-dg.x, dg.y));
        float sSE = outlineInverseDepth(uv + vec2(dg.x, -dg.y));

        float lapAxis = max(centerInv - 0.5 * (sE + sW), centerInv - 0.5 * (sN + sS));
        float lapDiag = max(centerInv - 0.5 * (sNE + sSW), centerInv - 0.5 * (sNW + sSE));
        float relative = min(lapAxis, lapDiag) / centerInv;

        float edge = smoothstep(0.035, 0.11, relative);

        float threshold = centerInv * 0.88;
        float farCount = step(sE, threshold) + step(sW, threshold) + step(sN, threshold) + step(sS, threshold) +
            step(sNE, threshold) + step(sSW, threshold) + step(sNW, threshold) + step(sSE, threshold);
        float farFraction = farCount * 0.125;
        float speckle = 1.0 - smoothstep(0.80, 0.97, farFraction);

        return edge * speckle * distanceFade;
    }
#endif

void main() {
    #if PIXELATION > 0
        pixelTexcoord = (floor(gl_FragCoord.xy / float(PIXELATION)) + 0.5) * float(PIXELATION) * vec2(1.0 / viewWidth, 1.0 / viewHeight);
    #endif

    #if CHROMA_ABER == 1
        vec3 blockColor = color_aberration();
    #else
        vec3 blockColor;

        #ifdef IMAGE_SHARPENING
            blockColor = CAS(texcoord);
        #else
            blockColor = texture2D(colortex1, texcoord).rgb;
        #endif

        #if AA_TYPE == 3 && !defined DOF
            blockColor = fxaa311(blockColor, 5);
        #endif
    #endif

    blockColor *= vec3(GLEAM_EXPOSURE * GLEAM_STYLE_EXPOSURE_MULT);
    blockColor = custom_sigmoid(blockColor);

    float toneLuma = luma(blockColor);

    vec3 shadowTint = STYLE_SPLIT_SHADOW - vec3(luma(STYLE_SPLIT_SHADOW));
    vec3 highTint = STYLE_SPLIT_HIGH - vec3(luma(STYLE_SPLIT_HIGH));
    float shadowWeight = 1.0 - smoothstep(0.0, 0.5, toneLuma);
    float highWeight = smoothstep(0.35, 1.0, toneLuma);
    blockColor += (shadowTint * shadowWeight + highTint * highWeight) * STYLE_SPLIT_STRENGTH;

    blockColor *= vec3(
        1.0 + GRADE_WARMTH * 0.08 + GRADE_TINT * 0.04,
        1.0 - GRADE_TINT * 0.06,
        1.0 - GRADE_WARMTH * 0.08 + GRADE_TINT * 0.04
    );

    float coolMask = 1.0 - smoothstep(0.30, 0.95, toneLuma);
    blockColor *= mix(vec3(1.0), vec3(0.93, 0.985, 1.10), STYLE_COOL_GRADE * coolMask);

    float gradeLuma = luma(blockColor);

    float chroma = max(max(blockColor.r, blockColor.g), blockColor.b) - min(min(blockColor.r, blockColor.g), blockColor.b);
    blockColor = mix(vec3(gradeLuma), blockColor, 1.0 + (GRADE_VIBRANCE + STYLE_VIBRANCE) * (1.0 - clamp(chroma * 1.6, 0.0, 1.0)));

    blockColor = mix(vec3(gradeLuma), blockColor, GLEAM_SATURATION * GLEAM_STYLE_SATURATION_MULT);
    blockColor = (blockColor - 0.5) * (GLEAM_CONTRAST * GLEAM_STYLE_CONTRAST_MULT) + 0.5;

    float lkLuma = luma(blockColor);
    blockColor += vec3(GRADE_SHADOWS * 0.06) * (1.0 - smoothstep(0.0, 0.5, lkLuma));
    blockColor *= 1.0 + GRADE_HIGHLIGHTS * 0.12 * smoothstep(0.5, 1.0, lkLuma);
    blockColor = pow(max(blockColor, vec3(0.0)), vec3(1.0 / GRADE_GAMMA));
    blockColor = blockColor * (1.0 - GRADE_FADE) + vec3(GRADE_FADE);

    #if COLOR_FILTER > 0
        float lkTone = smoothstep(0.15, 0.85, luma(blockColor));
        vec3 lkLook = blockColor;
        #if COLOR_FILTER == 1
            lkLook = vec3(luma(blockColor)) * vec3(1.14, 0.97, 0.74);
        #elif COLOR_FILTER == 2
            lkLook = (vec3(luma(blockColor)) - 0.5) * 1.18 + 0.5;
        #elif COLOR_FILTER == 3
            lkLook = blockColor * mix(vec3(0.86, 1.02, 1.14), vec3(1.14, 1.0, 0.84), lkTone);
        #elif COLOR_FILTER == 4
            lkLook = mix(blockColor, vec3(luma(blockColor)), 0.22) * 0.88 + vec3(0.10);
        #elif COLOR_FILTER == 5
            lkLook = blockColor * mix(vec3(1.06, 0.90, 1.04), vec3(1.12, 0.98, 0.84), lkTone);
        #endif
        blockColor = mix(blockColor, lkLook, COLOR_FILTER_STRENGTH);
    #endif

    float hrPeak = max(max(blockColor.r, blockColor.g), blockColor.b);
    float hrOver = max(hrPeak - 0.78, 0.0);
    float hrScale = hrPeak > 0.78 ? (0.78 + hrOver / (1.0 + hrOver * HIGHLIGHT_ROLLOFF * 3.0)) / hrPeak : 1.0;
    blockColor *= hrScale;

    #if GLEAM_CEL == 1
        float celLuma = min(luma(blockColor), 1.0);
        float celScaled = celLuma * float(CEL_BANDS);
        float celBase = floor(celScaled);
        float celStep = celBase + smoothstep(0.25, 0.75, celScaled - celBase);
        float celTarget = celStep / float(CEL_BANDS);
        vec3 celColor = blockColor * (max(celTarget, 0.02) / max(celLuma, 0.02));
        float celSolid = step(texture2D(depthtex0, texcoord).r, 0.9999);
        blockColor = mix(blockColor, celColor, CEL_STRENGTH * celSolid);
    #endif

    #if GLEAM_OUTLINES == 1
        #if GLEAM_COLOR_STYLE == 5
            float outlineEdge = outlineMask(texcoord, 1.7);
            float outlineBoost = 1.1;
        #else
            float outlineEdge = outlineMask(texcoord, 1.0);
            float outlineBoost = 1.0;
        #endif
        vec3 outlineTint = vec3(OUTLINE_COLOR_R, OUTLINE_COLOR_G, OUTLINE_COLOR_B);
        vec3 outlineInk = outlineTint + blockColor * 0.04;
        blockColor = mix(blockColor, outlineInk, clamp(outlineEdge * OUTLINE_STRENGTH * outlineBoost, 0.0, 1.0));
    #endif

    #if GLEAM_STYLE_VIGNETTE == 1
        vec2 vignetteCoord = (texcoord - 0.5) * vec2(1.0, 0.925);
        float vignetteFactor = 1.0 - smoothstep(0.35, 0.95, length(vignetteCoord) * 1.35) * VIGNETTE_STRENGTH;
        blockColor *= vignetteFactor;
    #endif

    #if GLEAM_GRAIN == 1
        float grain = grainHash(gl_FragCoord.xy + mod(float(frameCounter), 64.0) * 17.13) - 0.5;
        float grainMask = 1.0 - abs(luma(blockColor) * 2.0 - 1.0) * 0.55;
        blockColor += grain * FILM_GRAIN_STRENGTH * grainMask;
    #endif

    #if GLEAM_LETTERBOX == 1
        float screenAspect = viewWidth / viewHeight;
        float barHeight = max(0.0, 1.0 - screenAspect / LETTERBOX_RATIO) * 0.5 * letterboxAmount;
        float barEdge = 1.0 / viewHeight;
        float barMask = smoothstep(barHeight - barEdge, barHeight + barEdge, texcoord.y) *
            smoothstep(barHeight - barEdge, barHeight + barEdge, 1.0 - texcoord.y);
        blockColor *= barMask;
    #endif

    #if ANTI_BANDING == 1
        float bandNoise = fract(52.9829189 * fract(dot(gl_FragCoord.xy + mod(float(frameCounter), 16.0) * 5.37, vec2(0.06711056, 0.00583715)))) - 0.5;
        blockColor += bandNoise * (1.0 / 255.0);
    #endif

    blockColor = max(blockColor, vec3(0.0));

    #ifdef COLOR_BLINDNESS
        blockColor = color_blindness(blockColor);
    #endif

    #ifdef DEBUG_MODE
        if(texcoord.x < 0.5 && texcoord.y < 0.5) {
            blockColor = texture2D(shadowtex1, texcoord * 2.0).rrr;
        } else if(texcoord.x >= 0.5 && texcoord.y >= 0.5) {
            blockColor = vec3(GLEAM_EXPOSURE * 0.25);
        } else if(texcoord.x < 0.5 && texcoord.y >= 0.5) {
            blockColor = texture2D(colortex1, ((texcoord - vec2(0.0, 0.5)) * 2.0)).rgb;
        } else if(texcoord.x >= 0.5 && texcoord.y < 0.5) {
            blockColor = texture2D(shadowcolor0, ((texcoord - vec2(0.5, 0.0)) * 2.0)).rgb;
        } else {
            blockColor = vec3(0.5);
        }

        gl_FragData[0] = vec4(blockColor, 1.0);
    #else
        gl_FragData[0] = vec4(blockColor, 1.0);
    #endif
}
