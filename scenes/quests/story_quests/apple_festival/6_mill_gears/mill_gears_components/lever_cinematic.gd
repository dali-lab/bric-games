# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
## Plays a short cutscene the first time a lever is pulled: the camera pans to something, a
## dialogue is shown, and then the camera goes back to the player.
##
## Put it as a child of the lever. The player is held still for the length of the cutscene and
## gets control back once the dialogue is closed.
class_name LeverCinematic
extends Node

## The lever to listen to. Defaults to the parent.
@export var lever: Node

## Camera to cut to while the dialogue is shown. It should sit at priority 0 until then.
@export var camera: PhantomCamera2D

## Priority [member camera] is raised to. Must beat the player's camera, the grappling hook's and
## any other lever cutscene camera.
@export var camera_priority: int = 30

## Dialogue to show once the camera has arrived.
@export var dialogue: DialogueResource

## Cue within [member dialogue] to play.
@export var dialogue_title: String = ""

## Extra time on the shot after the camera has arrived and before the dialogue opens.
@export_range(0.0, 5.0, 0.1, "or_greater") var dialogue_delay: float = 0.3

var _played: bool = false


func _ready() -> void:
	if not lever:
		lever = get_parent()
	if lever and lever.has_signal(&"toggled"):
		lever.toggled.connect(_on_lever_toggled)

var first := 0
func _on_lever_toggled(_is_on: bool) -> void:
	print("hey")
	if first < 2:
		first += 1
		return
	if _played:
		return
	_played = true
	_play()


func _play() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if is_instance_valid(player):
		player.take_control(self)
	await get_tree().create_timer(1.5).timeout
	
	if is_instance_valid(camera):
		camera.priority = camera_priority
		var travel_time := camera.tween_resource.duration if camera.tween_resource else 0.0
		await get_tree().create_timer(travel_time + dialogue_delay).timeout

	if dialogue:
		DialogueManager.show_dialogue_balloon(dialogue, dialogue_title, [self])
		await DialogueManager.dialogue_ended

	if is_instance_valid(camera):
		camera.priority = 0
	if is_instance_valid(player):
		player.return_control(self)
