# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name LightBulbCheckpoint
extends Area2D
## A light bulb checkpoint where the player respawns if the current scene is reloaded.
##
## When the player enters the area, this becomes the active checkpoint and
## [member target] is made visible.

## Node made visible when this checkpoint is activated. It is hidden at start.
@export var target: Node2D

## The point where the player will spawn.
@onready var spawn_point: SpawnPoint = %SpawnPoint


func _ready() -> void:
	if target:
		target.visible = false
	body_entered.connect(func(_body: Node2D) -> void: activate())


## Makes this the active checkpoint.
func activate() -> void:
	GameState.scene.spawn_point = owner.get_path_to(spawn_point)
	GameState.save()

	if target:
		target.visible = true
