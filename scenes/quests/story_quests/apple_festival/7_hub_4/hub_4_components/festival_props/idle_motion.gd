# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node

@export var sprite: Node2D
@export var sway_degrees: float = 0.0
@export var breathing: float = 0.008
@export var speed: float = 1.6

var elapsed: float = randf() * TAU

@onready var resting_position: Vector2 = sprite.position
@onready var resting_scale: Vector2 = sprite.scale
@onready var resting_rotation: float = sprite.rotation


func _process(delta: float) -> void:
	elapsed += delta * speed
	var wave: float = sin(elapsed)
	var stretch: float = 1.0 + wave * breathing
	var sway: float = deg_to_rad(sway_degrees) * wave

	# Move just the picture around its feet; leave collisions and prompts still.
	sprite.scale = resting_scale * Vector2(1.0, stretch)
	sprite.rotation = resting_rotation + sway
	sprite.position = (resting_position * Vector2(1.0, stretch)).rotated(sway)
