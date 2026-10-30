float cloudShape(float v) {
    #ifdef CLOUD_ROUNDED
        return sqrt(max(v, 0.0));
    #else
        return v;
    #endif
}

float cloudField(vec2 posXZ) {
    float fieldValue = texture2D(gaux2, (posXZ * CLOUD_NOISE_SCALE) + (frameTimeCounter * CLOUD_HI_FACTOR)).r;

    fieldValue += texture2D(gaux2, (posXZ.yx * CLOUD_NOISE_SCALE) + (frameTimeCounter * CLOUD_LOW_FACTOR)).r;
    fieldValue = smoothstep(0.05, 0.95, fieldValue * 0.5);

    return fieldValue;
}

vec3 get_cirrus(vec3 eyeDirection, vec3 blockColor, float bright, vec3 litColor, vec3 shadeColor) {
    if (eyeDirection.y > 0.02) {
        vec2 plane = eyeDirection.xz / (eyeDirection.y + 0.16);
        vec2 drift = vec2(frameTimeCounter * 0.0011, frameTimeCounter * 0.0005);
        float bend = sin(plane.y * 1.3 + frameTimeCounter * 0.02) * 0.25 + sin(plane.y * 0.37 - frameTimeCounter * 0.012) * 0.45;
        plane.x += bend;

        float streak = texture2D(gaux2, plane * vec2(0.09, 0.46) + drift).r;
        float streakB = texture2D(gaux2, plane * vec2(0.17, 0.80) + drift * 1.4 + vec2(0.37, 0.52)).r;
        float fibers = texture2D(gaux2, plane * vec2(0.85, 4.2) + drift * 2.3 + vec2(0.71, 0.19)).r;
        float fine = texture2D(gaux2, plane * vec2(2.4, 9.5) + drift * 3.6 + vec2(3.3, 6.7)).r;

        float coverage = smoothstep(0.28, 0.80, streak * 0.6 + streakB * 0.4);
        float body = smoothstep(0.40, 0.90, streak * 0.45 + streakB * 0.25 + fibers * 0.22 + fine * 0.08);
        float filaments = smoothstep(0.34, 0.80, fibers) * smoothstep(0.26, 0.70, streak);
        float grain = smoothstep(0.50, 0.92, fine) * filaments;
        float wisps = clamp(body * 0.60 + filaments * 0.28 + grain * 0.14, 0.0, 1.0) * coverage;
        wisps *= smoothstep(0.02, 0.30, eyeDirection.y) * (1.0 - rainStrength);

        float horizonGlow = 1.0 - clamp(eyeDirection.y * 1.5, 0.0, 1.0);
        float twilight = 1.0 - smoothstep(0.04, 0.40, abs(sunElevation));
        float silver = pow(clamp(bright, 0.0, 1.0), 0.6);

        vec3 wispLit = litColor * mix(vec3(1.0), vec3(1.14, 0.90, 0.72), twilight * 0.7);
        vec3 wispShade = mix(shadeColor, shadeColor * vec3(0.95, 0.88, 0.96), twilight);
        vec3 wispColor = mix(wispShade, wispLit, 0.74 + 0.16 * filaments);
        wispColor += wispLit * (silver * 0.55 * (0.4 + 0.6 * filaments) + horizonGlow * 0.20 + twilight * horizonGlow * 0.22);

        float thin = 0.62 + 0.14 * coverage;
        return mix(blockColor, wispColor * CLOUD_BRIGHTNESS, wisps * thin);
    }

    return blockColor;
}

vec3 get_cloud(vec3 eyeDirection, vec3 blockColor, float bright, float dither, vec3 base_pos, int samples, float umbral, vec3 cloudColor, vec3 darkCloudColor, vec3 lightDir, float maxDist) {
    #if VOL_LIGHT == 0
        if (maxDist > 1e8) blockColor.rgb *= clamp(bright + ((dither - .5) * .1), 0.0, 1.0) * .3 + 1.0;
    #endif

    #if defined DISTANT_HORIZONS && defined DEFERRED_SHADER
        float d_dh = texture2D(dhDepthTex0, gl_FragCoord.xy / vec2(viewWidth, viewHeight)).r;
        float linear_d_dh = ld_dh(d_dh);
        if (linear_d_dh < 0.9999) {
            return blockColor;
        }
    #endif

    umbral = clamp(umbral / CLOUD_DENSITY, 0.0, 0.99);

    // Fade toward the horizon only when the camera is below the layer; from above or inside, keep the clouds visible.
    float horizonFade = (base_pos.y < CLOUD_PLANE) ? clamp((eyeDirection.y - 0.06) * 5.0, 0.0, 1.0) : 1.0;

    if (abs(eyeDirection.y) > 0.001) {
        float view_y_inv = 1.0 / max(abs(eyeDirection.y), 0.001);

        float plane_distance_inf = (CLOUD_PLANE - base_pos.y) / eyeDirection.y;
        float plane_distance_sup = (CLOUD_PLANE_SUP - base_pos.y) / eyeDirection.y;
        float plane_distance_start = max(min(plane_distance_inf, plane_distance_sup), 0.0);
        float plane_distance_end = max(plane_distance_inf, plane_distance_sup);

        // Clouds only exist in front of the visible surface (terrain or sky).
        plane_distance_start = min(plane_distance_start, maxDist);
        plane_distance_end = min(plane_distance_end, maxDist);

        // Only march the part of the cloud layer in front of the camera.
        if (plane_distance_end <= plane_distance_start + 0.001) {
            return blockColor;
        }

        vec3 intersection_pos = (eyeDirection * plane_distance_start) + base_pos;
        vec3 intersection_pos_sup = (eyeDirection * plane_distance_end) + base_pos;

        float dif_sup = CLOUD_PLANE_SUP - CLOUD_PLANE_CENTER;
        float dif_inf = CLOUD_PLANE_CENTER - CLOUD_PLANE;

        vec3 increment = (intersection_pos_sup - intersection_pos) / samples;

        float increment_dist = length(increment);

        float dist_aux_coeff = (CLOUD_PLANE_SUP - CLOUD_PLANE) * 0.075;
        float dist_aux_coeff_blur = dist_aux_coeff * 0.3;
        float opacity_dist = dist_aux_coeff * 2.0 * view_y_inv;

        float cloud_value = 0.0;
        float density = 0.0;
        bool first_contact = true;
        vec3 firstPos = intersection_pos;
        float firstValue = 0.0;

        intersection_pos += (increment * dither);

        for (int i = 0; i < samples; i++) {
            float current_value = texture2D(gaux2, (intersection_pos.xz * CLOUD_NOISE_SCALE) + (frameTimeCounter * CLOUD_HI_FACTOR)).r;

            current_value += texture2D(gaux2, (intersection_pos.zx * CLOUD_NOISE_SCALE) + (frameTimeCounter * CLOUD_LOW_FACTOR)).r;
            float detailNoise = texture2D(gaux2, (intersection_pos.xz * 0.0016) - (frameTimeCounter * CLOUD_HI_FACTOR * 1.6)).r;
            current_value = smoothstep(0.05, 0.95, current_value * 0.5) * 0.82 + detailNoise * 0.18;

            #ifdef CLOUD_LIGHT_ENHANCED
                float erosionNoise = texture2D(gaux2, (intersection_pos.xz * 0.0049) + vec2(frameTimeCounter * CLOUD_HI_FACTOR * 2.2, 0.37)).r;
                current_value += (erosionNoise - 0.5) * 0.20 * (1.0 - current_value);
            #else
                float erosionNoise = texture2D(gaux2, (intersection_pos.xz * 0.0049) + vec2(frameTimeCounter * CLOUD_HI_FACTOR * 2.2, 0.37)).r;
                current_value += (erosionNoise - 0.5) * 0.12 * (1.0 - current_value);
            #endif

            current_value = (current_value - umbral) / (1.0 - umbral);

            float shapedValue = cloudShape(current_value);
            float surface_inf = CLOUD_PLANE_CENTER - (shapedValue * dif_inf * CLOUD_INF_SCALE);
            float surface_sup = CLOUD_PLANE_CENTER + (shapedValue * dif_sup * CLOUD_SUP_SCALE);

            float current_opacity = 0.0;
            float cloud_thickness = surface_sup - surface_inf;

            if (intersection_pos.y > surface_inf && intersection_pos.y < surface_sup) {

                current_opacity = min(increment_dist, cloud_thickness);
            }
            else if (cloud_thickness > 0.0 && i > 0) {

                float distance_aux = min(abs(intersection_pos.y - surface_inf), abs(intersection_pos.y - surface_sup));
                if (distance_aux < dist_aux_coeff_blur) {
                    float blur_factor = 1.0 - (distance_aux / dist_aux_coeff_blur);
                    current_opacity = min(blur_factor * increment_dist, cloud_thickness);
                }
            }

            if (current_opacity > 0.0) {
                cloud_value += current_opacity;
                if (first_contact) {
                    first_contact = false;
                    firstPos = intersection_pos;
                    firstValue = current_value;
                    density = (surface_sup - intersection_pos.y) / (CLOUD_PLANE_SUP - CLOUD_PLANE);
                }
                if (cloud_value >= opacity_dist) {
                    break;
                }
            }

            intersection_pos += increment;
        }

        // Camera inside the layer: the path is short, so boost the density to make it feel like being inside a cloud.
        float interiorBoost = (base_pos.y > CLOUD_PLANE && base_pos.y < CLOUD_PLANE_SUP) ? CLOUD_INTERIOR_DENSITY : 1.0;
        cloud_value = clamp(cloud_value / opacity_dist * interiorBoost, 0.0, 1.0);
        density = clamp(density, 0.0001, 1.0);

        float sunSide = clamp(bright, 0.0, 1.0);
        float cloud_value_approx = sqrt(sqrt(cloud_value));

        float shadowAmount = 0.0;
        #if defined CLOUD_SELF_SHADOW && !defined CLOUD_LIGHT_ENHANCED
        if (cloud_value > 0.02) {
            vec2 lightHorizontal = lightDir.xz;
            float horizontalLength = max(length(lightHorizontal), 0.001);
            vec2 lightStep = lightHorizontal / horizontalLength;
            float rise = lightDir.y / max(horizontalLength, 0.15);

            float farDistance = 90.0;

            float farValue = (cloudField(firstPos.xz + lightStep * farDistance) - umbral) / (1.0 - umbral);

            float farTop = CLOUD_PLANE_CENTER + cloudShape(farValue) * dif_sup * CLOUD_SUP_SCALE;

            float farBlock = smoothstep(0.0, 28.0, farTop - (firstPos.y + farDistance * rise)) * step(0.0, farValue);
            shadowAmount = farBlock;
        }
        #endif

        #ifdef CLOUD_LIGHT_ENHANCED
            float lightOptical = 0.0;
            vec3 lightPos = firstPos;
            float lightReach = 0.0;

            for (int j = 0; j < 4; j++) {
                if (cloud_value < 0.02) {
                    break;
                }

                float stepLength = 10.0 + float(j) * 9.0;
                lightPos += lightDir * stepLength;
                lightReach += stepLength;

                float lightField = (cloudField(lightPos.xz) - umbral) / (1.0 - umbral);
                float lightShape = cloudShape(lightField);
                float lightTop = CLOUD_PLANE_CENTER + lightShape * dif_sup * CLOUD_SUP_SCALE;
                float lightBottom = CLOUD_PLANE_CENTER - lightShape * dif_inf * CLOUD_INF_SCALE;

                float inside = smoothstep(lightBottom - 3.0, lightBottom + 6.0, lightPos.y) *
                    (1.0 - smoothstep(lightTop - 6.0, lightTop + 3.0, lightPos.y)) * step(0.0, lightField);

                lightOptical += inside * stepLength;
            }

            float lightTrans = exp(-lightOptical * 0.040 * CLOUD_SHADOW_STRENGTH);
            float multiScatter = mix(pow(lightTrans, 0.85), pow(lightTrans, 0.30), 0.42);

            float sunForward = pow(clamp(dot(eyeDirection, lightDir) * 0.5 + 0.5, 0.0, 1.0), 10.0);
            float phaseBoost = 1.0 + 0.50 * sunForward * STYLE_CLOUD_CONTRAST * (1.0 - rainStrength);

            float heightLift = (1.0 - sqrt(density)) * 0.16;
            float baseLight = clamp((multiScatter * 0.90 + heightLift) * phaseBoost, 0.0, 1.0);

            float thickFactor = smoothstep(0.05, 0.80, clamp(firstValue, 0.0, 1.0));
            float lightAmount = max(pow(mix(1.0, baseLight, thickFactor * 0.95), 1.0 + 0.28 * STYLE_CLOUD_CONTRAST), 0.08);
        #else
            float topLit = 1.0 - clamp(sqrt(density) * CLOUD_SHADOW_STRENGTH, 0.0, 1.0);
            float directLit = 1.0 - shadowAmount;
            float baseLight = clamp(topLit * (0.30 + 0.70 * directLit) + directLit * (0.16 * STYLE_CLOUD_CONTRAST), 0.0, 1.0);

            float thickFactor = smoothstep(0.05, 0.80, clamp(firstValue, 0.0, 1.0));
            float lightContrast = 1.0 + 0.30 * STYLE_CLOUD_CONTRAST;
            float lightAmount = max(pow(mix(1.0, baseLight, thickFactor * 0.90), lightContrast), 0.10);
        #endif

        vec3 undersideColor = darkCloudColor * 1.10 + cloudColor * (0.08 + 0.10 * (1.0 - eyeDirection.y));
        vec3 shadedCloud = mix(undersideColor, cloudColor, lightAmount);

        float thinEdge = 1.0 - cloud_value_approx;
        float rimGlow = thinEdge * thinEdge * sunSide * (1.0 - rainStrength);
        cloudColor = (shadedCloud + cloudColor * (rimGlow * (1.8 + 1.6 * sunSide) * STYLE_CLOUD_GLOW_MULT)) * CLOUD_BRIGHTNESS;
        float silverLining = thinEdge * thinEdge * thinEdge * sunSide * (1.0 - rainStrength);
        cloudColor += cloudColor * (silverLining * 1.1 * STYLE_CLOUD_GLOW_MULT + sunSide * 0.10 * lightAmount);

        float horizonBleed = (1.0 - smoothstep(0.03, 0.32, eyeDirection.y)) * 0.55 * (base_pos.y < CLOUD_PLANE ? 1.0 : 0.0);
        cloudColor = mix(cloudColor, blockColor * 1.15 + cloudColor * 0.15, horizonBleed);

        float nightCloudSheer = 1.0 - 0.34 * (1.0 - smoothstep(-0.18, 0.02, sunElevation)) * (1.0 - cloud_value) * (1.0 - rainStrength);
        blockColor = mix(blockColor, cloudColor, cloud_value * nightCloudSheer * horizonFade);
    }

    return blockColor;
}
