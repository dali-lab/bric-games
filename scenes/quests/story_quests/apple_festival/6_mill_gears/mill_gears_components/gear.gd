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

## When set, the gear has no power of its own: it only turns while another gear's teeth are
## pushing its own, at whatever speed and direction that gear imposes. See [member
## angular_velocity]. [member angular_speed] is ignored.
@export var driven: bool = false:
	set = _set_driven

## Rotation speed in radians per second, under the gear's own power. Negative turns the other
## way, zero stands still. Ignored while [member driven] is set.
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

## The spin applied on the last [method advance], in radians per second. For a motor this is
## just [member angular_speed] scaled by [member spin_multiplier]; for a [member driven] gear it
## is whatever the gear train works out to, and [GearField] is what sets it.
var angular_velocity: float = 0.0

## Scales the spin at runtime: 1 turns as authored, -1 turns the other way, 0 holds still. On a
## [member driven] gear it scales the spin the train hands it, so 0 is a brake and -1 a reverser,
## and the gears it drives in turn feel the difference. [GearToggle] drives this from a lever.
var spin_multiplier: float = 1.0

## Scales the gear's travel along [member motion_path], or around [member orbit_centre], the same
## way [member spin_multiplier] scales the spin.
var motion_multiplier: float = 1.0

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


func _set_driven(value: bool) -> void:
	driven = value
	notify_property_list_changed()


## Greys out [member angular_speed] on a gear that cannot use it.
func _validate_property(property: Dictionary) -> void:
	if property.name == "angular_speed" and driven:
		property.usage |= PROPERTY_USAGE_READ_ONLY


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
## This is a nearest-point clamp, not a radial one. Walking off the flank of a tooth keeps the
## player out on that flank instead of dumping them back onto the disc, and walking into the
## rim preserves their tangential motion so they slide along it.
func project_inside(global_point: Vector2) -> Vector2:
	var local := to_local(global_point)
	var distance := local.length()
	if distance <= root_radius:
		return global_point

	var angle := local.angle()
	var reach := minf(distance, tip_radius)
	var period := TAU / float(teeth)
	var offset := wrapf(angle, -period * 0.5, period * 0.5)
	var tooth_centre := angle - offset
	var half_width := _tooth_half_angle(reach)

	# Still lined up with a tooth, so the only thing out of bounds is how far out they are.
	if absf(offset) <= half_width:
		if distance <= tip_radius:
			return global_point
		return _polar_to_global(reach - SURFACE_EPSILON, angle)

	# Off the side of a tooth, or in the notch between two. Take whichever is genuinely closer:
	# dropping down onto the disc, or staying out on the flank of the nearest tooth.
	var flank_angle := tooth_centre + signf(offset) * half_width
	var to_disc := distance - root_radius
	var to_flank := (
		(Vector2.from_angle(angle) * distance - Vector2.from_angle(flank_angle) * reach).length()
	)
	if to_disc <= to_flank:
		return _polar_to_global(root_radius - SURFACE_EPSILON, angle)

	# Nudge off the flank by the same epsilon, converted from pixels to radians at this radius.
	var inset := SURFACE_EPSILON / maxf(reach, 1.0)
	return _polar_to_global(
		reach - SURFACE_EPSILON, tooth_centre + signf(offset) * maxf(half_width - inset, 0.0)
	)


func _polar_to_global(distance: float, angle: float) -> Vector2:
	return to_global(Vector2.from_angle(angle) * distance)


## Spin this gear produces on its own, before any gear train is taken into account. A [member
## driven] gear produces none.
func get_motor_velocity() -> float:
	return 0.0 if driven else angular_speed * spin_multiplier


## Whether this gear's teeth reach [param other]'s, so that one can push the other.
##
## The test is deliberately slack -- any overlap of the two tooth rings counts, not just the
## textbook centre distance of one pitch radius plus the other -- because the gears are placed
## by hand and some of them drift in and out of contact as they travel.
func is_meshing_with(other: Gear) -> bool:
	var distance := global_position.distance_to(other.global_position)
	return distance < tip_radius + other.tip_radius


## The spin [param other] ends up with while this gear drives it.
##
## Meshed gears travel at the same speed where their teeth touch, so the smaller one turns
## faster, in proportion to the pitch radii. The sign flips: teeth pushing teeth turn the
## neighbour the other way.
func driven_velocity_for(other: Gear) -> float:
	return -angular_velocity * pitch_radius / maxf(other.pitch_radius, 0.001)


## Advances the gear's spin and motion by [param delta] seconds. Called by [GearField].
##
## A [member driven] gear expects its [member angular_velocity] to have been resolved already,
## which is why it is [GearField] that calls this.
func advance(delta: float) -> void:
	if not driven:
		angular_velocity = get_motor_velocity()
	rotation += angular_velocity * delta

	# Scale the time step rather than the speeds, so one factor covers both kinds of travel even
	# though they are expressed differently: pixels per second along a path, seconds per orbit.
	var motion_delta := delta * motion_multiplier

	if motion_path and motion_path.curve and not is_zero_approx(path_speed):
		var length := motion_path.curve.get_baked_length()
		if length > 0.0:
			_path_progress = fposmod(_path_progress + path_speed * motion_delta, length)
			global_position = motion_path.to_global(motion_path.curve.sample_baked(_path_progress))
	elif not is_zero_approx(orbit_period) and not is_zero_approx(_orbit_radius):
		_orbit_time = fposmod(_orbit_time + motion_delta, orbit_period)
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
