# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
## Leaves the level once a gear is turning under its own train.
##
## Getting drive all the way to the last gear is what the mill asks of the player, so that gear
## coming to life is the win condition, and there is nothing left to walk to afterwards. This
## watches it and follows [member scene_link] the moment it turns.
##
## A [member Gear.driven] gear's speed is worked out from scratch every frame by [GearField], so
## this only has to read [member Gear.angular_velocity] -- zero whenever nothing is pushing it.
class_name GearSpinSceneLink
extends Node

## The gear to watch. Driving this is what finishes the level.
@export var gear: Gear

## The transition to follow once the gear turns.
@export var scene_link: SceneLink

## How long the gear has to keep turning before the level ends.
##
## Gears that orbit or ride a path drift in and out of mesh, so a gear that was nudged for an
## instant and let go again is not the puzzle being solved. This doubles as a beat for the player
## to watch the mill come alive before the screen fades.
@export_range(0.0, 10.0, 0.1) var confirm_time: float = 1.0

## Spin slower than this, in radians per second, counts as standing still.
@export_range(0.0, 1.0, 0.001, "or_greater") var minimum_spin: float = 0.01

@export_group("Ending Cinematic")
## Optional camera to pan to before leaving. When set, winning takes control away from the
## player and raises this camera above every other one, so [PhantomCameraHost] glides the view
## from wherever it was (normally the player) over to it, using this camera's own
## [member PhantomCamera2D.tween_resource] for the move. Leave empty to transition straight away.
@export var cinematic_camera: PhantomCamera2D

## Priority given to [member cinematic_camera] once the level is won. Must beat every other
## camera in the level, including the intro cinematic's and the grappling hook's.
@export var cinematic_priority: int = 100

## How long to linger on the gear once the camera has arrived, before the scene transition.
@export_range(0.0, 10.0, 0.1, "or_greater") var hold_time: float = 1.5

var _spinning_time: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_physics_process(is_instance_valid(gear) and is_instance_valid(scene_link))


func _physics_process(delta: float) -> void:
	if absf(gear.angular_velocity) < minimum_spin:
		_spinning_time = 0.0
		return

	_spinning_time += delta
	if _spinning_time < confirm_time:
		return

	# One transition only: switch() awaits a transition the level does not outlive.
	set_physics_process(false)
	_finish()


func _finish() -> void:
	if is_instance_valid(cinematic_camera):
		await _play_cinematic()
	scene_link.switch()


## Pans the view from the player to [member cinematic_camera] and holds it there.
func _play_cinematic() -> void:
	# The player stays frozen for good: the scene transition follows, so control is never handed
	# back.
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if is_instance_valid(player):
		player.take_control(self)

	cinematic_camera.priority = cinematic_priority

	# Timed off the tween's length instead of awaiting tween_completed, which never fires if
	# there turns out to be nothing to tween from.
	var travel_time := 0.0
	if cinematic_camera.tween_resource:
		travel_time = cinematic_camera.tween_resource.duration
	await get_tree().create_timer(travel_time + hold_time).timeout


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not is_instance_valid(gear):
		warnings.append("Set Gear to the gear whose spin ends the level.")
	if not is_instance_valid(scene_link):
		warnings.append("Set Scene Link to the transition to follow.")
	return warnings
