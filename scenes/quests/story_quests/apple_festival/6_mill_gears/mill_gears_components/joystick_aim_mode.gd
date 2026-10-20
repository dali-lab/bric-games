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
## • the aim snaps onto whichever hookable lies nearest in roughly that direction, so each of the
##   eight directions covers a whole sector of the mill rather than a single line.
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

## How far either side of the aimed direction a hookable may be and still be snapped onto.
##
## Eight directions are 45 degrees apart, so half of that covers the whole circle with no gaps:
## every hookable in reach lies in exactly one direction's sector. Widen it and the sectors
## overlap, which makes the nearer hookable win more often.
@export_range(0.0, 90.0, 0.5, "radians_as_degrees") var snap_arc: float = deg_to_rad(22.5)

## Hold the player still while they are aiming from a needle.
@export var hold_still: bool = true

## Snap the aim onto the nearest hookable in the aimed direction.
@export var snap_aim: bool = true

var _hook: PlayerHook
var _walk: InputWalkBehavior

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
	if not control:
		return

	var target := _best_hookable(control)
	if target:
		control.global_rotation = control.global_position.angle_to_point(
			target.get_anchor_position()
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


## The nearest hookable within [member snap_arc] of where [param control] is pointing, that the
## control could actually reach.
func _best_hookable(control: HookControl) -> HookableArea:
	var origin := control.global_position
	var aimed := control.global_rotation

	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = control.string_length
	query.shape = circle
	query.transform = Transform2D(0.0, origin)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1 << (Enums.CollisionLayers.HOOKABLE - 1)

	var best: HookableArea = null
	var best_distance := INF
	for hit: Dictionary in control.get_world_2d().direct_space_state.intersect_shape(query, 32):
		var area := hit.get("collider") as HookableArea
		if not area or area == control.hook_area or area in control.exclude_areas:
			continue

		var anchor := area.get_anchor_position()
		if absf(angle_difference(aimed, origin.angle_to_point(anchor))) > snap_arc:
			continue

		var distance := origin.distance_to(anchor)
		if distance >= best_distance or distance > control.string_length:
			continue
		if not _can_reach(control, anchor, area):
			continue

		best = area
		best_distance = distance
	return best


## Whether a throw at [param anchor] would actually land on [param area], rather than stopping at
## a wall on the way. Uses the throwing ray's own mask, so it agrees with what the throw will do.
func _can_reach(control: HookControl, anchor: Vector2, area: HookableArea) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(control.global_position, anchor)
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	ray.collision_mask = control.ray_cast_2d.collision_mask
	var hit := control.get_world_2d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.get("collider") == area


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not enabled:
		warnings.append("Switched off: the hook behaves as it does by default.")
	return warnings
