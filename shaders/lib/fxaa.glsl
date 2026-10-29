const float quality[12] = float[12] (1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.5f, 2.0f, 2.0f, 2.0f, 2.0f, 4.0f, 8.0f);

vec3 fxaa311(vec3 color, int iterations){
  vec3 aa = color;

  float edgeThresholdMin = 0.03125f;
  float edgeThresholdMax = 0.0625f;
  float subpixelQuality = 0.75f;

  float lumaCenter = luma(color);

  float lumaDown = luma(texture2DLod(colortex1, texcoord.xy + vec2(0.0,-pixelSizeY), 0.0).rgb);
  float lumaUp = luma(texture2DLod(colortex1, texcoord.xy + vec2(0.0,pixelSizeY), 0.0).rgb);
  float lumaLeft = luma(texture2DLod(colortex1, texcoord.xy + vec2(-pixelSizeX, 0.0), 0.0).rgb);
  float lumaRight = luma(texture2DLod(colortex1, texcoord.xy + vec2(pixelSizeX, 0.0), 0.0).rgb);

  float lumaMin = min(lumaCenter, min(min(lumaDown, lumaUp), min(lumaLeft, lumaRight)));
  float lumaMax = max(lumaCenter, max(max(lumaDown, lumaUp), max(lumaLeft, lumaRight)));

  float lumaRange = lumaMax - lumaMin;

  if (lumaRange > max(edgeThresholdMin, lumaMax * edgeThresholdMax)) {

    float lumaDownLeft = luma(texture2DLod(colortex1, texcoord.xy + vec2(-pixelSizeX, -pixelSizeY), 0.0).rgb);
    float lumaUpRight = luma(texture2DLod(colortex1, texcoord.xy + vec2(pixelSizeX, pixelSizeY), 0.0).rgb);
    float lumaUpLeft = luma(texture2DLod(colortex1, texcoord.xy + vec2(-pixelSizeX, pixelSizeY), 0.0).rgb);
    float lumaDownRight = luma(texture2DLod(colortex1, texcoord.xy + vec2(pixelSizeX, -pixelSizeY), 0.0).rgb);

    float lumaDownUp = lumaDown + lumaUp;
    float lumaLeftRight = lumaLeft + lumaRight;

    float lumaLeftCorners = lumaDownLeft + lumaUpLeft;
    float lumaDownCorners = lumaDownLeft + lumaDownRight;
    float lumaRightCorners = lumaDownRight + lumaUpRight;
    float lumaUpCorners = lumaUpRight + lumaUpLeft;

    float edgeHorizontal = abs(-2.0f * lumaLeft + lumaLeftCorners) + abs(-2.0f * lumaCenter + lumaDownUp ) * 2.0f + abs(-2.0f * lumaRight + lumaRightCorners);
    float edgeVertical = abs(-2.0f * lumaUp + lumaUpCorners) + abs(-2.0f * lumaCenter + lumaLeftRight) * 2.0f + abs(-2.0f * lumaDown + lumaDownCorners);

    bool isHorizontal = (edgeHorizontal >= edgeVertical);

    float luma1 = isHorizontal ? lumaDown : lumaLeft;
    float luma2 = isHorizontal ? lumaUp : lumaRight;

    float gradient1 = luma1 - lumaCenter;
    float gradient2 = luma2 - lumaCenter;

    bool is1Steepest = abs(gradient1) >= abs(gradient2);

    float gradientScaled = 0.25f*max(abs(gradient1), abs(gradient2));

    float stepLength = isHorizontal ? pixelSizeY : pixelSizeX;

    float lumaLocalAverage = 0.0;

    if (is1Steepest){

      stepLength = - stepLength;
      lumaLocalAverage = 0.5f*(luma1 + lumaCenter);
    } else {
      lumaLocalAverage = 0.5f*(luma2 + lumaCenter);
    }

    vec2 currentUv = texcoord.xy;
    if (isHorizontal){
      currentUv.y += stepLength * 0.5f;
    } else {
      currentUv.x += stepLength * 0.5f;
    }

    vec2 offset = isHorizontal ? vec2(pixelSizeX, 0.0) : vec2(0.0, pixelSizeY);

    vec2 uv1 = currentUv - offset;
    vec2 uv2 = currentUv + offset;

    float lumaEnd1 = luma(texture2DLod(colortex1, uv1, 0.0).rgb);
    float lumaEnd2 = luma(texture2DLod(colortex1, uv2, 0.0).rgb);
    lumaEnd1 -= lumaLocalAverage;
    lumaEnd2 -= lumaLocalAverage;

    bool reached1 = abs(lumaEnd1) >= gradientScaled;
    bool reached2 = abs(lumaEnd2) >= gradientScaled;
    bool reachedBoth = reached1 && reached2;

    if (!reached1){
      uv1 -= offset;
    }
    if (!reached2){
      uv2 += offset;
    }

    if (!reachedBoth) {
      for(int i = 2; i < iterations; i++) {

        if (!reached1) {
          lumaEnd1 = luma(texture2DLod(colortex1, uv1, 0.0).rgb);
          lumaEnd1 = lumaEnd1 - lumaLocalAverage;
        }

        if (!reached2) {
          lumaEnd2 = luma(texture2DLod(colortex1, uv2, 0.0).rgb);
          lumaEnd2 = lumaEnd2 - lumaLocalAverage;
        }

        reached1 = abs(lumaEnd1) >= gradientScaled;
        reached2 = abs(lumaEnd2) >= gradientScaled;
        reachedBoth = reached1 && reached2;

        if (!reached1) {
          uv1 -= offset * quality[i];
        }
        if (!reached2) {
          uv2 += offset * quality[i];
        }

        if (reachedBoth) {
          break;
        }
      }
    }

    float distance1 = isHorizontal ? (texcoord.x - uv1.x) : (texcoord.y - uv1.y);
    float distance2 = isHorizontal ? (uv2.x - texcoord.x) : (uv2.y - texcoord.y);

    bool isDirection1 = distance1 < distance2;
    float distanceFinal = min(distance1, distance2);

    float edgeThickness = (distance1 + distance2);

    float pixelOffset = - distanceFinal / edgeThickness + 0.5f;

    bool isLumaCenterSmaller = lumaCenter < lumaLocalAverage;

    bool correctVariation = ((isDirection1 ? lumaEnd1 : lumaEnd2) < 0.0) != isLumaCenterSmaller;

    float finalOffset = correctVariation ? pixelOffset : 0.0f;

    float lumaAverage = (1.0f/12.0f) * (2.0f * (lumaDownUp + lumaLeftRight) + lumaLeftCorners + lumaRightCorners);

    float subPixelOffset1 = clamp(abs(lumaAverage - lumaCenter)/lumaRange,0.0f,1.0f);
    float subPixelOffset2 = (-2.0f * subPixelOffset1 + 3.0f) * subPixelOffset1 * subPixelOffset1;

    float subPixelOffsetFinal = subPixelOffset2 * subPixelOffset2 * subpixelQuality;

    finalOffset = max(finalOffset, subPixelOffsetFinal);

    vec2 finalUv = texcoord.xy;
    if (isHorizontal){
      finalUv.y += finalOffset * stepLength;
    } else {
      finalUv.x += finalOffset * stepLength;
    }

    aa = texture2DLod(colortex1, finalUv, 0.0).rgb;
  }

  return aa;
}
