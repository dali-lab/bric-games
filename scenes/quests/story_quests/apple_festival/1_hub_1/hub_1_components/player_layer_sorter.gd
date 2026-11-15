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
## unchanged. Other moving characters (such as Grandpa) can be sorted the same
## way by adding them to [member extra_characters].

## The player to lift.
@export var player: Node2D
## Other characters to sort the same way as the player, e.g. NPCs that walk around.
@export var extra_characters: Array[Node2D] = []
## The y-sorted node that holds the props (OnTheGround).
@export var sort_root: Node2D
## The layer the top forest and other raised props use.
@export var raised_z_index: int = 1
## Size of the box around the player's feet used to test overlaps.
@export var player_size: Vector2 = Vector2(90, 170)
## When a character is in front of a raised prop but behind a normal-layer prop
## at the same time (e.g. between a lamp and a fountain), lift that normal prop
## to the raised layer too for as long as it lasts, so all three sort by height.
## Leave off where lifting would pull props above the canopy (Hub 1).
@export var lift_props_in_conflicts: bool = false
## Pixels at the bottom of that box that are ignored. Props drawn only at foot
## level, like the rim of a fountain the player stands just above, can't cover her.
@export var foot_margin: float = 14.0

## The z_index each character had at start, by character.
var _base_z_index: Dictionary = {}
var _characters: Array[Node2D] = []
## Each entry is [sprite: Sprite2D, sort_node: Node2D, z: int].
var _sprites: Array = []
## Props currently lifted to resolve a conflict, mapped to their own z_index.
var _lifted_props: Dictionary = {}
var _props_to_lift: Dictionary = {}


func _ready() -> void:
	_characters.append(player)
	for character in extra_characters:
		if character and character not in _characters:
			_characters.append(character)
	for character in _characters:
		_base_z_index[character] = character.z_index
	_collect(sort_root, 0)


func _physics_process(_delta: float) -> void:
	_props_to_lift.clear()
	for character in _characters:
		if is_instance_valid(character):
			_sort(character, _base_z_index[character])
	_update_lifted_props()


func _sort(character: Node2D, base_z: int) -> void:
	var feet := character.global_position
	var player_rect := Rect2(
		feet - Vector2(player_size.x / 2.0, player_size.y),
		player_size - Vector2(0.0, foot_margin))
	var behind_raised := false
	var in_front_base := false
	var covering: Dictionary = {}
	for entry: Array in _sprites:
		var sprite: Sprite2D = entry[0]
		if not is_instance_valid(sprite) or not sprite.is_visible_in_tree():
			continue
		var sort_node: Node2D = entry[1]
		var z: int = entry[2]
		if not _overlaps(sprite, player_rect):
			continue
		var in_front := sort_node.global_position.y > feet.y
		if z == raised_z_index and not in_front:
			behind_raised = true
		elif z <= base_z and in_front:
			in_front_base = true
			covering[sort_node] = raised_z_index - z
	if behind_raised and in_front_base and lift_props_in_conflicts:
		character.z_index = raised_z_index
		_props_to_lift.merge(covering)
		return
	character.z_index = raised_z_index if behind_raised and not in_front_base else base_z


func _update_lifted_props() -> void:
	for prop: Node2D in _lifted_props.keys():
		if not _props_to_lift.has(prop):
			if is_instance_valid(prop):
				prop.z_index = _lifted_props[prop]
			_lifted_props.erase(prop)
	for prop: Node2D in _props_to_lift:
		if not _lifted_props.has(prop):
			_lifted_props[prop] = prop.z_index
			prop.z_index += _props_to_lift[prop]


## Walks y-sorted containers and records every sprite with the node it is sorted by
## and the z layer it draws on.
func _collect(node: Node, z: int) -> void:
	for child in node.get_children():
		if child == player or child in extra_characters or not child is CanvasItem:
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


## True if any visible (non-transparent) pixel of [param sprite] falls inside
## [param rect]. Comparing whole sprite rectangles is too coarse: a fountain's
## empty corners would count as covering the player.
func _overlaps(sprite: Sprite2D, rect: Rect2) -> bool:
	var area := _global_rect(sprite).intersection(rect)
	if not area.has_area():
		return false
	var columns := clampi(int(area.size.x / 8.0), 2, 12)
	var rows := clampi(int(area.size.y / 12.0), 2, 15)
	for ix in columns:
		for iy in rows:
			var point := area.position + area.size * Vector2(
				(ix + 0.5) / columns, (iy + 0.5) / rows)
			if sprite.is_pixel_opaque(sprite.to_local(point)):
				return true
	return false


func _global_rect(sprite: Sprite2D) -> Rect2:
	var local := sprite.get_rect()
	var xform := sprite.global_transform
	var rect := Rect2(xform * local.position, Vector2.ZERO)
	rect = rect.expand(xform * Vector2(local.end.x, local.position.y))
	rect = rect.expand(xform * Vector2(local.position.x, local.end.y))
	return rect.expand(xform * local.end)
