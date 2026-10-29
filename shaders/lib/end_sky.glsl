// End sky: one self-contained atmosphere with a molten core.
// There are no stars, clouds, nebula or aurora in the End. The vanilla End
// sky quads are discarded in gbuffers_skybasic/skytextured, so this is the
// only thing drawn in the sky.

vec3 endSkyGradient(vec3 worldDir) {
    float up = clamp(worldDir.y, -1.0, 1.0);

    // Horizon colour at the bottom of the dome, sky colour straight up.
    float climb = pow(clamp(up, 0.0, 1.0), 0.65);
    vec3 sky = mix(END_SKY_HORIZON, END_SKY_ZENITH, climb);

    // Glow that hugs the horizon.
    float horizonGlow = exp(-abs(up) * 7.5);
    sky += END_SKY_GLOW * (horizonGlow * 0.10 * END_HORIZON_GLOW);

    // The void below the horizon is darker.
    float below = smoothstep(0.0, -0.35, up);
    sky = mix(sky, sky * 0.35, below);

    return sky * END_SKY_DEPTH;
}

vec3 endCoreLayer(vec3 worldDir, float pixelAngle, float time) {
    vec3 coreDir = normalize(END_CORE_DIR);
    float facing = dot(worldDir, coreDir);
    if (facing <= 0.0) {
        return vec3(0.0);
    }

    // Gnomonic projection onto the core's tangent plane. uv has length 1.0 at the limb.
    vec3 reference = abs(coreDir.y) > 0.94 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(reference, coreDir));
    vec3 up = normalize(cross(coreDir, right));
    vec2 plane = vec2(dot(worldDir, right), dot(worldDir, up)) / facing;
    vec2 uv = plane / max(tan(END_CORE_SIZE), 1.0e-4);
    float r = length(uv);

    float aa = clamp(pixelAngle / max(END_CORE_SIZE, 1.0e-4) * 1.5, 0.0025, 0.35);
    float disc = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r);
    float corona = exp(-max(r - 1.0, 0.0) * 4.2) * (1.0 - disc);

    // Sphere normal across the disc, so the core reads as a ball, not a sticker.
    float z = sqrt(max(1.0 - r * r, 0.0));
    vec3 n = vec3(uv, z);
    float limb = mix(0.20, 1.0, pow(clamp(z, 0.0, 1.0), 0.42));

    // Slow convection cells on the surface.
    vec3 flow = n * 3.2 + vec3(0.0, time * 0.006, time * 0.004);
    float cells = fbm3(flow);
    float fine = fbm3(n * 8.0 - flow * 0.35 + 11.3);
    float heat = clamp(cells * 0.85 + fine * 0.35 + 0.05, 0.0, 1.0);

    vec3 surface = mix(END_CORE_DEEP, END_CORE_MID, smoothstep(0.20, 0.60, heat));
    surface = mix(surface, END_CORE_HOT, smoothstep(0.62, 0.95, heat));
    // Purple lines wrapping the core, bent by slow noise so they read as flow lines.
    float linePhase = (n.y + (fbm3(n * 2.2 + vec3(time * 0.004)) - 0.5) * 0.25) * END_CORE_LINE_COUNT * 3.14159265;
    float coreLines = pow(max(1.0 - abs(sin(linePhase)), 0.0), 10.0);
    surface = mix(surface, END_CORE_LINE_COLOR, clamp(coreLines * END_CORE_LINE_STRENGTH * 0.85, 0.0, 1.0));
    surface = mix(surface, END_CORE_RIM, pow(1.0 - clamp(z, 0.0, 1.0), 5.0) * 0.55);

    // Clamp the lit surface so the disc stays readable and does not blow out bloom or exposure.
    vec3 lit = min(surface * limb * END_CORE_INTENSITY, vec3(END_CORE_RADIANCE_CAP));
    vec3 halo = END_CORE_RIM * (corona * 0.22 * END_CORE_INTENSITY);
    return lit * disc + halo;
}
