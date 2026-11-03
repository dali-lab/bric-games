# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Area2D

const DISSOLVE_PROGRESS_PARAM := &"dissolve_progress"
const NOISE_OFFSET_PARAM := &"noise_offset"

@export_range(0.5, 10.0, 0.5) var lifetime: float = 4.0
# How long the liquid takes to eat its way out across the ground, and to dry
# back off it again. The puddle is only solid in between.
@export_range(0.05, 3.0, 0.05) var appear_time: float = 0.4
@export_range(0.05, 3.0, 0.05) var disappear_time: float = 0.8

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

var dissolve_material: ShaderMaterial


func _ready() -> void:
	_make_shape()
	dissolve_material = material as ShaderMaterial
	if dissolve_material:
		# Start hidden, and break up differently from every other puddle.
		dissolve_material.set_shader_parameter(DISSOLVE_PROGRESS_PARAM, 0.0)
		dissolve_material.set_shader_parameter(
			NOISE_OFFSET_PARAM, Vector2(randf() * 100.0, randf() * 100.0)
		)
	# Nothing to step in until the puddle has finished forming.
	collision_polygon.disabled = true

	var life: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	life.tween_method(_set_dissolve, 0.0, 1.0, appear_time)
	life.tween_callback(_on_formed)
	life.tween_interval(lifetime)
	life.tween_callback(_on_drying_up)
	life.tween_method(_set_dissolve, 1.0, 0.0, disappear_time)
	life.tween_callback(queue_free)


func _set_dissolve(progress: float) -> void:
	if dissolve_material:
		dissolve_material.set_shader_parameter(DISSOLVE_PROGRESS_PARAM, progress)


func _on_formed() -> void:
	collision_polygon.set_deferred("disabled", false)


func _on_drying_up() -> void:
	# A puddle that is breaking up no longer catches the player.
	collision_polygon.set_deferred("disabled", true)
	for child: Node in get_children():
		if child is CPUParticles2D:
			(child as CPUParticles2D).emitting = false


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
	collision_polygon.polygon = outline
