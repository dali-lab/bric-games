# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
## A procedurally generated gear the player can stand on.
##
## The walkable surface is described analytically instead of with collision shapes, so it
## keeps working while the gear spins and moves. [GearField] drives the gear and queries
## [method is_point_inside] and [method project_inside] to keep the player on top of it.
##
## The tooth count is not authored: it is derived from [member radius] and [member module],
## so two gears sharing a module always mesh.
class_name Gear
extends Node2D

## Smallest tooth count a gear may have, whatever its radius.
const MIN_TEETH: int = 6

## Tooth angular half-width at the root circle, as a fraction of [code]PI / teeth[/code].
const TOOTH_HALF_ANGLE_AT_ROOT: float = 0.5

## Tooth angular half-width at the tip circle, as a fraction of [code]PI / teeth[/code].
const TOOTH_HALF_ANGLE_AT_TIP: float = 0.25

## How far a tooth root sits inside the pitch circle, as a multiple of [member module].
const DEDENDUM: float = 1.25

## How far a tooth tip sits outside the pitch circle, as a multiple of [member module].
const ADDENDUM: float = 1.0

## Size of the drawn hub, as a fraction of the root radius.
const HUB_RATIO: float = 0.28

## How far inside the surface [method project_inside] lands the player, in pixels. Without it,
## rounding can leave the projected point a hair outside and it gets re-projected every frame.
const SURFACE_EPSILON: float = 0.5

## Requested pitch radius. The effective radius is snapped to a whole number of teeth, see
## [member pitch_radius].
@export_range(16.0, 512.0, 1.0, "or_greater") var radius: float = 96.0:
	set = _set_radius

## Tooth size. Gears mesh only when they share a module, so [GearField] applies one value to
## every gear it owns.
@export_range(4.0, 64.0, 0.5, "or_greater") var module: float = 16.0:
	set = _set_module

## Rotation speed in radians per second. Negative turns the other way, zero stands still.
@export var angular_speed: float = 0.0

@export_group("Motion")

## When set, the gear rides this curve instead of orbiting. Needs a non-zero [member path_speed].
@export var motion_path: Path2D

## Speed along [member motion_path], in pixels per second.
@export var path_speed: float = 0.0

## Point to orbit, in the parent's coordinates. The orbit radius and starting phase are taken
## from wherever the gear is placed, so it always passes through its authored position.
@export var orbit_centre: Vector2 = Vector2.ZERO

## Seconds per orbit around [member orbit_centre]. Zero means the gear does not orbit.
@export var orbit_period: float = 0.0

@export_group("Appearance")

@export var color: Color = Color(0.36, 0.38, 0.45):
	set = _set_color

@export var hub_color: Color = Color(0.2, 0.22, 0.28):
	set = _set_hub_color

## Tooth count, derived from [member radius] and [member module].
var teeth: int = 12

## Effective pitch radius, snapped to a whole number of teeth.
var pitch_radius: float = 96.0

## Radius of the solid disc. Everything inside this is walkable.
var root_radius: float = 76.0

## Radius at the tooth tips. Outside this nothing is walkable.
var tip_radius: float = 112.0

var _orbit_radius: float = 0.0
var _orbit_angle: float = 0.0
var _orbit_time: float = 0.0
var _path_progress: float = 0.0


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return

	var offset := position - orbit_centre
	_orbit_radius = offset.length()
	_orbit_angle = offset.angle()
	if motion_path and motion_path.curve:
		_path_progress = motion_path.curve.get_closest_offset(motion_path.to_local(global_position))


func _set_radius(value: float) -> void:
	radius = value
	_rebuild()


func _set_module(value: float) -> void:
	module = value
	_rebuild()


func _set_color(value: Color) -> void:
	color = value
	queue_redraw()


func _set_hub_color(value: Color) -> void:
	hub_color = value
	queue_redraw()


## Recalculates the tooth count and the three profile radii.
func _rebuild() -> void:
	var safe_module := maxf(module, 0.001)
	teeth = maxi(MIN_TEETH, roundi(2.0 * radius / safe_module))
	pitch_radius = float(teeth) * safe_module / 2.0
	root_radius = maxf(pitch_radius - DEDENDUM * safe_module, 1.0)
	tip_radius = pitch_radius + ADDENDUM * safe_module
	queue_redraw()
	update_configuration_warnings()


## Half-width, in radians, of a tooth at distance [param distance] from the centre. Teeth taper
## towards their tips.
func _tooth_half_angle(distance: float) -> float:
	var t := clampf(inverse_lerp(root_radius, tip_radius, distance), 0.0, 1.0)
	var factor := lerpf(TOOTH_HALF_ANGLE_AT_ROOT, TOOTH_HALF_ANGLE_AT_TIP, t)
	return factor * PI / float(teeth)


## Whether [param angle] (gear-local, radians) falls on a tooth at distance [param distance].
func _is_angle_on_tooth(angle: float, distance: float) -> bool:
	var period := TAU / float(teeth)
	var offset := wrapf(angle, -period * 0.5, period * 0.5)
	return absf(offset) <= _tooth_half_angle(distance)


## Whether the player may stand on [param global_point].
func is_point_inside(global_point: Vector2) -> bool:
	var local := to_local(global_point)
	var distance := local.length()
	if distance <= root_radius:
		return true
	if distance > tip_radius:
		return false
	return _is_angle_on_tooth(local.angle(), distance)


## The closest walkable point to [param global_point], in global coordinates.
##
## The clamp is radial, so a player walking into the rim keeps their tangential motion and
## slides along it rather than sticking.
func project_inside(global_point: Vector2) -> Vector2:
	var local := to_local(global_point)
	var distance := local.length()
	if distance <= root_radius:
		return global_point

	var angle := local.angle()
	if distance <= tip_radius and _is_angle_on_tooth(angle, distance):
		return global_point

	var target_radius := root_radius
	if distance > tip_radius and _is_angle_on_tooth(angle, tip_radius):
		target_radius = tip_radius
	target_radius = maxf(target_radius - SURFACE_EPSILON, 0.0)
	return to_global(Vector2.from_angle(angle) * target_radius)


## Advances the gear's spin and motion by [param delta] seconds. Called by [GearField].
func advance(delta: float) -> void:
	rotation += angular_speed * delta

	if motion_path and motion_path.curve and not is_zero_approx(path_speed):
		var length := motion_path.curve.get_baked_length()
		if length > 0.0:
			_path_progress = fposmod(_path_progress + path_speed * delta, length)
			global_position = motion_path.to_global(motion_path.curve.sample_baked(_path_progress))
	elif not is_zero_approx(orbit_period) and not is_zero_approx(_orbit_radius):
		_orbit_time = fposmod(_orbit_time + delta, orbit_period)
		var angle := _orbit_angle + TAU * _orbit_time / orbit_period
		position = orbit_centre + Vector2.from_angle(angle) * _orbit_radius


func _draw() -> void:
	draw_circle(Vector2.ZERO, root_radius, color)

	var period := TAU / float(teeth)
	var root_half := _tooth_half_angle(root_radius)
	var tip_half := _tooth_half_angle(tip_radius)
	for i in teeth:
		var centre := period * float(i)
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2.from_angle(centre - root_half) * root_radius,
					Vector2.from_angle(centre - tip_half) * tip_radius,
					Vector2.from_angle(centre + tip_half) * tip_radius,
					Vector2.from_angle(centre + root_half) * root_radius,
				]
			),
			color
		)

	draw_circle(Vector2.ZERO, root_radius * HUB_RATIO, hub_color)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if module <= 0.0:
		warnings.append("Module must be greater than zero.")
	elif radius < float(MIN_TEETH) * module / 2.0:
		warnings.append(
			"Tooth count is clamped to %d: lower the module, or raise the radius." % MIN_TEETH
		)
	return warnings
