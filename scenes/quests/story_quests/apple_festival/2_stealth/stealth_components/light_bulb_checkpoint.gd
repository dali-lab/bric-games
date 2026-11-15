# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name LightBulbCheckpoint
extends Area2D
## A light bulb checkpoint where the player respawns if the current scene is reloaded.
##
## When the player enters the area, this becomes the active checkpoint, the bulb switches to its
## lit sprite, [member target] is made visible, and a flame sound plays.

## Node made visible when this checkpoint is activated. It is hidden at start.
@export var target: Node2D

## Texture shown on the bulb while this checkpoint is off. The bulb's own texture is used once
## the checkpoint is on.
@export var off_texture: Texture2D

var _is_on := false

## The point where the player will spawn.
@onready var spawn_point: SpawnPoint = %SpawnPoint
@onready var bulb: Sprite2D = %Bulb
@onready var on_texture: Texture2D = bulb.texture
@onready var flame_sound: AudioStreamPlayer2D = %FlameSound


func _ready() -> void:
	# If the player is respawning at this checkpoint, start lit without replaying the sound.
	_set_on(GameState.scene.spawn_point == owner.get_path_to(spawn_point))
	body_entered.connect(func(_body: Node2D) -> void: activate())


## Makes this the active checkpoint.
func activate() -> void:
	GameState.scene.spawn_point = owner.get_path_to(spawn_point)
	GameState.save()

	if _is_on:
		return

	_set_on(true)
	flame_sound.play()


func _set_on(on: bool) -> void:
	_is_on = on
	if target:
		target.visible = on
	if off_texture:
		bulb.texture = on_texture if on else off_texture
