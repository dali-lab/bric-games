# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Area2D
## While the player is inside this area, a soft circle of [member canopy] around
## them turns see-through, so the path and trees under the canopy show.

## The canopy polygon to fade. Its material must use canopy_reveal.gdshader.
@export var canopy: Node2D
## How long the canopy takes to fade in or out, in seconds.
@export var fade_time: float = 0.4
## Offset from the player's feet to the centre of the see-through circle.
@export var reveal_offset: Vector2 = Vector2(0, -70)

var _player: Node2D
var _material: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	_material = canopy.material as ShaderMaterial
	_material.set_shader_parameter(&"reveal_strength", 0.0)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if _player:
		var center := canopy.to_local(_player.global_position + reveal_offset)
		_material.set_shader_parameter(&"reveal_center", center)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body
		_fade_to(1.0)


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_fade_to(0.0)


func _fade_to(strength: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_material, "shader_parameter/reveal_strength", strength, fade_time)
