# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
extends NPC
## Grandpa in Hub 2.
##
## Waits in front of the mill. When Sarah talks to him the "start" conversation
## plays; afterwards he walks along [member walk_path] into the apple trees and
## [member apple_trees_link] unlocks, so walking into it starts the apple
## minigame. Sarah can move freely while he walks.
##
## Walking uses his standing frame with a hop and sway, like Sarah's walk.

const DIALOGUE: DialogueResource = preload("hub_2_grandpa.dialogue")

## Route to the apple trees. Its points are followed in order, starting from
## wherever Grandpa is standing.
@export var walk_path: Path2D
## Trigger that starts the apple minigame. Locked until the conversation ends.
@export var apple_trees_link: Area2D
## Walking speed in pixels per second.
@export var walk_speed: float = 150.0

@export_group("Walk motion")
## Seconds for one full hop cycle (two steps).
@export var step_cycle: float = 0.8
## How high each step lifts him, in pixels.
@export var hop_height: float = 6.0
## Side-to-side sway, in pixels.
@export var sway_pixels: float = 4.0
## Rocking angle at each step, in degrees.
@export var rock_degrees: float = 7.0

var _walking: bool = false
var _phase: float = 0.0
var _resting_position: Vector2
var _resting_rotation: float

@onready var interact_area: InteractArea = $InteractArea
@onready var talk_behavior: TalkBehavior = $TalkBehavior
@onready var idle_motion: Node = get_node_or_null("IdleMotion")


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	talk_behavior.dialogue = DIALOGUE
	talk_behavior.title = "start"
	interact_area.interaction_ended.connect(_on_talk_ended, CONNECT_ONE_SHOT)
	if apple_trees_link:
		apple_trees_link.set_deferred("monitoring", false)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _walking:
		return
	_phase = fmod(_phase + delta / step_cycle, 1.0)
	var angle := TAU * _phase
	var rock := deg_to_rad(rock_degrees) * sin(angle)
	var lift := hop_height * absf(sin(angle))
	var sway := sway_pixels * sin(angle)
	# Rock around his feet, so they stay planted while the body tips.
	animated_sprite_2d.rotation = _resting_rotation + rock
	animated_sprite_2d.position = _resting_position.rotated(rock) + Vector2(sway, -lift)


func _on_talk_ended() -> void:
	interact_area.disabled = true
	if apple_trees_link:
		apple_trees_link.monitoring = true
	if walk_path:
		await _walk_along(walk_path)


func _walk_along(path: Path2D) -> void:
	_start_walk_motion()
	var curve := path.curve
	for i in curve.point_count:
		var target := path.to_global(curve.get_point_position(i))
		var distance := global_position.distance_to(target)
		if distance < 1.0:
			continue
		if not is_zero_approx(target.x - global_position.x):
			animated_sprite_2d.flip_h = target.x < global_position.x
		var tween := create_tween()
		tween.tween_property(self, "global_position", target, distance / walk_speed)
		await tween.finished
	_stop_walk_motion()


func _start_walk_motion() -> void:
	if idle_motion:
		idle_motion.set_process(false)
		_resting_position = idle_motion.resting_position
		_resting_rotation = idle_motion.resting_rotation
		animated_sprite_2d.scale = idle_motion.resting_scale
	else:
		_resting_position = animated_sprite_2d.position
		_resting_rotation = animated_sprite_2d.rotation
	_phase = 0.0
	_walking = true


func _stop_walk_motion() -> void:
	_walking = false
	animated_sprite_2d.position = _resting_position
	animated_sprite_2d.rotation = _resting_rotation
	if idle_motion:
		idle_motion.set_process(true)
