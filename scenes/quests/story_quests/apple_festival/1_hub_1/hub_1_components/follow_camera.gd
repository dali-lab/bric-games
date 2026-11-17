# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D
## Keeps this node centred on whatever the camera is looking at.
##
## Put weather particles (rain, leaves, dust) under it with local_coords off:
## the emitters travel with the camera so they always cover the view, while
## the particles already in the air stay put in the world and scroll past
## naturally as the camera moves.


func _ready() -> void:
	top_level = true


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		global_position = camera.get_screen_center_position()
