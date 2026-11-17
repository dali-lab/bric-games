# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
## Keeps every point of the grappling hook string on the needle it is hooked to.
##
## [PlayerHook] only moves the two ends of its string each frame: the newest thing hooked and the
## player. Every needle in between is a "connection", and connections are assumed never to move,
## so the string stays pinned to wherever a needle was when it got hooked. In the mill the needles
## ride on turning and travelling gears, so in a chain the string visibly falls behind them. The
## same happens to the needle a throw was made from when that throw misses: it becomes the middle
## point while the missed end reels back in.
##
## The ends lag too, by a frame. [PlayerHook] updates at the default physics priority, before
## [GearField] has moved the gears and carried the player, so it draws them where they were.
##
## This runs once the gears have settled for the frame and rewrites every point from what it is
## hooked to. Purely visual: [PlayerHook] reads the same positions next frame either way.
##
## Put one anywhere in the scene. It finds the player through the [code]player[/code] group.
class_name GearHookString
extends Node

## After [GearField] has moved the gears and anything that adjusts a needle afterwards (such as
## [code]keep_upright.gd[/code]), so the anchors read here are where the needles are drawn.
const PHYSICS_PRIORITY: int = GearField.PHYSICS_PRIORITY + 2

var _hook: PlayerHook


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if is_instance_valid(player):
		_hook = player.get_node_or_null(^"PlayerHook")


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_hook):
		return
	var line: Line2D = _hook.hook_string
	if not is_instance_valid(line) or line.is_queued_for_deletion():
		return
	var count := line.get_point_count()
	if count < 2:
		return

	# The player's end. Same point PlayerHook uses, just read after the floor has carried them.
	line.set_point_position(count - 1, line.to_local(_hook.global_position))

	# Every other point, newest first. PlayerHook inserts each new hook at the front of the line
	# and appends it to the back of areas_hooked, so point i is areas_hooked[-1 - i].
	#
	# While pulling, points are consumed off the ends of the line without areas_hooked changing.
	# Ones the player passes come off the player's end, which keeps the count from the front
	# right. Ones a pulled object passes come off the front and would throw it out, which can
	# only happen when the object is light enough to move at all, so leave the middle alone then.
	var areas := _hook.areas_hooked
	var ending := _hook.get_ending_area()
	if _hook.pulling and is_instance_valid(ending) and ending.weight != 1.0:
		_set_anchor(line, 0, ending)
		return

	for i in mini(count - 1, areas.size()):
		# A null entry is a throw that hit the air or a wall. Its point is reeled in by
		# PlayerHook, not attached to anything.
		_set_anchor(line, i, areas[areas.size() - 1 - i])


func _set_anchor(line: Line2D, index: int, area: HookableArea) -> void:
	if is_instance_valid(area):
		line.set_point_position(index, line.to_local(area.get_anchor_position()))
