#if VOL_LIGHT == 2

    #define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

    vec3 get_volumetric_pos(vec3 shadowPos) {
        shadowPos = mat3(shadowModelView) * shadowPos + shadowModelView[3].xyz;
        shadowPos = diagonal3(shadowProjection) * shadowPos + shadowProjection[3].xyz;
        float distb = length(shadowPos.xy);
        float distortion = distb * SHADOW_DIST + (1.0 - SHADOW_DIST);

        shadowPos.xy /= distortion;
        shadowPos.z *= 0.2;

        return shadowPos * 0.5 + 0.5;
    }

    vec3 get_volumetric_scatter(float dither, float visibleDistance, mat4 modeli_times_projectioni) {
        vec3 light = vec3(0.0);
        float counted = 0.0;

        for (int i = 0; i < GODRAY_STEPS; i++) {
            float currentDistance = exp2(float(i) + dither) - 0.6;
            if (currentDistance > visibleDistance) {
                break;
            }

            float ndcDepth = (far * (currentDistance - near)) / (currentDistance * (far - near));
            vec4 pos = modeli_times_projectioni * (vec4(texcoord, ndcDepth, 1.0) * 2.0 - 1.0);
            vec3 shadowPos = get_volumetric_pos(pos.xyz / pos.w);

            float opaqueLit = shadow2D(shadowtex1, shadowPos).r;
            vec3 sampleColor = vec3(opaqueLit);

            #if defined COLORED_GODRAYS || defined SCREENSHOT_MODE
                float allLit = shadow2D(shadowtex0, shadowPos).r;
                if (allLit < opaqueLit - 0.004) {
                    vec4 glass = texture2D(shadowcolor0, shadowPos.xy);
                    sampleColor = mix(vec3(1.0), glass.rgb, clamp(glass.a * 1.4, 0.0, 1.0)) * opaqueLit;
                }
            #endif

            light += sampleColor;
            counted += 1.0;
        }

        return light / max(counted, 1.0);
    }

#elif VOL_LIGHT == 1

    float ssGodrays(float dither) {
        float light = 0.0;
        float comp = 1.0 - (near / (far * far));

        vec2 ray_step = vec2(lightpos - texcoord) * 0.2;
        vec2 dither2d = texcoord + (ray_step * dither);

        float depth;

        for (int i = 0; i < CHEAP_GODRAY_SAMPLES; i++) {
            depth = texture2D(depthtex1, dither2d).x;
            dither2d += ray_step;
            light += step(comp, depth);
        }

        return light / CHEAP_GODRAY_SAMPLES;
  }

#endif
