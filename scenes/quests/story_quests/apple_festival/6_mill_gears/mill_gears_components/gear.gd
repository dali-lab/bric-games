# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
## A gear the player can stand on, drawn from a body sprite and a tooth sprite.
##
## The walkable surface is described analytically instead of with collision shapes, so it
## keeps working while the gear spins and moves. [GearField] drives the gear and queries
## [method WalkableSurface.is_point_inside] and [method WalkableSurface.project_inside] to keep
## the player on top of it. See [WalkableRect] for somewhere to stand that does not spin.
##
## Two things size the teeth, and they are kept apart. [member module] sets how deep they are,
## which fixes the root, pitch and tip circles -- and so how far apart the gears have to be placed
## to mesh. [member tooth_spacing] sets how far apart they are round the rim, which fixes the
## tooth count. The drawn teeth are much broader than a textbook tooth of the same depth, so they
## have to be spread out further than [member module] alone would put them.
##
## The tooth count is not authored: it is derived from the pitch circle and [member
## tooth_spacing], so two gears sharing both settings always mesh.
##
## The body sprite is scaled to the root circle, so it shrinks with the gear. The tooth sprite is
## the same size on every gear, because teeth that mesh have to match.
##
## A gear with [member walkable] cleared is scenery: it still meshes and drives, it just cannot
## be stood on.
class_name Gear
extends WalkableSurface

## Smallest tooth count a gear may have, whatever its radius.
const MIN_TEETH: int = 3

## Smallest pitch circle a gear may have, counted in [member module]-sized steps. This is what
## the pitch circle has always been snapped to, and it is kept that way so that the circles, and
## with them every gear's placement in the level, are unchanged by how the teeth are spaced.
const MIN_PITCH_STEPS: int = 6

## How far a tooth root sits inside the pitch circle, as a multiple of [member module].
const DEDENDUM: float = 1.25

## How far a tooth tip sits outside the pitch circle, as a multiple of [member module].
const ADDENDUM: float = 1.0

## Share of [member tooth_spacing] a tooth takes up at the pitch circle. A little under half, so
## that a tooth's tip fits into the gap of the gear it meshes with, right down at the root.
const TOOTH_FILL: float = 0.42

## The [member module] the art was drawn for: at this module the tooth sprite is drawn at its
## natural depth.
const ART_MODULE: float = 16.0

## Width of the drawn tooth where it leaves the body, half way out, and at its tip, in sprite
## pixels. Measured off the art; they make the walkable area follow the drawn tooth.
const ART_TOOTH_ROOT_WIDTH: float = 70.0
const ART_TOOTH_PITCH_WIDTH: float = 60.0
const ART_TOOTH_TIP_WIDTH: float = 52.0

## The tooth is drawn leaning, pointing up and to the right. This stands it on the rim.
const ART_TOOTH_ROTATION: float = PI / 4.0

## How far in from the tip circle the middle of the tooth sprite sits, in sprite pixels. Its
## outline pokes a little past the tip circle, and its base is tucked under the body.
const ART_TOOTH_CENTRE_INSET: float = 28.0

## Outer radius of the body sprite, in sprite pixels: the body is scaled so this lands on the
## root circle.
const ART_BODY_RADIUS: float = 124.0

## Where the body sprite's middle sits from the gear's centre, in sprite pixels, so that its
## ring comes out round the centre rather than a pixel off.
const ART_BODY_OFFSET: Vector2 = Vector2(-1.0, -1.0)

## Radius of the hole in the middle of the body sprite, in sprite pixels. The hole is see-through
## and the player cannot stand in it: the walkable ring starts here.
##
## The hole measures 57 to 58 across its widest, and sits a pixel or two off the sprite's
## centre; this is just enough to cover it, so the ring begins on the hole's outline.
const ART_HOLE_RADIUS: float = 59.0

## Laid over a gear that cannot be stood on, as [member CanvasItem.modulate]. This is #586169.
const UNWALKABLE_TINT: Color = Color(0.36, 0.382, 0.48, 1.0)

## Phase error the mesh simply absorbs, as a fraction of a tooth.
##
## A tooth is narrower than the gap it sits in, so it does not have to be dead centre to be
## clear of its neighbours. Inside this nothing is visibly out of step and the gear is left
## alone.
const MESH_CLEARANCE: float = 0.04

## How fast a gear turns itself back into mesh, in radians per second.
##
## A gear running as the train says needs no correction at all, so this only shows when one has
## been let out of mesh and is being taken back in -- which is to say when a lever stops holding
## it. Half a tooth is the furthest it can ever be out, so even the slowest gear is back in step
## in a fraction of a second, without the jump that setting the angle outright would give.
const MESH_LOCK_SPEED: float = 0.4

## How far outside a tooth the player may still stand, as a multiple of [member module].
##
## Teeth are narrow, and the player is a sprite rather than the point the surface test treats them
## as, so walking out along one is unforgiving without a little slack. This widens the walkable
## area only: the drawn profile, and the mesh test that decides which gears drive which, both use
## the true geometry.
const WALKABLE_MARGIN: float = 0.3

## Requested pitch radius. The effective radius is snapped to a whole number of teeth, see
## [member pitch_radius].
@export_range(16.0, 512.0, 1.0, "or_greater") var radius: float = 96.0:
	set = _set_radius

## Tooth depth. Gears mesh only when they share a module, so [GearField] applies one value to
## every gear it owns.
@export_range(4.0, 64.0, 0.5, "or_greater") var module: float = 16.0:
	set = _set_module

## Distance from one tooth to the next, measured round the pitch circle, in pixels. Gears mesh
## only when they share it, so [GearField] applies one value to every gear it owns.
##
## The tooth sprite is narrowed to suit, never widened: at about 143 and above it is drawn at
## its natural width, and below that it is squeezed sideways to keep a gap between teeth.
@export_range(16.0, 256.0, 1.0, "or_greater") var tooth_spacing: float = 100.0:
	set = _set_tooth_spacing

## Whether the player may stand on this gear at all.
##
## Clearing it takes the gear out of the floor without taking it out of the machine: it still
## meshes, still drives whatever it touches, still turns and travels. Only [GearField]'s surface
## queries change their answer, and the gear is tinted [constant UNWALKABLE_TINT] so that it
## reads as something to grapple past rather than something to walk on.
@export var walkable: bool = true:
	set = _set_walkable

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

## One tooth, drawn as it would sit on a gear of [constant ART_MODULE]. It is repeated round the
## rim, under the body.
@export var tooth_texture: Texture2D:
	set = _set_tooth_texture

## The gear's body: a ring with a hole in the middle, scaled to the root circle.
@export var body_texture: Texture2D:
	set = _set_body_texture

## Laid over both sprites. White leaves the art as drawn.
@export var color: Color = Color.WHITE:
	set = _set_color

## Tooth count, derived from [member pitch_radius] and [member tooth_spacing].
var teeth: int = 12

## How much the tooth sprite is stretched along the tooth, out from the centre, to suit [member
## module].
var tooth_depth_scale: float = 1.0

## How much the tooth sprite is squeezed across the tooth, to suit [member tooth_spacing].
var tooth_width_scale: float = 1.0

## Effective pitch radius, snapped to a whole number of [member module]-sized steps.
var pitch_radius: float = 96.0

## Radius of the hole in the middle. Nothing inside this is walkable.
var hole_radius: float = 36.0

## Outer radius of the solid ring. Everything between this and [member hole_radius] is walkable.
var root_radius: float = 76.0

## Radius at the tooth tips. This is the true profile, and what the gear train measures.
var tip_radius: float = 112.0

## Slack around the teeth, in pixels. See [constant WALKABLE_MARGIN].
var walkable_margin: float = 4.0

## Radius at the tooth tips plus [member walkable_margin]. Outside this nothing is walkable.
var walkable_tip_radius: float = 116.0

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
	_apply_walkable_tint()
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


func _set_walkable(value: bool) -> void:
	walkable = value
	_apply_walkable_tint()


## Greys out a gear that cannot be stood on, so the floor reads apart from the scenery.
func _apply_walkable_tint() -> void:
	self_modulate = Color.WHITE if walkable else UNWALKABLE_TINT


func _set_tooth_spacing(value: float) -> void:
	tooth_spacing = value
	_rebuild()


func _set_tooth_texture(value: Texture2D) -> void:
	tooth_texture = value
	queue_redraw()


func _set_body_texture(value: Texture2D) -> void:
	body_texture = value
	queue_redraw()


func _set_color(value: Color) -> void:
	color = value
	queue_redraw()


## Recalculates the tooth count, the profile radii and the tooth sprite's scale.
func _rebuild() -> void:
	var safe_module := maxf(module, 0.001)
	var pitch_steps := maxi(MIN_PITCH_STEPS, roundi(2.0 * radius / safe_module))
	pitch_radius = float(pitch_steps) * safe_module / 2.0
	root_radius = maxf(pitch_radius - DEDENDUM * safe_module, 1.0)
	tip_radius = pitch_radius + ADDENDUM * safe_module
	# The body sprite is scaled to the root circle, so its hole scales with it.
	hole_radius = ART_HOLE_RADIUS * root_radius / ART_BODY_RADIUS
	walkable_margin = WALKABLE_MARGIN * safe_module
	walkable_tip_radius = tip_radius + walkable_margin

	var safe_spacing := maxf(tooth_spacing, 1.0)
	teeth = maxi(MIN_TEETH, roundi(TAU * pitch_radius / safe_spacing))
	tooth_depth_scale = safe_module / ART_MODULE
	tooth_width_scale = minf(
		TOOTH_FILL * safe_spacing / ART_TOOTH_PITCH_WIDTH, tooth_depth_scale
	)
	queue_redraw()
	update_configuration_warnings()


## Half-width, in radians, of a tooth at distance [param distance] from the centre. Follows the
## drawn tooth, which tapers towards its tip.
func _tooth_half_angle(distance: float) -> float:
	var t := clampf(inverse_lerp(root_radius, tip_radius, distance), 0.0, 1.0)
	var width := lerpf(ART_TOOTH_ROOT_WIDTH, ART_TOOTH_TIP_WIDTH, t) * tooth_width_scale
	return 0.5 * width / maxf(distance, 1.0)


## Half-width, in radians, of the walkable area around a tooth at distance [param distance].
##
## The tooth itself, widened by [member walkable_margin] on each flank. The margin is in pixels,
## so how many radians it buys shrinks the further out the player is -- which is what keeps the
## slack an even width all along the tooth rather than a wedge.
func _walkable_half_angle(distance: float) -> float:
	var profile := _tooth_half_angle(minf(distance, tip_radius))
	return profile + walkable_margin / maxf(distance, 1.0)


## Whether [param angle] (gear-local, radians) falls on a tooth at distance [param distance],
## within the walkable margin.
func _is_angle_on_tooth(angle: float, distance: float) -> bool:
	var period := TAU / float(teeth)
	var offset := wrapf(angle, -period * 0.5, period * 0.5)
	return absf(offset) <= _walkable_half_angle(distance)


## Whether the player may stand on [param global_point].
func is_point_inside(global_point: Vector2) -> bool:
	if not walkable:
		return false

	var local := to_local(global_point)
	var distance := local.length()
	if distance < hole_radius:
		return false
	if distance <= root_radius:
		return true
	if distance > walkable_tip_radius:
		return false
	return _is_angle_on_tooth(local.angle(), distance)


## Roughly how far [param global_point] is from the gear.
##
## Measured from the outer walkable circle, so it goes negative between the teeth. That is
## deliberate: a player in a tooth notch counts as nearer to this gear than to anything they are
## merely beside.
##
## Infinite for a gear that is not [member walkable], so the search for somewhere to stand
## passes over it however close the player is.
func distance_to_point(global_point: Vector2) -> float:
	if not walkable:
		return INF

	return global_position.distance_to(global_point) - walkable_tip_radius


## The closest walkable point to [param global_point], in global coordinates.
##
## This is a nearest-point clamp, not a radial one. Walking off the flank of a tooth keeps the
## player out on that flank instead of dumping them back onto the ring, and walking into the
## rim preserves their tangential motion so they slide along it.
##
## Stepping into the hole in the middle pushes the player straight back out to its edge, which
## is the nearest walkable point and likewise lets them slide round it.
func project_inside(global_point: Vector2) -> Vector2:
	var local := to_local(global_point)
	var distance := local.length()
	if distance < hole_radius:
		# Dead centre has no direction of its own; any way out is as near as any other.
		var out := local.angle() if distance > 0.001 else 0.0
		return _polar_to_global(hole_radius + SURFACE_EPSILON, out)
	if distance <= root_radius:
		return global_point

	var angle := local.angle()
	var reach := minf(distance, walkable_tip_radius)
	var period := TAU / float(teeth)
	var offset := wrapf(angle, -period * 0.5, period * 0.5)
	var tooth_centre := angle - offset
	var half_width := _walkable_half_angle(reach)

	# Still lined up with a tooth, so the only thing out of bounds is how far out they are.
	if absf(offset) <= half_width:
		if distance <= walkable_tip_radius:
			return global_point
		return _polar_to_global(reach - SURFACE_EPSILON, angle)

	# Off the side of a tooth, or in the notch between two. Take whichever is genuinely closer:
	# dropping down onto the ring, or staying out on the flank of the nearest tooth.
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
## Each tooth that passes one gear's contact point pushes one tooth of the other past it, so the
## gear with fewer teeth turns faster, in proportion to the tooth counts. That is what keeps the
## pair in mesh: the pitch circles are snapped independently of the teeth, so going by their
## radii instead would let the teeth creep out of step. The sign flips: teeth pushing teeth turn
## the neighbour the other way.
func driven_velocity_for(other: Gear) -> float:
	return -angular_velocity * float(teeth) / float(maxi(other.teeth, 1))


## Whether this gear should be held in mesh with whatever is driving it.
##
## A lever that brakes or reverses a driven gear is asking for something no gear train can
## actually do, and the mesh is what gives: while [member spin_multiplier] is anything but 1 the
## gear turns as the lever says and its teeth are allowed to pass through its driver's.
func can_mesh_lock() -> bool:
	return driven and is_equal_approx(spin_multiplier, 1.0)


## The rotation this gear wants so that its teeth sit in [param driver]'s gaps.
##
## Easiest counted in teeth rather than radians: measure each gear's tooth phase from the line
## joining the two centres, and those phases have to add up to half a tooth for one gear's teeth
## to land in the other's spaces. Rolling the pair leaves that sum alone -- meshed gears turn
## opposite ways in the ratio of their tooth counts, which is exactly what [method
## driven_velocity_for] hands out -- so a pair that starts in mesh stays in mesh on its own. What
## does break it is the centres moving, which the gears that orbit or ride a path do constantly.
##
## There is one answer per tooth, and this is whichever is nearest where the gear already is, so
## nothing is ever asked to travel more than half a tooth. [method lock_mesh_with] is what sees
## to it that the trip is never taken backwards.
func mesh_phase_for(driver: Gear) -> float:
	var axis := (global_position - driver.global_position).angle()
	var driver_phase := float(driver.teeth) * (driver.global_rotation - axis) / TAU
	var pitch := TAU / float(teeth)
	var ideal := axis + PI + (0.5 - driver_phase) * pitch
	return ideal + pitch * roundf((global_rotation - ideal) / pitch)


## Eases the gear into mesh with [param driver] over [param delta] seconds.
##
## The correction is always toward the nearest tooth and stops at the near edge of [constant
## MESH_CLEARANCE], so the gear is never turned further than it takes to stop the teeth
## touching.
##
## Which means it is sometimes asked to give rotation back, and a running gear cannot do that by
## reversing. So it is taken out of this frame's travel instead: the gear eases off, at most
## stands still for a frame, and lets its driver come to it. Slower to settle than spinning on
## to the next tooth would be, but it never runs backwards and never overshoots.
func lock_mesh_with(driver: Gear, delta: float) -> void:
	var error := wrapf(mesh_phase_for(driver) - global_rotation, -PI, PI)
	var slack := MESH_CLEARANCE * TAU / float(teeth)
	if absf(error) <= slack:
		return

	var wanted := error - signf(error) * slack
	var step := clampf(wanted, -MESH_LOCK_SPEED * delta, MESH_LOCK_SPEED * delta)

	# What [method advance] already turned the gear this frame. Giving back more than that would
	# have it running the wrong way.
	var travelled := angular_velocity * delta
	if not is_zero_approx(travelled) and signf(travelled + step) != signf(travelled):
		step = -travelled

	global_rotation += step


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
			_path_progress = clampf(_path_progress + path_speed * motion_delta, 0.0, length)
			global_position = motion_path.to_global(motion_path.curve.sample_baked(_path_progress))
	elif not is_zero_approx(orbit_period) and not is_zero_approx(_orbit_radius):
		_orbit_time = fposmod(_orbit_time + motion_delta, orbit_period)
		var angle := _orbit_angle + TAU * _orbit_time / orbit_period
		position = orbit_centre + Vector2.from_angle(angle) * _orbit_radius


func _draw() -> void:
	# Teeth first, so the body covers their bases.
	if tooth_texture:
		var period := TAU / float(teeth)
		var centre_distance := tip_radius - ART_TOOTH_CENTRE_INSET * tooth_depth_scale
		# Stand the drawn tooth on the rim, then squeeze it to size: depth along x, width along y.
		var shape := (
			Transform2D(
				Vector2(tooth_depth_scale, 0.0), Vector2(0.0, tooth_width_scale), Vector2.ZERO
			)
			* Transform2D(ART_TOOTH_ROTATION, Vector2.ZERO)
		)
		var offset := -tooth_texture.get_size() / 2.0
		for i in teeth:
			var angle := period * float(i)
			draw_set_transform_matrix(
				Transform2D(angle, Vector2.from_angle(angle) * centre_distance) * shape
			)
			draw_texture(tooth_texture, offset, color)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	var body_scale := root_radius / ART_BODY_RADIUS
	if not body_texture:
		draw_circle(Vector2.ZERO, root_radius, color)
		return

	draw_set_transform(ART_BODY_OFFSET * body_scale, 0.0, Vector2.ONE * body_scale)
	draw_texture(body_texture, -body_texture.get_size() / 2.0, color)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if module <= 0.0:
		warnings.append("Module must be greater than zero.")
	elif radius < float(MIN_PITCH_STEPS) * module / 2.0:
		warnings.append(
			(
				"Pitch circle is clamped to %d steps: lower the module, or raise the radius."
				% MIN_PITCH_STEPS
			)
		)
	if tooth_spacing > 0.0 and TAU * pitch_radius / tooth_spacing < float(MIN_TEETH) - 0.5:
		warnings.append(
			(
				"Tooth count is clamped to %d: lower the tooth spacing, or raise the radius."
				% MIN_TEETH
			)
		)
	if not tooth_texture or not body_texture:
		warnings.append("Set both the tooth and body textures.")
	return warnings
