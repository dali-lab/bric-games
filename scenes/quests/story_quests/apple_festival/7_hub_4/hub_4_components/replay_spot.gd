# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Area2D

const DIALOGUE: DialogueResource = preload("replay.dialogue")
const REPLAY_DIR := "res://scenes/quests/story_quests/apple_festival/7_hub_4/hub_4_components/replays/"
const LEVELS: Dictionary[String, String] = {
	"apples": REPLAY_DIR + "apple_dodge_replay.tscn",
	"sneaking": REPLAY_DIR + "stealth_replay.tscn",
	"gears": "uid://cagcg8dpqjcvn",
}

@export_enum("forest", "mill") var cue: String = "forest"

var replay_level: String = ""


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if not player or player.mode != Player.Mode.USER_CONTROLLED:
		return

	player.input_walk_behavior.input_vector = Vector2.ZERO
	player.input_walk_behavior.is_running = false
	player.velocity = Vector2.ZERO
	player.take_control(self)

	replay_level = ""
	var balloon := DialogueManager.show_dialogue_balloon(DIALOGUE, cue, [self, player])
	await balloon.tree_exited
	if not is_inside_tree() or not is_instance_valid(player):
		return

	if not replay_level.is_empty():
		await SceneSwitcher.change_to_file_with_transition(
			LEVELS[replay_level], ^"", Transition.Effect.FADE, Transition.Effect.FADE
		)
	if is_instance_valid(player):
		player.return_control(self)
