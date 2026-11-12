float cloudShape(float v) {
    #ifdef CLOUD_ROUNDED
    return sqrt(max(v, 0.0));
    #else
    return v;
    #endif
}

#include "/lib/cloud_noise.glsl"

float cloudField(vec2 posXZ) {
    return cloud_field(posXZ);
}

vec3 get_cloud(vec3 eyeDirection, vec3 blockColor, float bright, float dither, vec3 base_pos, int samples, float umbral, vec3 cloudColor, vec3 darkCloudColor, vec3 lightDir, float maxDist, float atmosphereFade, out float cloudCoverage) {
    cloudCoverage = 0.0;

    #if VOL_LIGHT == 0
    if (maxDist > 1e8) blockColor.rgb *= clamp(bright + ((dither - .5) * .1), 0.0, 1.0) * .3 + 1.0;
    #endif

    umbral = clamp(umbral / CLOUD_DENSITY, 0.0, 0.99);

    float belowLayer = 1.0 - smoothstep(CLOUD_PLANE - 20.0, CLOUD_PLANE + 5.0, base_pos.y);
    float horizonFade = mix(1.0, clamp((eyeDirection.y - 0.06) * 5.0, 0.0, 1.0), belowLayer);
    if (maxDist > 1e8) {
        horizonFade = 1.0;
    }
    
    float dif_sup = CLOUD_PLANE_SUP - CLOUD_PLANE_CENTER;
    float dif_inf = CLOUD_PLANE_CENTER - CLOUD_PLANE;

    float layerEdgeFade = 10.0;
    float insideLayer = smoothstep(CLOUD_PLANE - layerEdgeFade, CLOUD_PLANE + layerEdgeFade, base_pos.y) *
        (1.0 - smoothstep(CLOUD_PLANE_SUP - layerEdgeFade, CLOUD_PLANE_SUP + layerEdgeFade, base_pos.y));

    float cameraField = clamp((cloud_field(base_pos.xz) - umbral) / max(1.0 - umbral, 0.001), 0.0, 1.0);
    float cameraShape = clamp(cloudShape(cameraField), 0.0, 1.0);
    float cameraSurfaceInf = CLOUD_PLANE_CENTER - cameraShape * dif_inf * CLOUD_INF_SCALE;
    float cameraSurfaceSup = CLOUD_PLANE_CENTER + cameraShape * dif_sup * CLOUD_SUP_SCALE;

    #if CLOUD_TOWERS == 1
    // Consistencia: se a camera estiver perto/na torre, o shape da camera
    // acompanha a coluna (a bigorna nao afeta o interior da camera).
    vec2 camTower = cloud_tower_field(base_pos.xz);
    if (camTower.y > 0.001) {
        cameraSurfaceSup = max(cameraSurfaceSup, CLOUD_PLANE_CENTER + dif_sup * CLOUD_SUP_SCALE * (1.0 + camTower.y * 2.4));
        cameraSurfaceInf = min(cameraSurfaceInf, CLOUD_PLANE_CENTER - dif_inf * CLOUD_INF_SCALE * (1.0 + camTower.y * 0.6));
    }
    #endif
    float insideCloud = smoothstep(cameraSurfaceInf - 20.0, cameraSurfaceInf + 20.0, base_pos.y) *
        (1.0 - smoothstep(cameraSurfaceSup - 20.0, cameraSurfaceSup + 20.0, base_pos.y));

    // Em um buraco entre nuvens cameraShape == 0 e as duas superficies colapsam
    // em CLOUD_PLANE_CENTER. Sem este gate o smoothstep vira um degrau de 40
    // blocos e interiorAmount = 1 pinta a tela inteira de nuvem ao cruzar a
    // altitude do plano, mesmo sem nenhuma nuvem ali.
    insideCloud *= smoothstep(4.0, 40.0, cameraSurfaceSup - cameraSurfaceInf);

    float interiorAmount = insideLayer * insideCloud;

    float safeY = max(abs(eyeDirection.y), 0.001);
    float dirYSign = eyeDirection.y < 0.0 ? -1.0 : 1.0;
    
    float view_y_inv = 1.0 / safeY;
    view_y_inv = min(view_y_inv, 6.0);
    float plane_distance_inf = (CLOUD_PLANE - base_pos.y) / (dirYSign * safeY);
    float plane_distance_sup = (CLOUD_PLANE_SUP - base_pos.y) / (dirYSign * safeY);
    
    float plane_distance_start = max(min(plane_distance_inf, plane_distance_sup), 0.0);
    float plane_distance_end = max(plane_distance_inf, plane_distance_sup);

    plane_distance_start = min(plane_distance_start, maxDist);
    plane_distance_end = min(plane_distance_end, maxDist);

    float maxRayDist = (CLOUD_PLANE_SUP - CLOUD_PLANE) * 4.0;
    plane_distance_end = min(plane_distance_end, plane_distance_start + maxRayDist);

    // CORREÇÃO PARA O REFLEXO: Se for a água (maxDist infinito), não aplicar fade de distância nem de horizonte.
    if (maxDist > 1e8) {
        horizonFade = 1.0;
    }
    float distToCloud = plane_distance_start;
    float distanceFade = 1.0 - smoothstep(10000.0, 15000.0, distToCloud);
    if (maxDist > 1e8) {
        distanceFade = 1.0;
    }

    if (plane_distance_end > plane_distance_start + 0.001) {
        
        vec3 intersection_pos = (eyeDirection * plane_distance_start) + base_pos;
        vec3 intersection_pos_sup = (eyeDirection * plane_distance_end) + base_pos;

        vec3 increment = (intersection_pos_sup - intersection_pos) / samples;

        float increment_dist = length(increment);

        float dist_aux_coeff = (CLOUD_PLANE_SUP - CLOUD_PLANE) * 0.075;
        float dist_aux_coeff_blur = dist_aux_coeff * 0.3;

        float opacity_y_factor = mix(view_y_inv, 1.0, interiorAmount);
        float opacity_dist = dist_aux_coeff * 2.0 * opacity_y_factor;

        float cloud_value = 0.0;
        float density = 0.0;
        bool first_contact = true;
        vec3 firstPos = intersection_pos;
        float firstValue = 0.0;

        intersection_pos += (increment * dither);

        for (int i = 0; i < samples; i++) {
            float detailNoise = texture2D(YDREAM_CLOUD_NOISE_TEX, (intersection_pos.xz * 0.0016) - (frameTimeCounter * CLOUD_HI_FACTOR * 1.6)).r;
            float current_value = mix(cloud_field(intersection_pos.xz), detailNoise, CLOUD_DETAIL_WEIGHT);

            #ifdef CLOUD_LIGHT_ENHANCED
            float erosionNoise = texture2D(YDREAM_CLOUD_NOISE_TEX, (intersection_pos.xz * 0.0049) + vec2(frameTimeCounter * CLOUD_HI_FACTOR * 2.2, 0.37)).r;
            current_value += (erosionNoise - 0.5) * 0.20 * (1.0 - current_value);
            #else
            float erosionNoise = texture2D(YDREAM_CLOUD_NOISE_TEX, (intersection_pos.xz * 0.0049) + vec2(frameTimeCounter * CLOUD_HI_FACTOR * 2.2, 0.37)).r;
            current_value += (erosionNoise - 0.5) * 0.12 * (1.0 - current_value);
            #endif

            current_value = (current_value - umbral) / (1.0 - umbral);

            float shapedValue = cloudShape(current_value);
            float surface_inf = CLOUD_PLANE_CENTER - (shapedValue * dif_inf * CLOUD_INF_SCALE);
            float surface_sup = CLOUD_PLANE_CENTER + (shapedValue * dif_sup * CLOUD_SUP_SCALE);

            #if CLOUD_TOWERS == 1
            // Torre de tempestade rara: coluna central muito mais alta e funda
            // (o cogumelo) + bigorna, um anel largo e fino no topo.
            vec2 towerF = cloud_tower_field(intersection_pos.xz);
            if (towerF.x > 0.001) {
                float towerTop = CLOUD_PLANE_CENTER + dif_sup * CLOUD_SUP_SCALE * (1.0 + towerF.y * 2.4);
                float towerBot = CLOUD_PLANE_CENTER - dif_inf * CLOUD_INF_SCALE * (1.0 + towerF.y * 0.6);
                float anvilTop = CLOUD_PLANE_CENTER + dif_sup * CLOUD_SUP_SCALE * (0.75 + 0.55 * towerF.x);
                float anvilInf = anvilTop - 48.0;
                surface_sup = max(surface_sup, mix(anvilTop, towerTop, towerF.y));
                surface_inf = mix(min(surface_inf, anvilInf), towerBot, towerF.y);
            }
            #endif

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

        float rainDensity = mix(1.0, RAIN_CLOUD_DENSITY, rainStrength); 
        // O boost de densidade interna so vale quando o primeiro contato do raio
        // e profundo (camera de verdade dentro do material). Nuvens vistas como
        // forma (contato raso, de cima) mantêm cloud_value < 1, preservando o
        // thinEdge (bordas iluminadas) perto da camera.
        float boostWeight = smoothstep(0.35, 0.75, density);
        float interiorBoost = mix(1.0, CLOUD_INTERIOR_DENSITY, interiorAmount * 0.5 * boostWeight) * rainDensity;
        cloud_value = clamp(cloud_value / opacity_dist * interiorBoost, 0.0, 1.0);

        density = mix(density, 0.5, interiorAmount * 0.6);
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
            if (cloud_value < 0.02) break;

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

        float lightTrans = exp(-lightOptical * 0.120 * CLOUD_SHADOW_STRENGTH);
        float multiScatter = mix(pow(lightTrans, 0.85), pow(lightTrans, 0.30), 0.42);

        float sunForward = pow(clamp(dot(eyeDirection, lightDir) * 0.5 + 0.5, 0.0, 1.0), 10.0);
        
        float phaseBoost = 1.0 + 0.50 * sunForward * STYLE_CLOUD_CONTRAST * (1.0 - getAltitudeRain());

        float heightLift = (1.0 - sqrt(density)) * 0.16;
        float baseLight = clamp((multiScatter * 0.90 + heightLift) * phaseBoost, 0.0, 1.0);
        float thickFactor = smoothstep(0.05, 0.80, clamp(firstValue, 0.0, 1.0));
        thickFactor = mix(thickFactor, 0.85, interiorAmount * 0.7);
        float lightAmount = max(pow(mix(1.0, baseLight, thickFactor * 0.95), 1.0 + 0.28 * STYLE_CLOUD_CONTRAST), 0.08);
        #else
        float topLit = 1.0 - clamp(sqrt(density) * CLOUD_SHADOW_STRENGTH, 0.0, 1.0);
        float directLit = 1.0 - shadowAmount;
        float baseLight = clamp(topLit * (0.30 + 0.70 * directLit) + directLit * (0.16 * STYLE_CLOUD_CONTRAST), 0.0, 1.0);

        float thickFactor = smoothstep(0.05, 0.80, clamp(firstValue, 0.0, 1.0));
        thickFactor = mix(thickFactor, 0.85, interiorAmount * 0.7);
        float lightContrast = 1.0 + 0.30 * STYLE_CLOUD_CONTRAST;
        float lightAmount = max(pow(mix(1.0, baseLight, thickFactor * 0.90), lightContrast), 0.10);
        #endif
        
        float topViewBoost = smoothstep(0.0, -0.8, eyeDirection.y) * mix(0.4, 0.8, rainStrength);
        topViewBoost *= (1.0 - smoothstep(0.1, 0.5, interiorAmount));
        // Nuvens grossas de perto ja saem com o topo 100% iluminado (density ~ 0
        // no primeiro contato de cima); o boost gratuito sobre elas era o que
        // estourava o brilho. Aplica so em material fino/distante.
        topViewBoost *= 1.0 - clamp(cloud_value, 0.0, 1.0) * 0.8;
        lightAmount = clamp(lightAmount + topViewBoost, 0.0, 1.0);
        lightAmount *= mix(1.0, 0.75, interiorAmount);

        // Gradiente direcional do sol: pista de volume para nuvens vistas de
        // cima. A densidade no primeiro contato nao diferencia o lado voltado
        // ao sol do lado oposto (tudo fica 100% iluminado); este termo escurece
        // a metade anti-solar de acordo com o alinhamento horizontal entre
        // visao e sol. So atua em material denso (bordas finas ficam).
        float viewSunCos = 0.5;
        {
            vec2 viewH = eyeDirection.xz;
            vec2 sunH = lightDir.xz;
            float viewHLen = length(viewH);
            float sunHLen = length(sunH);
            if (viewHLen > 0.05 && sunHLen > 0.001) {
                viewSunCos = clamp(dot(viewH / viewHLen, sunH / sunHLen) * 0.5 + 0.5, 0.0, 1.0);
            }
        }
        float downView = smoothstep(-0.10, -0.70, eyeDirection.y);
        float volumeGradient = mix(1.0, mix(0.45, 1.0, viewSunCos),
            downView * (1.0 - smoothstep(0.1, 0.5, interiorAmount)) * clamp(cloud_value, 0.0, 1.0));
        lightAmount *= volumeGradient;

        vec3 undersideColor = darkCloudColor * mix(1.0, 0.5, rainStrength) + cloudColor * (0.08 + 0.10 * (1.0 - eyeDirection.y));
        vec3 shadedCloud = mix(undersideColor, cloudColor, lightAmount);

        float thinEdge = 1.0 - cloud_value_approx;
        float rimGlow = thinEdge * thinEdge * sunSide * (1.0 - getAltitudeRain());

        float edgeBoostMask = 1.0 - smoothstep(0.4, 0.9, interiorAmount);

        // O boost de 1.4x valia para qualquer nuvem vista de cima; nuvens
        // grossas de perto ficavam estouradas. Fino/distante mantém 1.4,
        // material denso de perto cai para ~1.05.
        float topBoost = mix(1.0, mix(1.4, 1.05, clamp(cloud_value, 0.0, 1.0)), smoothstep(-0.1, -0.8, eyeDirection.y));
        
        cloudColor = (shadedCloud + cloudColor * (rimGlow * (1.8 + 1.6 * sunSide) * STYLE_CLOUD_GLOW_MULT * edgeBoostMask)) * CLOUD_BRIGHTNESS * topBoost;
        
        float silverLining = thinEdge * thinEdge * thinEdge * sunSide * (1.0 - getAltitudeRain());
        
        cloudColor += cloudColor * (silverLining * 1.1 * STYLE_CLOUD_GLOW_MULT * edgeBoostMask
                                  + sunSide * 0.10 * lightAmount * edgeBoostMask);

        cloudColor = min(cloudColor, vec3(1.8));

        float horizonBleed = (1.0 - smoothstep(0.03, 0.32, eyeDirection.y)) * 0.55 * belowLayer;
        cloudColor = mix(cloudColor, blockColor * 1.15 + cloudColor * 0.15, horizonBleed);

        float nightCloudSheer = 1.0 - 0.34 * (1.0 - smoothstep(-0.18, 0.02, sunElevation)) * (1.0 - cloud_value) * (1.0 - getAltitudeRain());
        
        cloudCoverage = clamp(cloud_value * nightCloudSheer * horizonFade, 0.0, 1.0);
        
        cloudCoverage *= distanceFade;
        cloudColor *= atmosphereFade;
        
        float cameraInCloud = smoothstep(0.1, 0.4, interiorAmount);
        cloudCoverage = mix(cloudCoverage, 1.0, cameraInCloud);

        blockColor = mix(blockColor, cloudColor, cloudCoverage);
    } else {
        if (interiorAmount > 0.01) {
            float coverage = smoothstep(0.05, 0.35, interiorAmount);
            cloudCoverage = coverage;
            blockColor = mix(blockColor, cloudColor * CLOUD_BRIGHTNESS, coverage);
        }
    }

    return blockColor;
}