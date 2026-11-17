# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
extends Player


## Start the replay over when Sarah runs out of lives.
func _handle_game_over() -> void:
	GameState.player.reset_lives()
	GameState.scene.spawn_point = ^""
	SceneSwitcher.reload_with_transition()
