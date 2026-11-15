// SPDX-FileCopyrightText: The Threadbare Authors
// SPDX-License-Identifier: MPL-2.0

// Makes a soft circle of a canopy polygon see-through, so the player can see
// the path and trees underneath while walking under the canopy.
shader_type canvas_item;

// Centre of the see-through circle, in the polygon's local coordinates.
uniform vec2 reveal_center;
// Radius of the fully see-through part of the circle, in pixels.
uniform float reveal_radius = 220.0;
// Width of the soft edge around the circle, in pixels.
uniform float reveal_softness = 140.0;
// 0 = canopy fully opaque, 1 = circle fully revealed. Tweened by the reveal zone.
uniform float reveal_strength : hint_range(0.0, 1.0) = 0.0;
// How opaque the canopy is at the centre of the circle when fully revealed.
uniform float revealed_alpha : hint_range(0.0, 1.0) = 0.35;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// In Godot 4, COLOR already includes the texture, so don't sample it again.
	vec4 color = COLOR;
	float distance_to_center = distance(local_position, reveal_center);
	float inside = 1.0 - smoothstep(reveal_radius, reveal_radius + reveal_softness, distance_to_center);
	color.a *= mix(1.0, revealed_alpha, inside * reveal_strength);
	COLOR = color;
}
