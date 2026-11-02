// Cloud shadows for the real chunks. The shared field lives in
// /lib/cloud_shadow.glsl, which is included at global scope by
// solid_blocks_vertex.glsl so both the chunks and the LOD terrain use exactly
// the same pattern.
vec3 csWorld = (gbufferModelViewInverse * viewPosition).xyz + cameraPosition;
vec3 csLight = normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz) * mix(-1.0, 1.0, step(0.5, dayNightMix));

directLightStrength *= 1.0 - cloud_shadow_amount(csWorld, csLight);
