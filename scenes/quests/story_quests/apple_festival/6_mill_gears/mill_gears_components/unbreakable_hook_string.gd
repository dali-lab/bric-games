# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
## Stops the grappling hook string from snapping when the player gets too far from what it is
## hooked to.
##
## [PlayerHook] shatters the string once the stretch between the player and the last thing hooked
## grows past [member PlayerHook.string_max_length]. In the mill the needles ride on turning gears
## and the player is carried along by the floor, so that distance changes on its own and the
## string would break under a player who did nothing wrong.
##
## [Player] writes its own value back into that property whenever the player's abilities change,
## so setting it once is not enough. This lifts the limit every physics frame, ahead of
## [PlayerHook] checking it.
##
## Drop one anywhere in the scene. It finds the player through the [code]player[/code] group.
class_name UnbreakableHookString
extends Node

## Runs before [PlayerHook] measures the string, so the limit is already lifted when it does.
const PHYSICS_PRIORITY: int = -10

var _hook: PlayerHook


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if is_instance_valid(player):
		_hook = player.get_node_or_null(^"PlayerHook")
	_lift_limit()


func _physics_process(_delta: float) -> void:
	_lift_limit()


func _lift_limit() -> void:
	if is_instance_valid(_hook):
		_hook.string_max_length = INF
