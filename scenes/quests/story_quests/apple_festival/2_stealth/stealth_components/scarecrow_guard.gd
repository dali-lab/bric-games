# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name ScarecrowGuard
extends Guard
## Scarecrow variant of [Guard] used in the Apple Festival stealth level.
##
## Inherits all patrol and player-detection behavior from [Guard], and adds
## wildly exaggerated, cartoonish procedural animation on top of the sprite:
## [br]- [b]Idle[/b]: swaying on its pole, breathing squash & stretch, bendy skew.
## [br]- [b]Walk[/b]: hops along like it only has one leg, squashing on every
## landing, stretching in the air, leaning and wobbling.
## [br]- [b]Attack[/b] (when the player is caught): crouching wind-up, a
## spinning lunge into the air, then a furious shaking frenzy.
## [br][br]
## A springy "jiggle" layer is kicked on landings and state changes so the
## scarecrow wobbles and overshoots like jelly.
## [br][br]
## Every motion is driven from this script (not the AnimationPlayer), so all
## the amounts below can be tweaked live in the Inspector.

## Biggest allowed squash (negative) and stretch (positive), so the sprite never
## flips inside out.
const MIN_SQUASH := -0.8
const MAX_SQUASH := 2.0
## Longest frame time used for the animation, so a lag spike can't make the
## jiggle spring explode.
const MAX_DELTA := 1.0 / 30.0

@export_category("Scarecrow Sounds")
## Played every time the scarecrow lands a hop while walking.
@export var hop_sound_stream: AudioStream
## Played sometimes at the end of each idle sway, like a creaky wooden pole.
@export var creak_sound_stream: AudioStream
## Chance (0 to 1) that [member creak_sound_stream] plays on each sway.
@export_range(0.0, 1.0, 0.05) var creak_chance: float = 0.35
## Played when the scarecrow first notices the player (starts detecting).
## [br][br]
## [b]Note:[/b] The base guard's [member Guard.alerted_sound_stream] also plays then.
@export var startled_sound_stream: AudioStream
## Played when the scarecrow crouches down, winding up its attack.
@export var windup_sound_stream: AudioStream
## Played when the scarecrow springs forward in its attack lunge.
@export var attack_sound_stream: AudioStream
## Played when the scarecrow lands after its attack lunge.
@export var attack_land_sound_stream: AudioStream
## Random pitch variation applied to every scarecrow sound, so repeated sounds
## (like hops) don't feel robotic. 0.15 means pitch between 0.85 and 1.15.
@export_range(0.0, 0.5, 0.01) var pitch_variation: float = 0.15

@export_category("Scarecrow Animation")
## Plays the procedural animation in the editor so you can tune it without
## running the game. The sprite is reset before the scene is saved.
@export var preview_animation_in_editor: bool = false:
	set(new_value):
		if new_value == preview_animation_in_editor:
			return
		if is_node_ready():
			if new_value:
				_capture_base_sprite_transform()
			else:
				_reset_sprite_transform()
		preview_animation_in_editor = new_value
## Moves the pivot (the point that stays planted) up or down from the bottom
## edge of the sprite, in pixels. Use it if the texture has empty space under
## the scarecrow's feet. Negative values move the pivot up.
@export var feet_offset: float = 0.0
## How wide the sprite gets when squashed. 0 keeps the width the same; 1 makes
## it widen as much as it shrinks in height.
@export_range(0.0, 1.5, 0.05) var squash_width_ratio: float = 0.7

@export_group("Idle")
## Sway cycles per second while standing still.
@export_range(0.05, 3.0, 0.05, "or_greater") var idle_sway_speed: float = 0.6
## How far the scarecrow sways side to side.
@export_range(0.0, 45.0, 0.5, "or_greater", "suffix:°") var idle_sway_degrees: float = 12.0
## Extra bendiness while swaying (the top lags behind the bottom).
@export_range(0.0, 45.0, 0.5, "or_greater", "suffix:°") var idle_bend_degrees: float = 10.0
## How much it squashes and stretches while "breathing".
@export_range(0.0, 1.0, 0.01) var idle_breathe_amount: float = 0.12

@export_group("Walk")
## Hops per second at [member walk_reference_speed].
@export_range(0.1, 10.0, 0.1, "or_greater") var hops_per_second: float = 2.2
## Movement speed at which [member hops_per_second] is used. Faster guards hop
## faster, slower guards hop slower.
@export_range(10.0, 1000.0, 5.0, "or_greater", "suffix:m/s") var walk_reference_speed: float = 200.0
## How high each hop goes, in pixels.
@export_range(0.0, 300.0, 1.0, "or_greater", "suffix:px") var hop_height: float = 55.0
## How tall and thin it stretches at the top of a hop.
@export_range(0.0, 1.5, 0.01) var hop_stretch_amount: float = 0.35
## How flat it squashes right when it lands or takes off.
@export_range(0.0, 0.9, 0.01) var hop_squash_amount: float = 0.4
## How much it leans forward in the direction it's going.
@export_range(0.0, 60.0, 0.5, "or_greater", "suffix:°") var walk_lean_degrees: float = 18.0
## How much it tips left/right on alternating hops.
@export_range(0.0, 60.0, 0.5, "or_greater", "suffix:°") var walk_wobble_degrees: float = 14.0

@export_group("Attack")
## How long the crouching wind-up lasts before the lunge.
@export_range(0.05, 2.0, 0.01, "suffix:s") var attack_windup_time: float = 0.3
## How flat it squashes down during the wind-up.
@export_range(0.0, 0.9, 0.01) var attack_windup_squash: float = 0.5
## How far it leans back during the wind-up.
@export_range(0.0, 60.0, 0.5, "suffix:°") var attack_windup_lean_degrees: float = 25.0
## How long the lunge (spin through the air) lasts.
@export_range(0.05, 2.0, 0.01, "suffix:s") var attack_lunge_time: float = 0.4
## How tall and thin it stretches during the lunge.
@export_range(0.0, 2.0, 0.01) var attack_lunge_stretch: float = 0.7
## How high it jumps during the lunge, in pixels.
@export_range(0.0, 500.0, 1.0, "or_greater", "suffix:px") var attack_lunge_height: float = 90.0
## How many full spins it does during the lunge. 0 for no spin.
@export_range(0.0, 5.0, 0.25) var attack_spin_turns: float = 1.0
## Shakes per second during the frenzy after the lunge.
@export_range(0.0, 30.0, 0.5) var attack_frenzy_speed: float = 9.0
## How far it rotates back and forth during the frenzy.
@export_range(0.0, 60.0, 0.5, "suffix:°") var attack_frenzy_degrees: float = 16.0
## How much it squashes and stretches during the frenzy.
@export_range(0.0, 1.0, 0.01) var attack_frenzy_squash: float = 0.25
## Random side-to-side jitter during the frenzy, in pixels.
@export_range(0.0, 50.0, 0.5, "suffix:px") var attack_frenzy_jitter: float = 6.0

@export_group("Jiggle")
## How stiff the jiggle spring is. Higher means faster, tighter wobbles.
@export_range(10.0, 2000.0, 10.0) var jiggle_stiffness: float = 320.0
## How quickly the jiggle calms down. Lower means it wobbles for longer.
@export_range(0.0, 50.0, 0.5) var jiggle_damping: float = 7.0
## Squash kick when landing a hop.
@export_range(0.0, 30.0, 0.5) var hop_land_jiggle: float = 5.0
## Squash kick when coming to a stop.
@export_range(0.0, 30.0, 0.5) var stop_jiggle: float = 6.0
## Stretch kick when the scarecrow notices the player.
@export_range(0.0, 30.0, 0.5) var startled_jiggle: float = 12.0

## Time accumulated for the idle sway, in cycles.
var _sway_phase: float = 0.0
## Hop progress while walking. The integer part counts hops, the fraction is the
## progress through the current hop.
var _hop_phase: float = 0.0
## Seconds since the attack started, or a negative number if not attacking.
var _attack_time: float = -1.0
var _was_moving: bool = false
var _last_sway_direction: float = 0.0
var _last_state: State = State.PATROLLING

# Jiggle springs: value and velocity.
var _jiggle_squash: float = 0.0
var _jiggle_squash_velocity: float = 0.0
var _jiggle_rotation: float = 0.0
var _jiggle_rotation_velocity: float = 0.0

# The sprite's position and scale as set up in the scene. Animation is applied
# on top of these.
var _base_sprite_position: Vector2
var _base_sprite_scale: Vector2

@onready var _hop_sound: AudioStreamPlayer2D = %HopSound
@onready var _creak_sound: AudioStreamPlayer2D = %CreakSound
@onready var _startled_sound: AudioStreamPlayer2D = %StartledSound
@onready var _windup_sound: AudioStreamPlayer2D = %WindupSound
@onready var _attack_sound: AudioStreamPlayer2D = %AttackSound
@onready var _attack_land_sound: AudioStreamPlayer2D = %AttackLandSound


## A snapshot of how the sprite should be deformed this frame.
class Pose:
	## Positive stretches tall and thin, negative squashes short and wide.
	var squash: float = 0.0
	## Rotation in radians around the pivot.
	var rotation: float = 0.0
	## Skew in radians: leans the top while the feet stay flat on the ground.
	var skew: float = 0.0
	## Pixels lifted off the ground.
	var lift: float = 0.0
	## Horizontal shake offset in pixels.
	var shake: float = 0.0
	## 0 pivots around the feet, 1 pivots around the sprite's center.
	var center_pivot: float = 0.0


func _ready() -> void:
	super()
	_capture_base_sprite_transform()
	_last_state = state


func _process(delta: float) -> void:
	super(delta)

	if Engine.is_editor_hint() and not preview_animation_in_editor:
		return

	delta = minf(delta, MAX_DELTA)

	if state != _last_state:
		_on_scarecrow_state_changed(state)
		_last_state = state

	var pose: Pose
	if state == State.ALERTED:
		pose = _attack_pose(delta)
	elif velocity.is_zero_approx():
		pose = _idle_pose(delta)
	else:
		pose = _walk_pose(delta)

	_update_jiggle(delta)
	pose.squash += _jiggle_squash
	pose.rotation += _jiggle_rotation
	_apply_pose(pose)


func _notification(what: int) -> void:
	# Guard's own _notification runs automatically too, no need to call super.
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			# Only undo the deformation if it was applied, so edits made to the
			# sprite in the editor are kept.
			if is_node_ready() and preview_animation_in_editor:
				_reset_sprite_transform()


func _on_scarecrow_state_changed(new_state: State) -> void:
	match new_state:
		State.DETECTING:
			# Jumps out of its straw!
			_kick_jiggle(startled_jiggle, _facing() * 4.0)
			_play_sound(_startled_sound, startled_sound_stream)
		State.ALERTED:
			_attack_time = 0.0
			_play_sound(_windup_sound, windup_sound_stream)
		_:
			_attack_time = -1.0


## -1 when the sprite is facing left, 1 when facing right.
func _facing() -> float:
	return -1.0 if animated_sprite_2d.flip_h else 1.0


func _idle_pose(delta: float) -> Pose:
	if _was_moving:
		# Skids to a stop and wobbles.
		_was_moving = false
		_kick_jiggle(-stop_jiggle, _facing() * 6.0)

	_sway_phase += delta * idle_sway_speed
	var sway := sin(TAU * _sway_phase)
	var breathe := sin(TAU * _sway_phase * 2.0)

	# Creak at each end of the sway, when it changes direction.
	var sway_direction := signf(cos(TAU * _sway_phase))
	if sway_direction != _last_sway_direction:
		if _last_sway_direction != 0.0 and randf() < creak_chance:
			_play_sound(_creak_sound, creak_sound_stream)
		_last_sway_direction = sway_direction

	var pose := Pose.new()
	pose.squash = breathe * idle_breathe_amount
	pose.rotation = sway * deg_to_rad(idle_sway_degrees)
	# The bend lags a quarter cycle behind the sway, like a floppy straw body.
	pose.skew = -cos(TAU * _sway_phase) * deg_to_rad(idle_bend_degrees)
	return pose


func _walk_pose(delta: float) -> Pose:
	if not _was_moving:
		_was_moving = true
		_hop_phase = 0.0

	var speed_factor := clampf(velocity.length() / walk_reference_speed, 0.5, 3.0)
	var previous_hop_phase := _hop_phase
	_hop_phase += delta * hops_per_second * speed_factor

	var hop_index := int(floor(_hop_phase))
	var side := 1.0 if hop_index % 2 == 0 else -1.0
	if hop_index > int(floor(previous_hop_phase)):
		# Landed a hop: SPLAT.
		_kick_jiggle(-hop_land_jiggle, side * 3.0)
		_play_sound(_hop_sound, hop_sound_stream)

	var progress := fposmod(_hop_phase, 1.0)
	# 0 on the ground, 1 at the top of the hop.
	var arc := sin(PI * progress)

	var pose := Pose.new()
	pose.lift = arc * hop_height
	# Squashed flat near the ground, stretched tall in the air.
	pose.squash = hop_stretch_amount * arc - hop_squash_amount * pow(1.0 - arc, 3.0)
	# Lean into the direction of travel, leaning more in the air.
	pose.skew = _facing() * deg_to_rad(walk_lean_degrees) * (0.5 + 0.5 * arc)
	# Tip to alternating sides on each hop.
	pose.rotation = side * deg_to_rad(walk_wobble_degrees) * arc
	return pose


func _attack_pose(delta: float) -> Pose:
	if _attack_time < 0.0:
		_attack_time = 0.0
	var previous_time := _attack_time
	_attack_time += delta

	var lunge_start := attack_windup_time
	var lunge_end := attack_windup_time + attack_lunge_time
	var facing := _facing()
	var pose := Pose.new()

	if _attack_time < lunge_start:
		# Wind-up: crouch down low and lean back, trembling with anticipation.
		var t := ease(_attack_time / attack_windup_time, 0.4)
		pose.squash = -attack_windup_squash * t
		pose.skew = -facing * deg_to_rad(attack_windup_lean_degrees) * t
		pose.shake = sin(_attack_time * TAU * 25.0) * 3.0 * t
		return pose

	if previous_time < lunge_start:
		_play_sound(_attack_sound, attack_sound_stream)
		_kick_jiggle(0.0, facing * 8.0)

	if _attack_time < lunge_end:
		# Lunge: spring up into the air, stretch, and spin around.
		var t := (_attack_time - lunge_start) / attack_lunge_time
		var arc := sin(PI * t)
		pose.lift = arc * attack_lunge_height
		pose.squash = attack_lunge_stretch * arc - attack_windup_squash * pow(1.0 - t, 6.0)
		pose.skew = facing * deg_to_rad(attack_windup_lean_degrees) * arc
		pose.rotation = facing * TAU * attack_spin_turns * ease(t, -2.0)
		pose.center_pivot = arc
		return pose

	if previous_time < lunge_end:
		# Slam back down.
		_kick_jiggle(-hop_land_jiggle * 2.5, -facing * 10.0)
		_play_sound(_attack_land_sound, attack_land_sound_stream)

	# Frenzy: shake furiously, flailing back and forth.
	var frenzy_time := _attack_time - lunge_end
	var cycle := frenzy_time * TAU * attack_frenzy_speed
	pose.squash = sin(cycle * 2.0) * attack_frenzy_squash
	pose.rotation = sin(cycle) * deg_to_rad(attack_frenzy_degrees)
	pose.skew = facing * deg_to_rad(attack_windup_lean_degrees) * 0.5
	pose.shake = randf_range(-1.0, 1.0) * attack_frenzy_jitter
	pose.lift = absf(sin(cycle)) * hop_height * 0.3
	return pose


## Adds a sudden push to the jiggle springs. Positive squash kicks stretch it
## tall, negative kicks squash it flat. Rotation kick is in radians per second.
func _kick_jiggle(squash_kick: float, rotation_kick: float) -> void:
	_jiggle_squash_velocity += squash_kick
	_jiggle_rotation_velocity += rotation_kick


func _update_jiggle(delta: float) -> void:
	var squash_acceleration := (
		-jiggle_stiffness * _jiggle_squash - jiggle_damping * _jiggle_squash_velocity
	)
	_jiggle_squash_velocity += squash_acceleration * delta
	_jiggle_squash += _jiggle_squash_velocity * delta

	var rotation_acceleration := (
		-jiggle_stiffness * _jiggle_rotation - jiggle_damping * _jiggle_rotation_velocity
	)
	_jiggle_rotation_velocity += rotation_acceleration * delta
	_jiggle_rotation += _jiggle_rotation_velocity * delta


## Deforms the sprite according to [param pose], keeping the pivot point (the
## feet, or the center while spinning) planted in place.
func _apply_pose(pose: Pose) -> void:
	var squash := clampf(pose.squash, MIN_SQUASH, MAX_SQUASH)
	var deform_scale := Vector2(maxf(1.0 - squash * squash_width_ratio, 0.2), 1.0 + squash)
	var sprite_scale := _base_sprite_scale * deform_scale

	# Pivot points in the sprite's own coordinates.
	var center := animated_sprite_2d.offset
	var half_height := 0.0
	var texture := animated_sprite_2d.sprite_frames.get_frame_texture(
		animated_sprite_2d.animation, animated_sprite_2d.frame
	)
	if texture:
		var size := texture.get_size()
		half_height = size.y / 2.0
		if not animated_sprite_2d.centered:
			center += size / 2.0
	var feet := center + Vector2(0.0, half_height + feet_offset)
	var pivot := feet.lerp(center, pose.center_pivot)

	# Where the pivot sits in the guard's coordinates when not deformed.
	var anchor := _base_sprite_position + _base_sprite_scale * pivot
	var deform := Transform2D(pose.rotation, sprite_scale, pose.skew, Vector2.ZERO)
	var sprite_position := anchor - deform.basis_xform(pivot)
	sprite_position += Vector2(pose.shake, -pose.lift)

	animated_sprite_2d.transform = Transform2D(
		pose.rotation, sprite_scale, pose.skew, sprite_position
	)


## Remembers how the sprite is set up in the scene, so the animation can be
## applied on top of it.
func _capture_base_sprite_transform() -> void:
	_base_sprite_position = animated_sprite_2d.position
	_base_sprite_scale = animated_sprite_2d.scale


func _reset_sprite_transform() -> void:
	animated_sprite_2d.transform = Transform2D(0.0, _base_sprite_scale, 0.0, _base_sprite_position)


func _play_sound(player: AudioStreamPlayer2D, stream: AudioStream) -> void:
	if not stream:
		return
	player.stream = stream
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.play()
