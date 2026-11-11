# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
extends NPC

var wants_to_leave: bool = false

@onready var interact_area: InteractArea = $InteractArea
@onready var scene_link: SceneLink = $SceneLink


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	interact_area.interaction_ended.connect(_on_interaction_ended)


func _on_interaction_ended() -> void:
	if wants_to_leave:
		# Finish the conversation and return control before starting the transition.
		interact_area.disabled = true
		scene_link.switch.call_deferred()
