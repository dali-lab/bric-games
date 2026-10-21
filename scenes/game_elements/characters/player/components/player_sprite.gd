# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends AnimatedSprite2D

@onready var player: Player = owner
@onready var eye_sprite: AnimatedSprite2D = %EyeSprite
@onready var blink_timer: Timer = %BlinkTimer


func _ready() -> void:
	blink_timer.timeout.connect(_blink)
	_blink()


func _blink():
	eye_sprite.show()
	await get_tree().create_timer(randf_range(0.2, 0.3)).timeout
	eye_sprite.hide()
	blink_timer.start(randfn(3.5,  2.5))


func _process(_delta: float) -> void:
	if not player:
		return
	if player.velocity.is_zero_approx():
		return
	if not is_zero_approx(player.velocity.x):
		flip_h = player.velocity.x > 0
		eye_sprite.flip_h = player.velocity.x > 0


func look_at_side(side: Enums.LookAtSide) -> void:
	if side == 0:
		return
	flip_h = side > 0
	eye_sprite.flip_h = side > 0
