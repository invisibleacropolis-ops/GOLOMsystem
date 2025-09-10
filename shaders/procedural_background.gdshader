shader_type canvas_item;

uniform float time_scale = 0.1;
uniform float noise_scale = 5.0;
uniform vec4 color_a : source_color = vec4(0.1, 0.2, 0.3, 1.0);
uniform vec4 color_b : source_color = vec4(0.3, 0.5, 0.7, 1.0);

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float noise(vec2 uv) {
    vec2 ij = floor(uv);
    vec2 f = fract(uv);
    f = f * f * (3.0 - 2.0 * f); // Smoothstep

    float a = rand(ij);
    float b = rand(ij + vec2(1.0, 0.0));
    float c = rand(ij + vec2(0.0, 1.0));
    float d = rand(ij + vec2(1.0, 1.0));

    float x1 = mix(a, b, f.x);
    float x2 = mix(c, d, f.x);
    return mix(x1, x2, f.y);
}

void fragment() {
    vec2 uv = SCREEN_UV * noise_scale + TIME * time_scale;
    float n = noise(uv);
    COLOR = mix(color_a, color_b, n);
}
