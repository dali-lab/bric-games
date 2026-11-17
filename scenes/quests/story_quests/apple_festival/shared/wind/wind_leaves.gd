# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

const LEAVES := preload("leaves.png")
# Each rectangle selects a single leaf from the drawing.
const LEAF_SHAPES: Array[Rect2] = [
	Rect2(326, 6, 104, 87),
	Rect2(37, 65, 154, 121),
	Rect2(360, 141, 145, 107),
	Rect2(201, 270, 154, 83),
]


func _ready() -> void:
	while is_inside_tree():
		for i in randi_range(2, 4):
			_blow_leaf()
			await get_tree().create_timer(randf_range(0.4, 0.9), false).timeout
		await get_tree().create_timer(randf_range(4.0, 6.0), false).timeout


func _blow_leaf() -> void:
	var leaf := Sprite2D.new()
	leaf.texture = LEAVES
	leaf.region_enabled = true
	leaf.region_rect = LEAF_SHAPES.pick_random()
	leaf.scale = Vector2.ONE * randf_range(0.12, 0.18)

	# Use the camera to place the leaf once, then let it travel through the world.
	var view := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
	var start := view.position + Vector2(-24.0, view.size.y * randf_range(0.08, 0.9))
	var distance := view.size.x + 48.0
	var phase := randf_range(0.0, TAU)
	add_child(leaf)
	var move_leaf := _move_leaf.bind(leaf, start, distance, phase)
	move_leaf.call(0.0)

	var gust := create_tween()
	gust.tween_method(move_leaf, 0.0, 1.0, randf_range(5.5, 7.5))
	gust.tween_callback(leaf.queue_free)


func _move_leaf(
	progress: float, leaf: Sprite2D, start: Vector2, distance: float, phase: float
) -> void:
	var sway := sin(phase + progress * TAU * 2.0)
	leaf.position = start + Vector2(distance * progress, 22.0 * sway + 32.0 * progress)
	leaf.rotation = phase + TAU * progress + 0.3 * sway
