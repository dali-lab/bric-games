# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

signal player_hit
signal apple_land

const BIG_FALL_SOUND = preload(
	"res://scenes/quests/story_quests/apple_festival/4_cider_press/cider_press_components/audio/big_apple_fall.wav"
)

@export_range(0.1, 5.0, 0.1) var warning_time: float = 1.0
@export_range(0.1, 5.0, 0.1) var fall_time: float = 0.6
@export var fall_height: float = 650.0
@export var landed_time: float = 0.4

var leaves_poison: bool = false
var leaves_sticky_juice: bool = false
var is_big: bool = false
var has_landed: bool = false
var animation: Tween
var wait_for_dodge: bool = false
var waiting_for_dodge: bool = false

@onready var apple_sprite: Sprite2D = $AppleSprite
@onready var shadow: Sprite2D = $AppleShadow
@onready var hit_area: Area2D = $HitArea
@onready var fall_sound: AudioStreamPlayer = $FallSound
@onready var landing_sound: AudioStreamPlayer = $LandingSound


func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)
	# Put the opaque bottom at the sprite's origin so squash stays on the ground.
	var apple_image: Image = apple_sprite.texture.get_image()
	apple_sprite.offset.y = apple_image.get_height() / 2.0 - apple_image.get_used_rect().end.y
	if is_big:
		fall_sound.stream = BIG_FALL_SOUND
		fall_sound.volume_db = -12.0
		# Fit the rushing wind to the whole fall.
		fall_sound.pitch_scale = BIG_FALL_SOUND.get_length() / fall_time
		landing_sound.volume_db = -3.0
		landing_sound.pitch_scale = 0.6
	# The root stays at the landing spot; only the apple sprite falls.
	# All sizes start at the same height above the ground.
	apple_sprite.position.y = -fall_height / scale.y
	apple_sprite.hide()
	shadow.scale = Vector2(0.8, 0.4)
	shadow.modulate.a = 0.55

	animation = create_tween()
	var tween: Tween = animation
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# A growing ground shadow gives the player time to move away.
	tween.tween_property(shadow, "scale", Vector2(1.6, 0.8), warning_time)
	tween.parallel().tween_property(shadow, "modulate:a", 0.85, warning_time)
	if wait_for_dodge:
		# Keep the practice apple hidden until the player leaves its shadow.
		tween.tween_callback(_wait_for_dodge)
	tween.tween_callback(_start_fall)
	var fall: PropertyTweener = tween.tween_property(apple_sprite, "position:y", 0.0, fall_time)
	fall.set_trans(Tween.TRANS_QUAD)
	fall.set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_landed)
	# Squash on impact, then return to the normal shape.
	tween.tween_property(apple_sprite, "scale", Vector2(1.2, 0.8), 0.08)
	tween.tween_property(apple_sprite, "scale", Vector2.ONE, 0.12)
	tween.tween_interval(landed_time)
	# Shrink the apple and fade it with its shadow before removing it.
	tween.tween_property(apple_sprite, "scale", Vector2(0.65, 0.65), 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _start_fall() -> void:
	apple_sprite.show()
	fall_sound.play()


func _wait_for_dodge() -> void:
	waiting_for_dodge = true
	animation.pause()


func _on_landed() -> void:
	has_landed = true
	fall_sound.stop()
	landing_sound.play()
	# A tighter, darker contact shadow makes the landed apple feel planted.
	shadow.scale = Vector2(1.45, 0.45)
	shadow.modulate.a = 1.0
	apple_land.emit()
	# Catch a player already standing here when the apple lands.
	for body: Node2D in hit_area.get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node2D) -> void:
	# The shadow is safe; landed apples stay dangerous until they disappear.
	if has_landed and not is_queued_for_deletion() and body.is_in_group("player"):
		player_hit.emit()
