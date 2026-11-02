# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

signal player_hit
signal apple_land
signal apple_fade

const BIG_FALL_SOUND = preload(
	"res://scenes/quests/story_quests/apple_festival/4_cider_press/cider_press_components/audio/big_apple_fall.wav"
)

# The shadow keeps one 2:1 ellipse shape throughout; only its size changes.
const SHADOW_START_SCALE := Vector2(0.8, 0.4)
const SHADOW_LANDED_SCALE := Vector2(1.6, 0.8)

@export_range(0.1, 5.0, 0.1) var warning_time: float = 1.0
@export_range(0.1, 5.0, 0.1) var fall_time: float = 0.6
@export var fall_height: float = 650.0
# How long the apple lies on the ground, solid and blocking the player, before
# it starts shrinking away.
@export_range(0.0, 10.0, 0.1) var landed_time: float = 1.2
# How far the apple sits into its shadow, as a fraction of the apple's own
# height. Being relative keeps the look identical at every apple size.
@export_range(0.0, 0.5, 0.01) var shadow_sink: float = 0.1

var leaves_poison: bool = false
var leaves_sticky_juice: bool = false
var is_big: bool = false
var has_landed: bool = false
var has_hit_player: bool = false
var animation: Tween
var wait_for_dodge: bool = false
var waiting_for_dodge: bool = false
var base_sprite_scale: Vector2 = Vector2.ONE

@onready var apple_sprite: Sprite2D = $AppleSprite
@onready var shadow: Sprite2D = $AppleShadow
@onready var hit_area: Area2D = $HitArea
@onready var fall_sound: AudioStreamPlayer = $FallSound
@onready var landing_sound: AudioStreamPlayer = $LandingSound
@onready var blocker: CollisionShape2D = $Blocker/CollisionShape2D


func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)
	# Put the opaque bottom at the sprite's origin so squash stays on the ground,
	# then push it down into the shadow. This overwrites the offset set in the
	# scene, so tune the resting height with shadow_sink rather than there.
	var apple_image: Image = apple_sprite.texture.get_image()
	var opaque_rect: Rect2i = apple_image.get_used_rect()
	apple_sprite.offset.y = (
		apple_image.get_height() / 2.0 - opaque_rect.end.y + opaque_rect.size.y * shadow_sink
	)
	if is_big:
		fall_sound.stream = BIG_FALL_SOUND
		fall_sound.volume_db = -12.0
		# Fit the rushing wind to the whole fall.
		fall_sound.pitch_scale = BIG_FALL_SOUND.get_length() / fall_time
		landing_sound.volume_db = -3.0
		landing_sound.pitch_scale = 0.6
	# Impact and fade-out scales are multiples of the scene's sprite scale, so
	# the apple keeps one size from spawn to despawn.
	base_sprite_scale = apple_sprite.scale
	# The root stays at the landing spot; only the apple sprite falls.
	# All sizes start at the same height above the ground.
	apple_sprite.position.y = -fall_height / scale.y
	apple_sprite.hide()
	shadow.scale = SHADOW_START_SCALE
	shadow.modulate.a = 0.55

	animation = create_tween()
	var tween: Tween = animation
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# Warning and fall share one step so the shadow can grow across both.
	var approach_time: float = warning_time + fall_time
	# One accelerating growth from spawn to touchdown: the shadow widens slowly
	# while the apple is still high and rushes out as it drops, reaching full
	# size on the frame the apple lands.
	var shadow_growth: PropertyTweener = tween.tween_property(
		shadow, "scale", SHADOW_LANDED_SCALE, approach_time
	)
	shadow_growth.set_trans(Tween.TRANS_QUAD)
	shadow_growth.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(shadow, "modulate:a", 1.0, approach_time)
	if wait_for_dodge:
		# Keep the practice apple hidden until the player leaves its shadow.
		tween.parallel().tween_callback(_wait_for_dodge).set_delay(warning_time)
	tween.parallel().tween_callback(_start_fall).set_delay(warning_time)
	var fall: PropertyTweener = tween.parallel().tween_property(
		apple_sprite, "position:y", 0.0, fall_time
	)
	fall.set_delay(warning_time)
	fall.set_trans(Tween.TRANS_QUAD)
	fall.set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_landed)
	# Squash on impact, then return to the normal shape.
	tween.tween_property(apple_sprite, "scale", base_sprite_scale * Vector2(1.2, 0.8), 0.08)
	tween.tween_property(apple_sprite, "scale", base_sprite_scale, 0.12)
	tween.tween_interval(landed_time)
	# Shrink the apple and fade it with its shadow before removing it.
	tween.tween_callback(_start_fade)
	tween.tween_property(apple_sprite, "scale", base_sprite_scale * 0.65, 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _start_fade() -> void:
	# Stop blocking as soon as the apple starts to go, so a player pressed
	# against it is never caught inside a shape that is about to vanish.
	blocker.set_deferred("disabled", true)
	# Whatever the apple leaves behind seeps out as the apple itself goes.
	apple_fade.emit()


func _start_fall() -> void:
	# The dodge callback runs first and pauses the tween, so the practice apple
	# stays hidden until resume_fall() releases it.
	if waiting_for_dodge:
		return
	apple_sprite.show()
	fall_sound.play()


func _wait_for_dodge() -> void:
	waiting_for_dodge = true
	animation.pause()


func resume_fall() -> void:
	waiting_for_dodge = false
	_start_fall()
	animation.play()


func _on_landed() -> void:
	has_landed = true
	fall_sound.stop()
	landing_sound.play()
	# A resting apple is a solid obstacle the player has to walk around.
	blocker.set_deferred("disabled", false)
	# The shadow already reached its landed size and opacity on the way down,
	# so contact leaves it alone rather than snapping it to another shape.
	apple_land.emit()
	# Only the impact hurts. Catch a player already standing here, then go inert
	# so walking into the resting apple is safe -- it just blocks the way.
	for body: Node2D in hit_area.get_overlapping_bodies():
		_on_body_entered(body)
	hit_area.body_entered.disconnect(_on_body_entered)
	hit_area.set_deferred("monitoring", false)


func _on_body_entered(body: Node2D) -> void:
	# The shadow is safe; the apple is only dangerous on the frame it lands.
	if has_hit_player or is_queued_for_deletion() or not has_landed:
		return
	if body.is_in_group("player"):
		# One apple costs the player once, however often they walk back into it.
		has_hit_player = true
		player_hit.emit()
