// SPDX-FileCopyrightText: The Threadbare Authors
// SPDX-License-Identifier: MPL-2.0
// Full-screen gloom for Hub 1: drains colour from the whole view, darkens the
// edges, and lays a faint grey wash on top. Put it on a ColorRect that covers
// the screen, in a CanvasLayer below the HUD.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 0 = full colour, 1 = black and white.
uniform float desaturation : hint_range(0.0, 1.0) = 0.3;
// Colour of the dark edges.
uniform vec4 vignette_color : source_color = vec4(0.02, 0.03, 0.06, 1.0);
// How dark the edges get.
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
// Distance from the centre (0.5 = edge of screen) where darkening starts.
uniform float vignette_radius : hint_range(0.0, 1.0) = 0.38;
// How gradually the edges darken.
uniform float vignette_softness : hint_range(0.01, 1.0) = 0.45;
// A flat colour laid over everything, for a washed-out look.
uniform vec4 wash_color : source_color = vec4(0.55, 0.58, 0.64, 1.0);
uniform float wash_amount : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;

	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(grey), desaturation);

	col = mix(col, wash_color.rgb, wash_amount);

	// Correct for the screen's aspect so the vignette is round, not stretched.
	vec2 from_center = SCREEN_UV - 0.5;
	from_center.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float dist = length(from_center);
	float edge = smoothstep(vignette_radius, vignette_radius + vignette_softness, dist);
	col = mix(col, vignette_color.rgb, edge * vignette_strength);

	COLOR = vec4(col, 1.0);
}
