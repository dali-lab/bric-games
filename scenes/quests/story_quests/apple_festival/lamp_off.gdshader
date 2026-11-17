// SPDX-FileCopyrightText: The Threadbare Authors
// SPDX-License-Identifier: MPL-2.0
// Turns the yellow glass of the lamp post sprites into dim grey so the lamps
// read as unpowered. Non-yellow pixels (the black post) are left untouched.
shader_type canvas_item;

// How bright the greyed-out glass is compared to its original brightness.
uniform float darken : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	float yellow = smoothstep(0.15, 0.35, min(col.r, col.g) - col.b);
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114)) * darken;
	COLOR = vec4(mix(col.rgb, vec3(lum), yellow), col.a);
}
