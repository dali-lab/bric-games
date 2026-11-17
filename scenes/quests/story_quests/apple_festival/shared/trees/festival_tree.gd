# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
extends StaticBody2D

@export var tree_texture: Texture2D:
	set(value):
		tree_texture = value
		if is_node_ready():
			_update_sprite()

@export var leaf_color := Color("#66a52c"):
	set(value):
		leaf_color = value
		if is_node_ready():
			$DriftingLeaves.self_modulate = value

@onready var sprite: Sprite2D = $Sway/Sprite2D


func _ready() -> void:
	_update_sprite()
	$DriftingLeaves.self_modulate = leaf_color


func _update_sprite() -> void:
	sprite.texture = tree_texture
	if tree_texture:
		# Scale each drawing so the trunk meets the ground at the tree's origin.
		var height := -2.0 * sprite.position.y
		sprite.scale = Vector2.ONE * height / tree_texture.get_height()
