# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
## Drives every [Gear] in the scene and keeps the player standing on them.
##
## The walkable surface is the union of moving, rotating gears, so its complement -- the void --
## changes every frame and cannot be authored as collision geometry. Instead this node
## constrains the player analytically: after the player has moved, it carries them with
## whichever gear they are on and projects them back onto it if they left.
##
## It stands down whenever the player is not [constant Player.Mode.USER_CONTROLLED], which is
## what [PlayerHook] sets while it pulls the player across a gap, and re-acquires the nearest
## gear once control returns.
class_name GearField
extends Node

## Runs after the player's own [code]_physics_process[/code], so the carry and the clamp are
## applied to a position the player has already moved to this frame.
const PHYSICS_PRIORITY: int = 10

## Node holding the gears. Defaults to this node's own children.
@export var gears_root: Node2D:
	set = _set_gears_root

## Tooth size applied to every gear. Gears mesh only when they share a module.
@export_range(4.0, 64.0, 0.5, "or_greater") var module: float = 16.0:
	set = _set_module

var _gears: Array[Gear] = []
var _player: Player
var _current_index: int = -1
var _needs_reacquire: bool = true


func _ready() -> void:
	_collect_gears()
	_apply_module()
	if Engine.is_editor_hint():
		return

	process_physics_priority = PHYSICS_PRIORITY
	_player = get_tree().get_first_node_in_group(&"player") as Player


func _set_gears_root(value: Node2D) -> void:
	gears_root = value
	_collect_gears()
	_apply_module()


func _set_module(value: float) -> void:
	module = value
	_apply_module()


func _collect_gears() -> void:
	_gears.clear()
	var root: Node = gears_root if gears_root else self
	if not is_instance_valid(root):
		return
	for child in root.find_children("*", "Gear", true, false):
		_gears.append(child as Gear)


func _apply_module() -> void:
	for gear in _gears:
		gear.module = module


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Remember where each gear was, then move it, so the carry below can replay the exact
	# rigid motion the gear just underwent.
	var previous: Array[Transform2D] = []
	previous.resize(_gears.size())
	for i in _gears.size():
		previous[i] = _gears[i].global_transform
		_gears[i].advance(delta)

	if not is_instance_valid(_player) or _player.mode == Player.Mode.DEFEATED:
		return

	# The hook (or a dialogue) owns the player: do not fight it.
	if _player.mode != Player.Mode.USER_CONTROLLED:
		_needs_reacquire = true
		return

	if _needs_reacquire or _current_index < 0:
		_reacquire()
		return

	_carry(previous[_current_index])
	_constrain()


## Applies the current gear's rigid motion to the player. This covers spin and travel at once,
## and only moves the player -- a top-down character must not rotate with the gear.
func _carry(previous_transform: Transform2D) -> void:
	var gear := _gears[_current_index]
	var target: Vector2 = (
		gear.global_transform * (previous_transform.affine_inverse() * _player.global_position)
	)
	var motion := target - _player.global_position
	if not motion.is_zero_approx():
		# move_and_collide rather than assigning the position, so walls and props stay solid.
		_player.move_and_collide(motion)


## Keeps the player on a gear, preferring the one they are already on so that overlapping teeth
## do not make the choice flap between two gears.
func _constrain() -> void:
	var gear := _gears[_current_index]
	if gear.is_point_inside(_player.global_position):
		return

	for i in _gears.size():
		if i != _current_index and _gears[i].is_point_inside(_player.global_position):
			_current_index = i
			return

	_player.global_position = gear.project_inside(_player.global_position)


## Puts the player back on the nearest gear. Used on spawn, and after the hook releases them --
## possibly over open void.
func _reacquire() -> void:
	_needs_reacquire = false
	_current_index = _nearest_gear_index(_player.global_position)
	if _current_index < 0:
		return

	var gear := _gears[_current_index]
	if not gear.is_point_inside(_player.global_position):
		_player.global_position = gear.project_inside(_player.global_position)


func _nearest_gear_index(point: Vector2) -> int:
	var best := -1
	var best_distance := INF
	for i in _gears.size():
		var gear := _gears[i]
		if gear.is_point_inside(point):
			return i
		var distance := point.distance_to(gear.global_position) - gear.tip_radius
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	_collect_gears()
	if _gears.is_empty():
		warnings.append("No Gear nodes found. Set Gears Root, or add Gear children.")
	return warnings
