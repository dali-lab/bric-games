# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D


func _ready() -> void:
	# This dodging game only needs the shared player's movement controls.
	var player: Player = $OnTheGround/Player
	for ability: Node2D in [player.player_hook, player.player_repel]:
		ability.hide()
		ability.process_mode = Node.PROCESS_MODE_DISABLED
