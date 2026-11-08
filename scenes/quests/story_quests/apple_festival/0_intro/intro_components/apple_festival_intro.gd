# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

const INTRO_DIALOGUE = preload("apple_festival_intro.dialogue")
const LETTER_IMAGES: Array[Texture2D] = [
	preload("letter_back.png"),
	preload("letter_front.png"),
	preload("letter_open.png"),
]

var waiting_for_continue: bool = false

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

	# Cut to the addressed envelope, then turn it over and open it.
	picture.texture = LETTER_IMAGES[0]
	for image_index in range(1, LETTER_IMAGES.size()):
		await get_tree().create_timer(1.8, false).timeout
		await _show_picture(LETTER_IMAGES[image_index])

	continue_hint.show()
	waiting_for_continue = true


func _show_picture(texture: Texture2D) -> void:
	next_picture.texture = texture
	var fade: Tween = create_tween()
	fade.tween_property(next_picture, "modulate:a", 1.0, 0.4)
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
