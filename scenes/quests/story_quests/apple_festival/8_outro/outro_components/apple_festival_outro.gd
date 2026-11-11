# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

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
	# Leave the final picture on screen.
