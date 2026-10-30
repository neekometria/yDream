#include "/lib/config.glsl"

#if defined THE_END
    #include "/lib/color_utils_end.glsl"
#elif defined NETHER
    #include "/lib/color_utils_nether.glsl"
#else
    #include "/lib/color_utils.glsl"
#endif

uniform mat4 gbufferProjectionInverse;
uniform float rainStrength;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform float dayNightMix;

#if MC_VERSION < 12106 || defined UNKNOWN_DIM
    varying vec2 texcoord;
#endif

#ifdef UNKNOWN_DIM
    varying vec4 tintColor;
#endif

varying vec3 cloudFinalColor;
varying float meshAlpha;
varying float cloudFacing;
varying vec3 cloudWorldXZY;
varying vec3 cloudFaceNormalV;
varying float cloudUpFacingV;

#if AA_TYPE > 0
    #include "/src/taa_offset.glsl"
#endif

#include "/lib/luma.glsl"

void main() {
    #if MC_VERSION < 12106 || defined UNKNOWN_DIM
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    #endif

    #ifdef UNKNOWN_DIM
        tintColor = gl_Color;
    #endif

    meshAlpha = gl_Color.a < 0.05 ? 0.8 : gl_Color.a;

    #include "/src/position_vertex.glsl"

    // Vanilla cloud vertices are emitted relative to the camera around Y=192.
    // Keep the clouds fixed in world space at the per-dimension cloud height.
    vec4 cloudRelativePosition = gbufferModelViewInverse * viewPosition;
    cloudRelativePosition.y += CLOUD_PLANE_CENTER - 192.0;
    gl_Position = gl_ModelViewProjectionMatrix * cloudRelativePosition;

    cloudFinalColor = vec3(1.0);
    cloudFacing = 1.0;
    cloudWorldXZY = vec3(0.0);
    cloudFaceNormalV = vec3(0.0, 1.0, 0.0);
    cloudUpFacingV = 1.0;

    #if V_CLOUDS == 0 && !defined UNKNOWN_DIM && !defined THE_END && !defined NETHER
        vec3 cloudColor;
        vec3 darkCloudColor;

        #include "/src/cloud_palette.glsl"

        cloudColor = mix(vec3(luma(cloudColor)), cloudColor, 0.72) * 1.20;
        darkCloudColor = mix(vec3(luma(darkCloudColor)), darkCloudColor, 0.30);
        darkCloudColor = max(darkCloudColor, cloudColor * 0.68);

        vec3 viewNormal = gl_NormalMatrix * gl_Normal;
        float normalLength = dot(viewNormal, viewNormal);
        vec3 skyUp = normalize(gbufferModelView[1].xyz);
        vec3 faceNormal = normalLength > 0.0001 ? viewNormal * inversesqrt(normalLength) : skyUp;

        cloudFacing = abs(dot(faceNormal, normalize(viewPosition.xyz)));
        float upFacing = dot(faceNormal, skyUp);

        vec3 cloudWorldPos = cloudRelativePosition.xyz + cameraPosition;
        cloudWorldXZY = vec3(cloudWorldPos.xz, cloudWorldPos.y);
        cloudFaceNormalV = faceNormal;
        cloudUpFacingV = upFacing;

        vec3 sunDirection = normalize(sunPosition);
        float sunFacing = mix(-dot(faceNormal, sunDirection), dot(faceNormal, sunDirection), dayNightMix);

        float cloudWorldY = cloudRelativePosition.y + cameraPosition.y;
        float heightGradient = clamp((cloudWorldY - VANILLA_CLOUD_BASE_Y) * 0.22, 0.0, 1.0);

        float topAmount = smoothstep(-0.85, 0.85, upFacing);
        float baseLight = mix(0.42, 1.0, topAmount) * mix(0.88, 1.0, heightGradient);
        float sunBoost = clamp(sunFacing, 0.0, 1.0) * 0.55 * (1.0 - cloudRain * 0.8);

        float cloudLightAmount = clamp(mix(1.0, baseLight + sunBoost, VANILLA_CLOUD_SHADING), 0.0, 1.0);
        cloudColor = mix(cloudColor, cloudSunLight * 1.15, clamp(sunFacing, 0.0, 1.0) * 0.45 * (1.0 - cloudRain));

        cloudFinalColor = mix(darkCloudColor, cloudColor, cloudLightAmount) * CLOUD_BRIGHTNESS;
    #endif
}
