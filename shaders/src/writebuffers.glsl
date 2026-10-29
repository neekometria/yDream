#ifdef WATER_F
    blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
    #if GLEAM_VOXEL_LIGHT > 0
        float glassPeak = max(max(glassAlbedo.r, glassAlbedo.g), glassAlbedo.b);
        float glassSaturation = (glassPeak - min(min(glassAlbedo.r, glassAlbedo.g), glassAlbedo.b)) / max(glassPeak, 0.001);
        float glassMask = step(1.5, blockType) * (1.0 - step(2.5, blockType)) * smoothstep(0.16, 0.34, glassSaturation) * smoothstep(0.50, 0.80, lmcoord.x);
        /* RENDERTARGETS: 1,11 */
        gl_FragData[0] = blockColor;
        gl_FragData[1] = vec4(glassAlbedo / max(glassPeak, 0.001), step(0.5, glassMask));
    #else
        /* DRAWBUFFERS:1 */
        gl_FragData[0] = blockColor;
    #endif
#elif (defined SPECIAL_TRANS && MC_VERSION >= 11300) || defined GBUFFER_HAND_WATER
    /* DRAWBUFFERS:1 */
    gl_FragData[0] = blockColor;
#else
    #if defined SET_FOG_COLOR
        blockColor = clamp(blockColor, vec3(0.0), vec3(50.0));
        /* DRAWBUFFERS:17 */
        gl_FragData[0] = vec4(blockColor, 1.0);
        gl_FragData[1] = vec4(blockColor, 1.0);
    #elif MC_VERSION < 11604 && defined GBUFFER_SKYBASIC
        /* DRAWBUFFERS:17 */
        blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
        gl_FragData[0] = blockColor;
        gl_FragData[1] = blockColor;
    #else
        #if defined GBUFFER_ENTITIES && MC_VERSION >= 260000
            /* DRAWBUFFERS:14 */
            blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
            gl_FragData[0] = blockColor;
            gl_FragData[1] = blockColor;
        #elif defined GBUFFER_TERRAIN && defined GLEAM_LIGHT_BUFFERS
            /* RENDERTARGETS: 1,2,9 */
            blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
            gl_FragData[0] = blockColor;
            #if GLEAM_VOXEL_LIGHT > 0
                gl_FragData[1] = vec4(emitterTint * isEmissiveEntity, gleamCandleLuma);
            #else
                gl_FragData[1] = vec4(0.0, 0.0, 0.0, gleamCandleLuma);
            #endif
            gl_FragData[2] = vec4(gleamAlbedo, 1.0);
        #else
            /* DRAWBUFFERS:1 */
            blockColor = clamp(blockColor, vec4(0.0), vec4(vec3(50.0), 1.0));
            gl_FragData[0] = blockColor;
        #endif
    #endif
#endif
