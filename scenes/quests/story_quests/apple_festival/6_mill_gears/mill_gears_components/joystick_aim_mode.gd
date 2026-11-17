# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
## Makes the grappling hook playable with nothing but a direction.
##
## On a gamepad the hook is aimed with the right stick and the player walks with the left, so the
## two never interfere. With one stick, or on the keyboard, [code]aim_*[/code] and
## [code]move_*[/code] are the same inputs, which leaves two problems: lining up a throw walks
## the player across the floor at the same time, and a direction that only comes in eight steps
## cannot be pointed at a needle that is not on one of those eight lines.
##
## Switch this on and, for as long as the player is hooked to a needle and aiming from it:
## [br][br]
## • they hold still, so pushing a direction aims without walking;
## [br]
## • the aim is always snapped onto some hookable, as long as at least one is within reach. The
##   direction pushed only says which one to favour: the nearest hookable roughly that way wins.
##   Pushing a direction with nothing in it keeps the hookable already snapped onto rather than
##   letting go of it, and only when there is nothing to keep does the aim fall back to whichever
##   reachable hookable lies closest round from the direction pushed.
## [br][br]
## Snapping applies to the player's own hook control too, so the first throw of a chain is aimed
## the same way as the ones from needles.
##
## Drop one anywhere in the scene. It finds the player through the [code]player[/code] group, the
## same way [GearField] does, and does nothing at all while switched off.
class_name JoystickAimMode
extends Node

## Runs after the hook controls have pointed themselves at the raw input, so the snap is applied
## to the angle they settled on.
const PROCESS_PRIORITY: int = 10

## Runs before the player's walk behaviour reads its input vector, so holding still takes effect
## the same frame.
const PHYSICS_PRIORITY: int = -10

## Whether any of this is in effect. Off leaves the hook exactly as it behaves by default.
@export var enabled: bool = true:
	set = _set_enabled

## How far either side of the aimed direction a hookable may be and still count as being "in" that
## direction, which is what it takes to pull the snap away from the hookable it is already on.
##
## Eight directions are 45 degrees apart, so half of that covers the whole circle with no gaps:
## every hookable in reach lies in exactly one direction's sector. Widen it and the sectors
## overlap, which makes the nearer hookable win more often. Hookables outside every sector can
## still be snapped onto; they are just never chosen over the one already held.
@export_range(0.0, 90.0, 0.5, "radians_as_degrees") var snap_arc: float = deg_to_rad(22.5)

## Hold the player still while they are aiming from a needle.
@export var hold_still: bool = true

## Snap the aim onto a hookable, favouring the nearest one in the aimed direction.
@export var snap_aim: bool = true

var _hook: PlayerHook
var _walk: InputWalkBehavior

## The hookable the aim is currently snapped onto, and the control it was snapped for. Kept so
## that pushing towards empty space does not let go of it.
var _snapped: HookableArea
var _snapped_control: HookControl

## True between [signal PlayerHook.aiming_changed] going on and off: the player is parked on a
## needle, lining up the next throw.
var _aiming: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	process_priority = PROCESS_PRIORITY
	process_physics_priority = PHYSICS_PRIORITY

	var player: Node = get_tree().get_first_node_in_group(&"player")
	if not is_instance_valid(player):
		return
	_hook = player.get_node_or_null(^"PlayerHook")
	_walk = player.get_node_or_null(^"InputWalkBehavior")
	if is_instance_valid(_hook):
		_hook.aiming_changed.connect(_on_aiming_changed)


func _set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_aiming = false


func _on_aiming_changed(is_aiming: bool) -> void:
	_aiming = is_aiming


## Keeps the player planted while they aim from a needle.
##
## Zeroing the walk behaviour's input rather than the character's velocity, so the player eases
## to a stop on its own terms and anything else that moves them -- a gear turning underneath
## them, the hook pulling them -- is left alone.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if enabled and hold_still and _aiming and is_instance_valid(_walk):
		_walk.input_vector = Vector2.ZERO


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not enabled or not snap_aim:
		return

	var control := _active_control()
	if control != _snapped_control:
		# A different control (or none) is aiming now: whatever was held belonged to the old one.
		_snapped = null
		_snapped_control = control
	if not control:
		return
	if not is_instance_valid(_snapped):
		_snapped = null

	_snapped = _best_hookable(control)
	if _snapped:
		control.global_rotation = control.global_position.angle_to_point(
			_snapped.get_anchor_position()
		)


## The one hook control taking input right now, if any.
##
## Throwing from a needle disables the control that threw and hands aiming to the one on the
## needle it caught, so the control to steer is the one belonging to the last thing hooked, and
## the player's own whenever nothing is.
func _active_control() -> HookControl:
	if not is_instance_valid(_hook):
		return null

	var ending := _hook.get_ending_area()
	var control: HookControl = (
		ending.hook_control if is_instance_valid(ending) and ending.hook_control
		else _hook.hook_control
	)
	if not is_instance_valid(control) or control.state != HookControl.State.AIMING:
		return null
	return control


## The hookable [param control] should be snapped onto, out of the ones it could actually reach.
## Null only when it can reach none at all.
##
## In order of preference:
## [br]• the nearest one within [member snap_arc] of where the player is pushing;
## [br]• failing that, the one already snapped onto, if it is still within reach;
## [br]• failing that, whichever lies the smallest angle round from where the player is pushing.
func _best_hookable(control: HookControl) -> HookableArea:
	var origin := control.global_position
	# Still the raw aim: the control re-points itself at the input every frame, before this runs.
	var aimed := control.global_rotation

	var in_arc: HookableArea = null
	var in_arc_distance := INF
	var closest_round: HookableArea = null
	var closest_round_angle := INF
	var kept: HookableArea = null

	for area: HookableArea in _reachable_hookables(control):
		var anchor := area.get_anchor_position()
		var off_aim := absf(angle_difference(aimed, origin.angle_to_point(anchor)))
		if off_aim <= snap_arc:
			var distance := origin.distance_to(anchor)
			if distance < in_arc_distance:
				in_arc = area
				in_arc_distance = distance
		if off_aim < closest_round_angle:
			closest_round = area
			closest_round_angle = off_aim
		if area == _snapped:
			kept = area

	if in_arc:
		return in_arc
	if kept:
		return kept
	return closest_round


## Every hookable [param control] could actually catch from where it is.
func _reachable_hookables(control: HookControl) -> Array[HookableArea]:
	var origin := control.global_position

	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _reach(control)
	query.shape = circle
	query.transform = Transform2D(0.0, origin)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1 << (Enums.CollisionLayers.HOOKABLE - 1)

	var reachable: Array[HookableArea] = []
	for hit: Dictionary in control.get_world_2d().direct_space_state.intersect_shape(query, 64):
		var area := hit.get("collider") as HookableArea
		if not area or area == control.hook_area or area in control.exclude_areas:
			continue
		# An area with several shapes comes back once per shape.
		if area in reachable:
			continue

		# Reach is not measured here: the circle query already found only what is within the
		# throw's reach, and it measures to the hookable's collision shape, which is the same
		# generously sized box the throw itself has to hit. Measuring to the anchor instead
		# would hold the snap short of places a thrown string can plainly get to, because the
		# anchor sits out past the near face of that box.
		if not _can_reach(control, area.get_anchor_position(), area):
			continue

		reachable.append(area)
	return reachable


## How far a throw from [param control] actually carries, in pixels.
##
## Not [member HookControl.string_length]. That property keeps the ray in step through its
## setter, so it is only true of a control something has assigned it to -- which [PlayerHook]
## does to its own and nothing does to the ones on the needles. Theirs report 200 while their
## ray is the 300 it was authored with. The ray is what the throw is actually cast along, so the
## ray is what the snap has to agree with.
func _reach(control: HookControl) -> float:
	return control.ray_cast_2d.target_position.length()


## Whether aiming at [param anchor] really would catch [param area].
##
## Cast exactly as the throw casts -- from the control, one string long, same mask, areas
## included -- rather than as far as the anchor. That way the answer is the throw's answer: it
## accounts for a wall in the path, for the anchor lying past the end of the string while the
## hookable's box is still within it, and for some nearer hookable being in the way.
func _can_reach(control: HookControl, anchor: Vector2, area: HookableArea) -> bool:
	var origin := control.global_position
	var aim := origin.angle_to_point(anchor)
	var reach := origin + Vector2(_reach(control), 0.0).rotated(aim)
	var ray := PhysicsRayQueryParameters2D.create(origin, reach)
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	ray.collision_mask = control.ray_cast_2d.collision_mask
	var hit := control.get_world_2d().direct_space_state.intersect_ray(ray)
	return hit.get("collider") == area


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not enabled:
		warnings.append("Switched off: the hook behaves as it does by default.")
	return warnings
