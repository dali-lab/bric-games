# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Area2D

@export_range(0.5, 10.0, 0.5) var lifetime: float = 4.0


func _ready() -> void:
	_make_shape()
	$Lifetime.timeout.connect(queue_free)
	$Lifetime.start(lifetime)
	# Grow the liquid and its collision together from the landing point.
	var full_size: Vector2 = scale
	scale = full_size * 0.2
	var spread: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	spread.tween_property(self, "scale", full_size, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)


func _make_shape() -> void:
	var corners: PackedVector2Array = []
	var angle_offset: float = randf() * TAU
	for index: int in range(16):
		var angle: float = angle_offset + TAU * index / 16.0
		var radius: float = randf_range(0.65, 1.25)
		corners.append(Vector2(cos(angle) * 40.0, sin(angle) * 20.0) * radius)

	# Round each corner while keeping the outline different for every puddle.
	var outline: PackedVector2Array = []
	for index: int in range(corners.size()):
		var next_corner: Vector2 = corners[(index + 1) % corners.size()]
		outline.append(corners[index].lerp(next_corner, 0.25))
		outline.append(corners[index].lerp(next_corner, 0.75))
	$PuddleOutline.polygon = outline
	$PuddleFill.polygon = outline
	$CollisionPolygon2D.polygon = outline
