# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

const APPLE_FESTIVAL: StoryQuest = preload("../../quest.tres")
const REPLAY_SCREEN: PackedScene = preload("uid://c0fdh0ttv7brl")
const NEXT_PICTURES: Array[Texture2D] = [
	preload("bus_close.png"),
	preload("thanks_for_playing.png"),
]

@export var picture_duration: float = 4.0
@export var transition_duration: float = 2.0

@onready var picture: TextureRect = $ScreenOverlay/Picture
@onready var next_picture: TextureRect = $ScreenOverlay/NextPicture


func _ready() -> void:
	_play_outro.call_deferred()


func _play_outro() -> void:
	for texture in NEXT_PICTURES:
		await get_tree().create_timer(picture_duration, false).timeout
		next_picture.texture = texture
		var fade: Tween = create_tween()
		fade.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade.tween_property(next_picture, "modulate:a", 1.0, transition_duration)
		await fade.finished
		picture.texture = texture
		next_picture.modulate.a = 0.0
	await get_tree().create_timer(picture_duration, false).timeout

	# The replay screen starts a fresh run of the selected quest.
	GameState.global.set_quest_completed_state(APPLE_FESTIVAL, true)
	GameState.global.suspended_quests.erase(APPLE_FESTIVAL.resource_path)
	GameState.set_quest(APPLE_FESTIVAL)
	SceneSwitcher.change_to_packed_with_transition(
		REPLAY_SCREEN, ^"", Transition.Effect.FADE, Transition.Effect.FADE
	)
