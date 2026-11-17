# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node
## Opening camera pan: keeps the player still, waits for the scene's fade-in,
## plays [member animation] on [member animation_player], then gives the
## player control back.
##
## The animation should move a high-priority PhantomCamera2D from an overview
## down to where the player's own camera starts, then drop its priority to 0 and
## hide it so the player's camera takes over.

## Plays the pan.
@export var animation_player: AnimationPlayer
## Name of the pan animation.
@export var animation: StringName = &"intro_overview"


func _ready() -> void:
	_play.call_deferred()


func _play() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.take_control(self)

	await get_tree().process_frame
	while Transitions.is_running():
		await Transitions.finished

	if animation_player and animation_player.has_animation(animation):
		animation_player.play(animation)
		await animation_player.animation_finished

	if player:
		player.return_control(self)
