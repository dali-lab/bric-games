# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
## Somewhere the player is allowed to stand in the mill.
##
## The mill's floor is the union of pieces that spin and travel, so the void between them changes
## every frame and cannot be authored as collision geometry. [GearField] instead asks each piece
## where its surface is, every frame, and keeps the player on top of whichever one they are on.
##
## Describe the surface analytically rather than with collision shapes: it has to stay correct
## while the piece moves. Everything here works in global coordinates, so [method Node2D.to_local]
## is what turns a query into something a subclass can answer in its own frame -- which also means
## rotating or scaling the node is handled for free.
@abstract class_name WalkableSurface
extends Node2D

## How far inside the surface [method project_inside] lands the player, in pixels. Without it,
## rounding can leave the projected point a hair outside and it gets re-projected every frame.
const SURFACE_EPSILON: float = 0.5


## Whether the player may stand on [param global_point].
@abstract func is_point_inside(global_point: Vector2) -> bool


## The closest walkable point to [param global_point], in global coordinates.
##
## Called when the player has walked off the surface, so it decides where they get pushed back
## to. A nearest-point clamp preserves the motion that took them off the edge, which reads as
## sliding along it; a radial one would dump them somewhere they were not heading.
@abstract func project_inside(global_point: Vector2) -> Vector2


## Roughly how far [param global_point] is from this surface, in pixels.
##
## Only ever used to compare surfaces and pick the nearest, so it may be approximate, and may go
## negative for a point that is within the surface's footprint without being on it -- which
## usefully favours the surface the player is standing in the middle of.
@abstract func distance_to_point(global_point: Vector2) -> float


## Advances this surface's own movement by [param delta] seconds. Called by [GearField] before
## it carries the player. Surfaces that never move do not need to override it.
func advance(_delta: float) -> void:
	pass
