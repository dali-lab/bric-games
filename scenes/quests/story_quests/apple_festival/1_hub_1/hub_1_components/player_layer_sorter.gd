# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node
## Keeps the player sorted correctly against props on two z layers.
##
## Hub 1 sandwiches the canopy: the forest under the canopy and the player sit
## on z 0, the canopy on z 1, and the top forest, bus, barn and lamps on z 1
## above it. Y-sorting only works within one z layer, so z 1 props would always
## cover the player, even when she stands in front of them.
##
## This leaves the player on her normal layer, and only lifts her to
## [member raised_z_index] while she overlaps a z 1 prop that is behind her
## and no z 0 prop is in front of her. The layering of everything else is
## unchanged.

## The player to lift.
@export var player: Node2D
## The y-sorted node that holds the props (OnTheGround).
@export var sort_root: Node2D
## The layer the top forest and other raised props use.
@export var raised_z_index: int = 1
## Size of the box around the player's feet used to test overlaps.
@export var player_size: Vector2 = Vector2(90, 170)

var _base_z_index: int = 0
## Each entry is [sprite: Sprite2D, sort_node: Node2D, z: int].
var _sprites: Array = []


func _ready() -> void:
	_base_z_index = player.z_index
	_collect(sort_root, 0)


func _physics_process(_delta: float) -> void:
	var feet := player.global_position
	var player_rect := Rect2(feet - Vector2(player_size.x / 2.0, player_size.y), player_size)
	var behind_raised := false
	var in_front_base := false
	for entry: Array in _sprites:
		var sprite: Sprite2D = entry[0]
		if not is_instance_valid(sprite) or not sprite.is_visible_in_tree():
			continue
		var sort_node: Node2D = entry[1]
		var z: int = entry[2]
		if not _global_rect(sprite).intersects(player_rect):
			continue
		var in_front := sort_node.global_position.y > feet.y
		if z == raised_z_index and not in_front:
			behind_raised = true
		elif z <= _base_z_index and in_front:
			in_front_base = true
	player.z_index = raised_z_index if behind_raised and not in_front_base else _base_z_index


## Walks y-sorted containers and records every sprite with the node it is sorted by
## and the z layer it draws on.
func _collect(node: Node, z: int) -> void:
	for child in node.get_children():
		if child == player or not child is CanvasItem:
			continue
		var child_z: int = _child_z(child, z)
		if child is Node2D and (child as Node2D).y_sort_enabled:
			_collect(child, child_z)
		else:
			_collect_unit(child, child, child_z)


## Records all sprites under [param node], which sort as one unit by [param unit].
func _collect_unit(node: Node, unit: Node2D, z: int) -> void:
	if node is Sprite2D:
		_sprites.append([node, unit, z])
	for child in node.get_children():
		if child is CanvasItem:
			_collect_unit(child, unit, _child_z(child, z))


func _child_z(item: CanvasItem, parent_z: int) -> int:
	return parent_z + item.z_index if item.z_as_relative else item.z_index


func _global_rect(sprite: Sprite2D) -> Rect2:
	var local := sprite.get_rect()
	var xform := sprite.global_transform
	var rect := Rect2(xform * local.position, Vector2.ZERO)
	rect = rect.expand(xform * Vector2(local.end.x, local.position.y))
	rect = rect.expand(xform * Vector2(local.position.x, local.end.y))
	return rect.expand(xform * local.end)
