# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
## Keeps a [Node2D] at a fixed world rotation while still following its parent's position.
##
## Attach to a child of a spinning [Gear] (e.g. a needle) so it rides along with the gear
## without turning with it.
extends Node2D


## The world rotation to hold. Captured from the node's placement in the scene when it enters
## the tree.
var _locked_global_rotation: float


func _ready() -> void:
	_locked_global_rotation = global_rotation
	# Run after [GearField] has spun the gears for this frame.
	process_physics_priority = 100


func _physics_process(_delta: float) -> void:
	global_rotation = _locked_global_rotation
