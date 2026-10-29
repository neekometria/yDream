vec3 CAS(vec2 texcoord) {
    vec3 e = texture2DLod(colortex1, texcoord, 0.0).rgb;

    vec3 left  = texture2DLod(colortex1, texcoord + vec2(-pixelSizeX, 0.0), 0.0).rgb;
    vec3 right = texture2DLod(colortex1, texcoord + vec2( pixelSizeX, 0.0), 0.0).rgb;
    vec3 down  = texture2DLod(colortex1, texcoord + vec2(0.0, -pixelSizeY), 0.0).rgb;
    vec3 up    = texture2DLod(colortex1, texcoord + vec2(0.0,  pixelSizeY), 0.0).rgb;
    vec3 ul    = texture2DLod(colortex1, texcoord + vec2(-pixelSizeX,  pixelSizeY), 0.0).rgb;
    vec3 ur    = texture2DLod(colortex1, texcoord + vec2( pixelSizeX,  pixelSizeY), 0.0).rgb;
    vec3 dl    = texture2DLod(colortex1, texcoord + vec2(-pixelSizeX, -pixelSizeY), 0.0).rgb;
    vec3 dr    = texture2DLod(colortex1, texcoord + vec2( pixelSizeX, -pixelSizeY), 0.0).rgb;

    vec3 mnRGB  = min(min(min(left,e),min(right,up)),down);
    vec3 mnRGB2 = min(min(min(mnRGB,ul),min(dl,ur)),dr);
    mnRGB += mnRGB2;

    vec3 mxRGB  = max(max(max(left,e),max(right,up)),down);
    vec3 mxRGB2 = max(max(max(mxRGB,ul),max(dl,ur)),dr);
    mxRGB += mxRGB2;

    vec3 rcpMxRGB = vec3(1.0) / mxRGB;
    vec3 ampRGB = clamp(min(mnRGB, 2.0 - mxRGB) * rcpMxRGB, 0.0, 1.0);

    ampRGB = inversesqrt(ampRGB);
    float peak = 8.0 - 3.0 * SHARPENING;
    vec3 wRGB = -vec3(1.0) / (ampRGB * peak);
    vec3 rcpWeightRGB = vec3(1.0) / (1.0 + 4.0 * wRGB);

    vec3 window = (up + down) + (left + right);
    vec3 outColor = clamp((window * wRGB + e) * rcpWeightRGB, 0.0, 1.0);

    return outColor;
}
