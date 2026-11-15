# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

const INTRO_DIALOGUE = preload("apple_festival_intro.dialogue")
const LETTER_BACK = preload("letter_back.png")
const LETTER_FRONT = preload("letter_front.png")
const LETTER_OPEN = preload("letter_open.png")
const FADE_DURATION := 0.4

var waiting_for_continue: bool = false

@onready var bedroom_ambience: AudioStreamPlayer = $BedroomAmbience
@onready var letter_unfold: AudioStreamPlayer = $LetterUnfold
@onready var picture: TextureRect = $ScreenOverlay/Picture
@onready var next_picture: TextureRect = $ScreenOverlay/NextPicture
@onready var continue_hint: LabeledInputHint = $ScreenOverlay/ContinueHint
@onready var scene_link: SceneLink = $SceneLink


func _ready() -> void:
	continue_hint.text = "Continue"
	_play_intro.call_deferred()


func _play_intro() -> void:
	await get_tree().create_timer(0.5, false).timeout
	var balloon: Node = DialogueManager.show_dialogue_balloon(INTRO_DIALOGUE, "start")
	await balloon.tree_exited
	if not is_inside_tree() or is_queued_for_deletion():
		return

	var ambience_fade := create_tween()
	ambience_fade.tween_property(bedroom_ambience, "volume_linear", 0.0, FADE_DURATION)
	ambience_fade.tween_callback(bedroom_ambience.stop)

	await _show_picture(LETTER_BACK)
	await get_tree().create_timer(1.8, false).timeout
	await _show_picture(LETTER_FRONT)
	await get_tree().create_timer(1.8, false).timeout
	letter_unfold.play()
	await _show_picture(LETTER_OPEN)

	continue_hint.show()
	waiting_for_continue = true


func _show_picture(texture: Texture2D) -> void:
	next_picture.texture = texture
	var fade: Tween = create_tween()
	fade.tween_property(next_picture, "modulate:a", 1.0, FADE_DURATION)
	await fade.finished
	picture.texture = texture
	next_picture.modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not waiting_for_continue or not event.is_action_pressed(&"interact"):
		return

	waiting_for_continue = false
	continue_hint.hide()
	get_viewport().set_input_as_handled()
	scene_link.switch()
