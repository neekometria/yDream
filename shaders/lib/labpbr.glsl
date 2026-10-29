vec3 labMetalF0(float value, vec3 albedo) {
    float id = floor(value + 0.5) - 230.0;
    vec3 f0 = albedo;

    if (id > -0.5 && id < 7.5) {
        f0 = vec3(0.531, 0.512, 0.496);
        f0 = id > 0.5 ? vec3(0.944, 0.776, 0.373) : f0;
        f0 = id > 1.5 ? vec3(0.912, 0.914, 0.920) : f0;
        f0 = id > 2.5 ? vec3(0.556, 0.555, 0.555) : f0;
        f0 = id > 3.5 ? vec3(0.926, 0.721, 0.504) : f0;
        f0 = id > 4.5 ? vec3(0.632, 0.626, 0.641) : f0;
        f0 = id > 5.5 ? vec3(0.679, 0.642, 0.588) : f0;
        f0 = id > 6.5 ? vec3(0.962, 0.949, 0.922) : f0;
    }

    return f0;
}
