# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

signal player_hit

@export_range(0.1, 5.0, 0.1) var warning_time: float = 1.0
@export_range(0.1, 5.0, 0.1) var fall_time: float = 0.6
@export var fall_height: float = 650.0
@export var landed_time: float = 0.4

@onready var apple_sprite: Sprite2D = $AppleSprite
@onready var shadow: Sprite2D = $AppleShadow
@onready var hit_area: Area2D = $HitArea


func _ready() -> void:
	# The root stays at the landing spot; only the apple sprite falls.
	# All sizes start at the same height above the ground.
	apple_sprite.position.y = -fall_height / scale.y
	apple_sprite.hide()
	shadow.scale = Vector2(0.8, 0.4)

	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# A growing ground shadow gives the player time to move away.
	tween.tween_property(shadow, "scale", Vector2(1.6, 0.8), warning_time)
	tween.tween_callback(apple_sprite.show)
	var fall: PropertyTweener = tween.tween_property(apple_sprite, "position:y", 0.0, fall_time)
	fall.set_trans(Tween.TRANS_QUAD)
	fall.set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_landed)
	tween.tween_interval(landed_time)
	tween.tween_callback(queue_free)


func _on_landed() -> void:
	# The warning shadow is harmless; check for a hit only at impact.
	for body: Node2D in hit_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			player_hit.emit()
			return
