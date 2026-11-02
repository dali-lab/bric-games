shader_type canvas_item;

// Sweeps a noise threshold across the puddle so it eats its way in and out
// instead of fading uniformly. dissolve_progress 0 is gone, 1 is whole.
uniform float dissolve_progress : hint_range(0.0, 1.0) = 1.0;
uniform float noise_scale = 0.09;
// Randomised per puddle so no two break up the same way.
uniform vec2 noise_offset = vec2(0.0);
uniform float edge_width : hint_range(0.01, 0.6) = 0.18;
uniform vec4 edge_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float edge_strength : hint_range(0.0, 1.0) = 0.7;

varying vec2 local_position;

float hash12(vec2 point) {
    vec3 scattered = fract(vec3(point.xyx) * 0.1031);
    scattered += dot(scattered, scattered.yzx + 33.33);
    return fract((scattered.x + scattered.y) * scattered.z);
}

float value_noise(vec2 point) {
    vec2 cell = floor(point);
    vec2 within_cell = fract(point);
    vec2 weight = within_cell * within_cell * (3.0 - 2.0 * within_cell);
    return mix(
        mix(hash12(cell), hash12(cell + vec2(1.0, 0.0)), weight.x),
        mix(hash12(cell + vec2(0.0, 1.0)), hash12(cell + vec2(1.0, 1.0)), weight.x),
        weight.y);
}

float fractal_noise(vec2 point) {
    float total = 0.0;
    float amplitude = 0.5;
    float normalization = 0.0;
    for (int octave = 0; octave < 3; octave++) {
        total += amplitude * value_noise(point);
        normalization += amplitude;
        point *= 2.0;
        amplitude *= 0.5;
    }
    return total / normalization;
}

void vertex() {
    // Polygon2D only generates UVs when it carries a texture, so the pattern
    // is anchored to the node's own local coordinates instead.
    local_position = VERTEX;
}

void fragment() {
    float pattern = fractal_noise(local_position * noise_scale + noise_offset);
    // The sweep runs past both ends so progress 1 leaves no holes and
    // progress 0 clears every last pixel.
    float threshold = mix(1.0 + edge_width, -edge_width, dissolve_progress);
    float reveal = smoothstep(threshold, threshold + edge_width, pattern);
    // Brighten the rim that is still spreading or drying back.
    float rim = reveal * (1.0 - reveal) * 4.0;
    COLOR.rgb = mix(COLOR.rgb, edge_color.rgb, rim * edge_strength * edge_color.a);
    COLOR.a *= reveal;
}
