# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
## Drives every [WalkableSurface] in the scene and keeps the player standing on them.
##
## The mill floor is the union of moving, rotating gears and whatever fixed ledges join them up,
## so its complement -- the void -- changes every frame and cannot be authored as collision
## geometry. Instead this node constrains the player analytically: after the player has moved, it
## carries them with whichever surface they are on and projects them back onto it if they left.
##
## [Gear] and [WalkableRect] are both surfaces and are treated alike here; the gear train in
## [method _resolve_drive] is the one part that only concerns the gears.
##
## It stands down whenever the player is not [constant Player.Mode.USER_CONTROLLED], which is
## what [PlayerHook] sets while it pulls the player across a gap, and re-acquires the nearest
## gear once control returns.
class_name GearField
extends Node

## Runs after the player's own [code]_physics_process[/code], so the carry and the clamp are
## applied to a position the player has already moved to this frame.
const PHYSICS_PRIORITY: int = 10

## Node holding the walkable surfaces. Defaults to this node's own children.
@export var surfaces_root: Node2D:
	set = _set_surfaces_root

## Tooth size applied to every gear. Gears mesh only when they share a module. Surfaces that are
## not gears ignore it.
@export_range(4.0, 64.0, 0.5, "or_greater") var module: float = 16.0:
	set = _set_module

var _surfaces: Array[WalkableSurface] = []

## The gears among [member _surfaces], kept apart because the gear train only involves them.
var _gears: Array[Gear] = []

## Every driven gear paired with whatever is driving it, in the order [method _resolve_drive]
## reached them. Walking it in order means a gear's driver has already been put into mesh by the
## time the gear itself is.
var _driven_gears: Array[Gear] = []
var _driving_gears: Array[Gear] = []

var _player: Player
var _current_index: int = -1
var _needs_reacquire: bool = true


func _ready() -> void:
	_collect_surfaces()
	_apply_module()
	if Engine.is_editor_hint():
		return

	process_physics_priority = PHYSICS_PRIORITY
	_player = get_tree().get_first_node_in_group(&"player") as Player


func _set_surfaces_root(value: Node2D) -> void:
	surfaces_root = value
	_collect_surfaces()
	_apply_module()


func _set_module(value: float) -> void:
	module = value
	_apply_module()


func _collect_surfaces() -> void:
	_surfaces.clear()
	_gears.clear()
	var root: Node = surfaces_root if surfaces_root else self
	if not is_instance_valid(root):
		return
	for child in root.find_children("*", "WalkableSurface", true, false):
		var surface := child as WalkableSurface
		_surfaces.append(surface)
		if surface is Gear:
			_gears.append(surface as Gear)


func _apply_module() -> void:
	for gear in _gears:
		gear.module = module


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_resolve_drive()

	# Remember where each surface was, then move it, so the carry below can replay the exact
	# rigid motion the surface just underwent.
	var previous: Array[Transform2D] = []
	previous.resize(_surfaces.size())
	for i in _surfaces.size():
		previous[i] = _surfaces[i].global_transform
		_surfaces[i].advance(delta)

	_apply_mesh_phases(delta)

	if not is_instance_valid(_player) or _player.mode == Player.Mode.DEFEATED:
		return

	# The hook (or a dialogue) owns the player: do not fight it.
	if _player.mode != Player.Mode.USER_CONTROLLED:
		_needs_reacquire = true
		return

	if _needs_reacquire or _current_index < 0:
		_reacquire()
		return

	_prefer_still_surface()
	_carry(previous[_current_index])
	_constrain()


## Works out how fast every [member Gear.driven] gear is turning this frame.
##
## Driven gears have no power of their own, so the speed has to be handed down from the motors:
## each motor turns whatever it meshes with, which turns whatever that meshes with, and so on.
## This is a breadth-first walk of that train, starting from the motors.
##
## Done from scratch every frame, because gears that orbit or ride a path mesh and unmesh as they
## travel. A driven gear nothing reaches stops dead rather than coasting: it is being pushed, and
## nothing is pushing it.
##
## A driven gear reached by two motors at once takes the first one the walk arrives at rather
## than jamming, which keeps a contradictory layout playable.
func _resolve_drive() -> void:
	# Seed the walk with the motors. Driven gears start at a standstill and are overwritten below
	# if the train reaches them.
	var frontier: Array[Gear] = []
	for gear in _gears:
		gear.angular_velocity = gear.get_motor_velocity()
		if not gear.driven:
			frontier.append(gear)

	_driven_gears.clear()
	_driving_gears.clear()

	var pending := _gears.filter(func(gear: Gear) -> bool: return gear.driven)

	while not frontier.is_empty() and not pending.is_empty():
		var next_frontier: Array[Gear] = []
		for driver: Gear in frontier:
			var still_pending: Array[Gear] = []
			for follower: Gear in pending:
				if not driver.is_meshing_with(follower):
					still_pending.append(follower)
					continue
				# Scaling by the follower's own multiplier here, rather than where it is used,
				# is what lets a lever brake or reverse a driven gear and have everything
				# further down the train feel it too.
				follower.angular_velocity = (
					driver.driven_velocity_for(follower) * follower.spin_multiplier
				)
				_driven_gears.append(follower)
				_driving_gears.append(driver)
				next_frontier.append(follower)
			pending = still_pending
		frontier = next_frontier


## Puts every driven gear back into mesh with the gear driving it, so that teeth land in gaps
## instead of through each other.
##
## Done after the whole field has moved, because a gear that orbits or rides a path changes the
## line between its centre and its driver's as it travels, and that line is what the phase is
## measured from. In [method _resolve_drive] order, so each gear is put in phase against a driver
## that is already in phase itself.
##
## Gears that run as the train says need almost no correction: the drive ratio keeps a meshed
## pair in mesh by itself. See [method Gear.mesh_phase_for].
func _apply_mesh_phases(delta: float) -> void:
	for i in _driven_gears.size():
		var gear := _driven_gears[i]
		if gear.can_mesh_lock():
			gear.lock_mesh_with(_driving_gears[i], delta)


## Applies the current surface's rigid motion to the player. This covers spin and travel at
## once, and only moves the player -- a top-down character must not rotate with the gear.
func _carry(previous_transform: Transform2D) -> void:
	var surface := _surfaces[_current_index]
	var target: Vector2 = (
		surface.global_transform * (previous_transform.affine_inverse() * _player.global_position)
	)
	var motion := target - _player.global_position
	if not motion.is_zero_approx():
		# move_and_collide rather than assigning the position, so walls and props stay solid.
		_player.move_and_collide(motion)


## Moves the player onto a surface that does not turn, when one of them is holding them up.
##
## Ledges overlap the gears they join onto, deliberately -- two surfaces that only just touch
## leave a seam the player can be clamped out of. Preferring whichever surface the player was
## already on is what stops the choice flapping, but it also means stepping off a gear onto a
## ledge leaves them indexed on the gear, still being swung around by it while they stand on
## something that is plainly bolted down. A still surface wins that tie.
##
## Called before [method _carry], so the gear does not get to move them one last time.
func _prefer_still_surface() -> void:
	if not _surfaces[_current_index] is Gear:
		return

	for i in _surfaces.size():
		if _surfaces[i] is Gear:
			continue
		if _surfaces[i].is_point_inside(_player.global_position):
			_current_index = i
			return


## Keeps the player on a surface, preferring the one they are already on so that overlapping
## teeth, or a ledge laid over a gear, do not make the choice flap between the two.
func _constrain() -> void:
	var surface := _surfaces[_current_index]
	if surface.is_point_inside(_player.global_position):
		return

	for i in _surfaces.size():
		if i != _current_index and _surfaces[i].is_point_inside(_player.global_position):
			_current_index = i
			return

	_player.global_position = surface.project_inside(_player.global_position)


## Puts the player back on the nearest surface. Used on spawn, and after the hook releases them
## -- possibly over open void.
func _reacquire() -> void:
	_needs_reacquire = false
	_current_index = _nearest_surface_index(_player.global_position)
	if _current_index < 0:
		return

	var surface := _surfaces[_current_index]
	if not surface.is_point_inside(_player.global_position):
		_player.global_position = surface.project_inside(_player.global_position)


func _nearest_surface_index(point: Vector2) -> int:
	var best := -1
	var best_distance := INF
	var on_gear := -1
	for i in _surfaces.size():
		var surface := _surfaces[i]
		if surface.is_point_inside(point):
			# Same tie-break as _prefer_still_surface: a ledge beats the gear beneath it.
			if not surface is Gear:
				return i
			if on_gear < 0:
				on_gear = i
			continue
		var distance := surface.distance_to_point(point)
		if distance < best_distance:
			best_distance = distance
			best = i
	return on_gear if on_gear >= 0 else best


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	_collect_surfaces()
	if _surfaces.is_empty():
		warnings.append(
			"No Gear or WalkableRect nodes found. Set Surfaces Root, or add them as children."
		)
	return warnings
