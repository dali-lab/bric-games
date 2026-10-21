# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name SquashStretch
extends Node2D

## Optional procedural squash and stretch for a character sprite.
##
## Deforms [member target]'s scale according to how fast [member character] is moving. It is meant
## as an extra layer on top of whatever the [AnimationPlayer] is already doing: every frame the
## component reads back the pose the animation wrote, multiplies its own deformation into it, and
## writes the result. Keyed scale tracks and this component therefore compose instead of fighting,
## and removing the component leaves the keyed animation untouched.
## [br][br]
## For that read-back to see the animated pose, this node must be processed after the
## [AnimationPlayer]. Keeping it below the [AnimationPlayer] in the scene tree is enough, but
## [member Node.process_priority] can also be raised to make it explicit.
## [br][br]
## [AnimatedSprite2D] draws its frames centered, so scaling on its own would make the character's
## feet slide up and down. [member pivot_height] is the distance in pixels from the sprite's origin
## down to the feet, and the component shifts [member target] vertically to keep that point planted.

## Node whose [member Node2D.scale] is deformed. Usually the character's [AnimatedSprite2D].
@export var target: Node2D:
	set = _set_target

## Character whose [member CharacterBody2D.velocity] drives the deformation. When unset, the
## component only reacts to [method pop].
@export var character: CharacterBody2D:
	set = _set_character

## When false, [member target] is left at the pose the animation wrote.
@export var enabled: bool = true

## Distance in pixels from [member target]'s origin down to the character's feet. This is half the
## sprite frame's height for a centered [AnimatedSprite2D] with no offset.
@export_range(0.0, 256.0, 0.5, "or_greater", "suffix:px") var pivot_height: float = 69.5

@export_group("Movement")
## Speed at which the movement-driven deformation reaches its full amount.
@export_range(10, 1000, 10, "or_greater", "suffix:m/s") var reference_speed: float = 300.0

## How much the sprite stretches at [member reference_speed]. Positive values make it taller and
## thinner while moving; negative values squash it instead.
@export_range(-0.5, 0.5, 0.01) var speed_stretch: float = 0.06

## Amplitude of a continuous bounce while moving. Leave at zero when the walk animation already
## has keyed scale tracks, otherwise the two bounces stack.
@export_range(0.0, 0.5, 0.01) var bob_amount: float = 0.0

## Bounces per second at [member reference_speed]. The bounce slows down with the character.
@export_range(0.1, 10.0, 0.1, "or_greater", "suffix:Hz") var bob_frequency: float = 2.0

## How quickly the deformation catches up with the character. Higher values are smoother and
## laggier; near zero snaps instantly.
@export_range(0.0, 1.0, 0.01, "suffix:s") var response_time: float = 0.08

@export_group("Pop")
## Default [param amount] used by [method pop].
@export_range(-1.0, 1.0, 0.01) var pop_strength: float = 0.25

## Default [param duration] used by [method pop].
@export_range(0.05, 3.0, 0.05, "or_greater", "suffix:s") var pop_duration: float = 0.5

## Deformation currently requested by [method pop]. Tweened back to zero.
var _pop_amount: float = 0.0
## Phase of the [member bob_amount] oscillation, advanced by the character's speed.
var _bob_phase: float = 0.0
## Deformation multiplier applied on top of the animated pose, smoothed over time.
var _deformation: Vector2 = Vector2.ONE
## Pose written by the animation this frame, before this component deformed it.
var _rest_scale: Vector2 = Vector2.ONE
var _rest_position: Vector2 = Vector2.ZERO
## Pose this component wrote last frame, used to tell our own writes apart from the animation's.
var _applied_scale: Vector2 = Vector2.ONE
var _applied_position: Vector2 = Vector2.ZERO
## Reference to the tween that settles [member _pop_amount] back to zero.
var _pop_tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint() or not target:
		return
	_rest_scale = target.scale
	_rest_position = target.position
	_applied_scale = _rest_scale
	_applied_position = _rest_position


func _set_target(new_target: Node2D) -> void:
	target = new_target
	update_configuration_warnings()


func _set_character(new_character: CharacterBody2D) -> void:
	character = new_character
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray
	if not target:
		warnings.append("Target must be set.")
	if not character:
		warnings.append("Character is not set, so only pop() will deform the target.")
	return warnings


## Punches the sprite with a one-shot deformation that settles back to neutral. A positive
## [param amount] stretches vertically and a negative one squashes. Useful for landings, hits, or
## picking something up. Calling it again restarts the effect.
func pop(amount: float = pop_strength, duration: float = pop_duration) -> void:
	if _pop_tween and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	(
		_pop_tween
		. tween_property(self, "_pop_amount", 0.0, duration)
		. from(amount)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(target):
		return

	_read_animated_pose()

	if not enabled:
		_deformation = Vector2.ONE
		_pop_amount = 0.0
		_write_pose()
		return

	var speed_ratio: float = 0.0
	if is_instance_valid(character) and reference_speed > 0.0:
		speed_ratio = clampf(character.velocity.length() / reference_speed, 0.0, 1.0)

	_bob_phase = fmod(_bob_phase + delta * bob_frequency * TAU * speed_ratio, TAU)

	# Positive stretches the sprite vertically, negative squashes it.
	var stretch: float = speed_stretch * speed_ratio
	stretch += bob_amount * sin(_bob_phase)
	stretch += _pop_amount

	# Thinner as it gets taller, so the character keeps roughly the same volume.
	var wanted := Vector2(1.0 / (1.0 + stretch), 1.0 + stretch)
	_deformation = _deformation.lerp(wanted, 1.0 - exp(-delta / maxf(response_time, 0.001)))

	_write_pose()


## Picks up the pose written by the [AnimationPlayer] this frame. Anything that does not match what
## this component wrote last frame must have come from the animation, so it becomes the new rest
## pose to deform from. This keeps the deformation from compounding frame after frame when no
## animation is keying these properties.
func _read_animated_pose() -> void:
	if not target.scale.is_equal_approx(_applied_scale):
		_rest_scale = target.scale
	if not target.position.is_equal_approx(_applied_position):
		_rest_position = target.position


func _write_pose() -> void:
	_applied_scale = _rest_scale * _deformation
	# Shift the sprite so that the point pivot_height below its origin stays where it was.
	var planted := pivot_height * _rest_scale.y * (1.0 - _deformation.y)
	_applied_position = _rest_position + Vector2(0.0, planted)
	target.scale = _applied_scale
	target.position = _applied_position
