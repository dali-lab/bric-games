# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
## Keeps the grappling hook camera on the hookable the player is really attached to.
##
## [PlayerHook] frames a hook by parking a marker, its [code]HookEnding[/code], on the anchor it
## has just caught and pointing its own [PhantomCamera2D] at that marker. The marker is written
## once, at the moment of the hook, and is an ordinary child of the player, so from then on it
## rides the player rather than the thing hooked. For the needles planted on a turning gear that
## leaves the camera framing the patch of air the needle has since swung out of.
##
## This re-reads the anchor every physics frame for as long as the hook camera is the active one.
## The string already does exactly this for its own first point, in
## [code]PlayerHook._process_hook_string[/code]; the camera is the part that was left behind.
##
## Put one anywhere in the scene. It finds the player through the [code]player[/code] group, the
## same way [GearField] does, and goes quiet if there is no hook to follow.
class_name GearHookCamera
extends Node

## Runs just after [GearField] has moved the gears for this frame, so the anchor read below is
## where the needle has ended up rather than where it started.
const PHYSICS_PRIORITY: int = GearField.PHYSICS_PRIORITY + 1

## While the hook camera sits at this priority it is dormant and the player's own camera is the
## one on screen, so there is nothing to keep pointed at anything.
const CAMERA_DORMANT_PRIORITY: int = 0

var _hook: PlayerHook


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if is_instance_valid(player):
		_hook = player.get_node_or_null(^"PlayerHook")


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_hook):
		return

	# Reading these lazily rather than in _ready: they are @onready on PlayerHook, which may not
	# have run by the time this node is ready.
	var camera: PhantomCamera2D = _hook.phantom_camera_2d
	var ending: Marker2D = _hook.hook_ending
	if not is_instance_valid(camera) or not is_instance_valid(ending):
		return

	# Dormant camera means the hook has been let go, or the player is being pulled along the
	# string. Either way PlayerHook owns the marker again, and must be left to put it back.
	if camera.priority == CAMERA_DORMANT_PRIORITY:
		return

	var area: HookableArea = _hook.get_ending_area()
	if not is_instance_valid(area):
		return

	ending.global_position = area.get_anchor_position()
