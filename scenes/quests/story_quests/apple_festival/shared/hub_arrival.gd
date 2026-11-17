# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

@export var grandpa_talk: TalkBehavior
@export var arrival_cue: String = "start"
## Set this to remember the welcome when returning from a minigame.
@export var welcome_fact: String

@onready var player: Player = $OnTheGround/PlayerGirl
@onready var player_camera: PhantomCamera2D = $OnTheGround/PlayerGirl/PhantomCamera2D
@onready var overview_camera: PhantomCamera2D = $OverviewCamera


func _enter_tree() -> void:
	# Choose the camera before either camera registers with the host.
	if GameState.quest and GameState.quest.facts.has(welcome_fact):
		$OverviewCamera.hide()
		$OnTheGround/PlayerGirl/PhantomCamera2D.tween_on_load = false


func _ready() -> void:
	if not overview_camera.visible:
		return

	player.take_control(self)
	player.player_interaction.character_sight.monitoring = false

	await get_tree().process_frame
	if not welcome_fact.is_empty() and GameState.quest:
		GameState.quest.facts[welcome_fact] = true
		GameState.save()

	while Transitions.is_running():
		await Transitions.finished
	await get_tree().create_timer(2.3, false).timeout

	# Hand the shot to Sarah's follow camera, which eases down to her and Grandpa.
	overview_camera.hide()
	await player_camera.tween_completed

	var usual_cue := grandpa_talk.title
	grandpa_talk.title = arrival_cue
	var area := grandpa_talk.interact_area
	area.start_interaction(player, player.global_position.x > area.global_position.x)
	await area.interaction_ended
	grandpa_talk.title = usual_cue

	player.player_interaction.character_sight.monitoring = true
	player.return_control(self)
