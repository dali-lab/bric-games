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
	scene_link.switch()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not is_instance_valid(gear):
		warnings.append("Set Gear to the gear whose spin ends the level.")
	if not is_instance_valid(scene_link):
		warnings.append("Set Scene Link to the transition to follow.")
	return warnings
