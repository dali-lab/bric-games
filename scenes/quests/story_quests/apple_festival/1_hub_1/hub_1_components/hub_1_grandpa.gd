# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
extends NPC
## Grandpa in Hub 1.
##
## Calls Sarah over when the level starts. After she talks to him, the screen
## fades to black, both of them are moved in front of the cider mill, the mill
## conversation plays, and then the mill door's scene link takes her into the
## stealth level.

const DIALOGUE: DialogueResource = preload("hub_1_grandpa.dialogue")

## Where Grandpa stands in front of the mill after the fade.
@export var mill_marker: Marker2D
## Where Sarah is placed in front of the mill after the fade.
@export var mill_spawn_point: SpawnPoint
## The mill door. It stays locked until the mill conversation is over.
@export var mill_door: SceneLinkArea

@onready var interact_area: InteractArea = $InteractArea
@onready var talk_behavior: TalkBehavior = $TalkBehavior


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	talk_behavior.dialogue = DIALOGUE
	talk_behavior.title = "start"
	interact_area.interaction_ended.connect(_on_interaction_ended, CONNECT_ONE_SHOT)
	# Sarah shouldn't walk into the mill before Grandpa has explained what's going on.
	mill_door.set_deferred("monitoring", false)
	_call_out_to_player.call_deferred()


func _call_out_to_player() -> void:
	# Let the scene's fade-in finish before Grandpa speaks.
	await get_tree().process_frame
	while Transitions.is_running():
		await Transitions.finished

	var player := _get_player()
	player.take_control(self)
	DialogueManager.show_dialogue_balloon(DIALOGUE, "arrival", [self])
	await DialogueManager.dialogue_ended
	player.return_control(self)


func _on_interaction_ended() -> void:
	interact_area.disabled = true
	# Keep Sarah still from here until the stealth level loads.
	_get_player().take_control(self)

	await Transitions.do_transition(_move_to_mill)

	DialogueManager.show_dialogue_balloon(DIALOGUE, "at_mill", [self])
	await DialogueManager.dialogue_ended
	mill_door.scene_link.switch()


func _move_to_mill() -> void:
	global_position = mill_marker.global_position
	mill_spawn_point.move_player_to_self_position()


func _get_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player
