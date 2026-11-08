# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D
## A generator that is started by a [Lever].
##
## When [member lever] is switched on, the generator plays its sound, flickers
## each of [member lights] on, and after [member transition_delay] seconds
## triggers [member scene_link] to leave the level.

## The lever that starts the generator.
@export var lever: Lever

## Lights (or any CanvasItem) that are hidden at start and flicker on when the
## generator starts.
@export var lights: Array[CanvasItem]

## Scene link used to leave the level once the generator is running.
@export var scene_link: SceneLink

## CanvasModulate whose alpha is tweened to 0 over [member transition_delay]
## once the generator starts.
@export var canvas_modulate: CanvasModulate

## Seconds between pulling the lever and switching scenes.
@export var transition_delay: float = 3.0

## Seconds between the sound starting and the lights beginning to flicker.
@export var lights_delay: float = 0.3

## Maximum random delay before each individual light starts flickering, so they
## don't all turn on in perfect sync.
@export var max_light_stagger: float = 0.4

## Number of on/off flashes each light does before staying on.
@export var flicker_count: int = 6

var _started := false

@onready var sound: AudioStreamPlayer2D = %StartSound
@onready var sound2: AudioStreamPlayer2D = %StartSound2


func _ready() -> void:
	for light: CanvasItem in lights:
		light.visible = false
	if lever:
		lever.toggled.connect(_on_lever_toggled)


func _on_lever_toggled(is_on: bool) -> void:
	if not is_on or _started:
		return
	_started = true

	# Don't let the player switch it back off.
	var interact_area: InteractArea = lever.get_node_or_null("InteractArea")
	if interact_area:
		interact_area.set_deferred(&"disabled", true)

	sound.play()
	sound2.play()
	_turn_on_lights()

	if canvas_modulate:
		create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE).tween_property(canvas_modulate, "color", Color.WHITE, 2.0).set_delay(1.0)

	await get_tree().create_timer(transition_delay).timeout
	if scene_link:
		scene_link.switch()


func _turn_on_lights() -> void:
	await get_tree().create_timer(lights_delay).timeout
	for light: CanvasItem in lights:
		_flicker_on(light)


func _flicker_on(light: CanvasItem) -> void:
	await get_tree().create_timer(randf_range(0.0, max_light_stagger)).timeout
	for i: int in flicker_count:
		light.visible = not light.visible
		await get_tree().create_timer(randf_range(0.03, 0.12)).timeout
	light.visible = true
