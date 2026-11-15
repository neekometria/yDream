// ============================================================================
// Unified water medium model: coefficients, Beer-Lambert transmittance, and
// column attenuation helpers. No depth-buffer or projection dependencies.
// Requires: cameraPosition and config macros (WATER_ABSORPTION,
// UNDERWATER_FOG_DENSITY, UNDERWATER_DARKNESS, WATER_DEPTH_TINT, etc.).
// ============================================================================
#ifndef YDREAM_WATER_MEDIUM_INCLUDED
#define YDREAM_WATER_MEDIUM_INCLUDED

// --- Medium coefficients --------------------------------------------------

// Selective Beer-Lambert absorption of the water body itself (1/block).
vec3 ydr_water_absorption_coeff() {
    return vec3(5.60, 1.45, 1.00) * max(WATER_ABSORPTION, 0.001);
}

// Backward-compatible alias.
vec3 ydr_water_absorption() {
    return ydr_water_absorption_coeff();
}

// Per-channel extinction for view paths through water (1/block).
vec3 ydr_water_column_extinction() {
    return vec3(0.070, 0.038, 0.022) *
        ((UNDERWATER_FOG_DENSITY * 0.5 + WATER_ABSORPTION * 4.0) * 0.55);
}

// Scalar extinction companion for fog-amount style attenuation.
float ydr_water_column_extinction_scalar() {
    return (0.035 + 0.014 * UNDERWATER_FOG_DENSITY) * max(UNDERWATER_DARKNESS, 0.5);
}

// --- Transmittance / attenuation ------------------------------------------

vec3 ydr_water_transmittance(vec3 sigma, float distanceBlocks) {
    return exp(-sigma * max(distanceBlocks, 0.0));
}

vec3 ydr_water_body_transmittance(float thicknessBlocks) {
    return ydr_water_transmittance(ydr_water_absorption_coeff(), thicknessBlocks);
}

vec3 ydr_water_column_transmittance(float distanceBlocks) {
    return ydr_water_transmittance(ydr_water_column_extinction(), distanceBlocks);
}

// The view ray may leave the water when looking upward. Distances passed to
// this helper are geometric (ray) distances, not depth-buffer Z distances.
float ydr_water_submerged_path(float rayDistance, vec3 rayDirection,
    float cameraPosY, float surfaceY) {
    float path = max(rayDistance, 0.0);
    if (rayDirection.y > 0.0001 && cameraPosY < surfaceY) {
        float surfaceDistance = (surfaceY - cameraPosY) / rayDirection.y;
        path = min(path, max(surfaceDistance, 0.0));
    }
    return path;
}

// Convert linear view-space depth (positive -Z) into distance along its ray.
float ydr_water_view_to_ray_distance(float viewDepth, vec3 viewRay) {
    return max(viewDepth, 0.0) / max(-normalize(viewRay).z, 0.0001);
}

vec3 ydr_water_effective_transmittance(float distanceBlocks) {
    float d = max(distanceBlocks, 0.0);
    vec3 transmittance = ydr_water_column_transmittance(d);
    transmittance = mix(vec3(1.0), transmittance, smoothstep(1.0, 6.0, d));
    // Fecha a coluna de vez: na agua nao existe visibilidade util alem de ~2x a
    // extincao. O residuo de 1e-4 (o azul escapa primeiro) era o que deixava o
    // LOD do DH, a superficie e o ceu distantes legiveis como silhueta clara.
    // Vale para TODO consumidor (DH, terreno, agua e ceu), entao nao ha costura.
    return transmittance * (1.0 - smoothstep(28.0, 64.0, d));
}

float ydr_water_column_fog_amount(float distanceBlocks) {
    return 1.0 - exp(-max(distanceBlocks, 0.0) * ydr_water_column_extinction_scalar());
}

// Vertical depth of the camera below nominal sea level (blocks, clamped).
float ydr_water_vertical_depth(float cameraPosY) {
    return max(62.0 - cameraPosY, 0.0);
}

float ydr_water_depth_darkening(float verticalDepth) {
    return exp(-verticalDepth * 0.025 * UNDERWATER_DARKNESS);
}

float ydr_water_column_darkening(float waterPath) {
    return exp(-waterPath * 0.035 * UNDERWATER_DARKNESS);
}

// Radiância de espalhamento da coluna d'água. NÃO depende do comprimento do
// raio: num meio uniforme a radiância espalhada é constante e só a transmitância
// varia com a distância. O antigo fator de distância (piso 0.30) fazia a
// geometria longe (LOD do DH, terra no horizonte) convergir para um tom ~3x
// mais escuro que o céu no mesmo pixel — era a "placa" visível do DH.
// Profundidade da câmera continua escurecendo (abismo preservado).
vec3 ydr_water_column_fog_radiance(vec3 lightColor, float skyBrightness,
    float cameraPosY) {
    return ydr_water_underwater_fog_radiance(lightColor, skyBrightness, cameraPosY) *
        ydr_water_depth_darkening(ydr_water_vertical_depth(cameraPosY));
}

vec3 ydr_water_apply_column_fog(vec3 sceneColor, vec3 lightColor,
    float skyBrightness, float cameraPosY, float distanceBlocks) {
    vec3 transmittance = ydr_water_effective_transmittance(distanceBlocks);
    vec3 fogRadiance = ydr_water_column_fog_radiance(
        lightColor, skyBrightness, cameraPosY
    );
    return sceneColor * transmittance + fogRadiance * (vec3(1.0) - transmittance);
}

// --- Depth / thickness helpers (math only) --------------------------------

float ydr_water_surface_distance(vec3 fragposView) {
    return max(-fragposView.z, 0.05);
}

// Profundidade a partir da qual a superficie d'agua esconde o leito, olhando
// de FORA. Usada no fade da névoa e no teto de espessura: se só a cor da névoa
// satura, a espessura continua variando e a absorção/espalhamento do corpo
// desenha o contorno do chão.
const float YDR_WATER_SURFACE_HIDE_DEPTH = 5.0;

float ydr_water_surface_thickness(float bedViewDist, float surfaceViewDist) {
    const float noBed = 1e8;
    if (bedViewDist >= noBed) return YDR_WATER_SURFACE_HIDE_DEPTH;
    return clamp(bedViewDist - surfaceViewDist, 0.0, YDR_WATER_SURFACE_HIDE_DEPTH);
}

#endif
