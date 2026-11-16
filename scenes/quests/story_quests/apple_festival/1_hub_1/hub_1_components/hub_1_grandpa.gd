# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
extends NPC
## Grandpa in Hub 1.
##
## When the level starts, the camera pans from an overview of the farm down to
## Sarah, then Grandpa calls her over. After she talks to him, the screen
## fades to black and Grandpa walks over to the cider mill, while Sarah and the
## camera stay put. She is free to explore until she talks to him again by the
## mill (arrows point to him if she takes longer than [member mill_nudge_time]
## seconds). The mill conversation then plays and [member mill_scene_link]
## takes her into the stealth level.

const DIALOGUE: DialogueResource = preload("hub_1_grandpa.dialogue")
const NudgeArrows = preload("nudge_arrows.gd")

## Where Grandpa waits next to the mill after the fade.
@export var mill_marker: Marker2D
## Switches to the stealth level once the mill conversation is over.
@export var mill_scene_link: SceneLink
## Plays the opening camera pan from the farm overview down to Sarah. Optional.
@export var intro_animation_player: AnimationPlayer
## Seconds Sarah can roam after the fade before arrows point her to Grandpa.
@export var mill_nudge_time: float = 20.0

var _waiting_at_mill: bool = false
var _mill_wait: float = 0.0
var _arrows: NudgeArrows

@onready var interact_area: InteractArea = $InteractArea
@onready var talk_behavior: TalkBehavior = $TalkBehavior


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	talk_behavior.dialogue = DIALOGUE
	talk_behavior.title = "start"
	interact_area.interaction_ended.connect(_on_first_talk_ended, CONNECT_ONE_SHOT)
	_arrows = NudgeArrows.new()
	_arrows.target = self
	add_child(_arrows)
	_call_out_to_player.call_deferred()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _waiting_at_mill:
		return
	if _get_player().mode != Player.Mode.USER_CONTROLLED:
		return
	_mill_wait += delta
	if _mill_wait >= mill_nudge_time:
		_waiting_at_mill = false
		_arrows.player = _get_player()
		_arrows.fade_to(1.0)


func _call_out_to_player() -> void:
	# Keep Sarah still through the opening pan and Grandpa's call.
	var player := _get_player()
	player.take_control(self)

	# Let the scene's fade-in finish before the camera starts moving.
	await get_tree().process_frame
	while Transitions.is_running():
		await Transitions.finished

	if intro_animation_player:
		intro_animation_player.play(&"intro_overview")
		await intro_animation_player.animation_finished

	DialogueManager.show_dialogue_balloon(DIALOGUE, "arrival", [self])
	await DialogueManager.dialogue_ended
	player.return_control(self)


func _on_first_talk_ended() -> void:
	interact_area.disabled = true
	var player := _get_player()
	player.take_control(self)

	# Only Grandpa moves during the fade; Sarah and the camera stay where they are.
	await Transitions.do_transition(_move_to_mill)

	talk_behavior.title = "at_mill"
	interact_area.interaction_started.connect(_on_mill_talk_started, CONNECT_ONE_SHOT)
	interact_area.interaction_ended.connect(_on_mill_talk_ended, CONNECT_ONE_SHOT)
	interact_area.disabled = false
	_mill_wait = 0.0
	_waiting_at_mill = true
	player.return_control(self)


func _move_to_mill() -> void:
	global_position = mill_marker.global_position


func _on_mill_talk_started(_player: Player, _from_right: bool) -> void:
	_waiting_at_mill = false
	_arrows.fade_to(0.0, 0.3)


func _on_mill_talk_ended() -> void:
	interact_area.disabled = true
	# Keep Sarah still from here until the stealth level loads.
	_get_player().take_control(self)
	mill_scene_link.switch()


func _get_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player
