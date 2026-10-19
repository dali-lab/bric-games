# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
## Changes what a set of [Gear]s do when a lever is switched.
##
## This is the [Toggleable] half of the mill puzzle: put one in the scene, list the gears it
## affects, pick what happens to their spin and to their travel, and point a lever's
## [code]targets[/code] at it. Switching the lever on applies the effects; switching it off puts
## the gears back to the speeds they were authored with.
##
## One node covers one group of gears doing one thing, so a lever that reverses two gears and
## stops a third is two of these, both listed as targets of the same lever.
class_name GearToggle
extends Toggleable

## What happens to one channel -- the spin, or the travel -- while this is toggled on.
enum Effect {
	UNCHANGED,  ## Leave it alone.
	STOPPED,  ## Hold it still.
	REVERSED,  ## Run it backwards.
}

## The gears this affects. Gears left out of the list keep running as authored.
@export var gears: Array[Gear] = []:
	set = _set_gears

## What happens to [member Gear.angular_speed], the spin around the gear's own centre.
@export var spin_effect: Effect = Effect.REVERSED

## What happens to the gear's travel: along [member Gear.motion_path] if it has one, around
## [member Gear.orbit_centre] otherwise.
@export var motion_effect: Effect = Effect.UNCHANGED

## How long the gears take to settle into the new speeds. A reversal eases through a standstill
## instead of snapping, which matters because the player is standing on them. Zero changes the
## speeds immediately.
@export_range(0.0, 5.0, 0.1, "suffix:s") var transition_duration: float = 0.5

var _tween: Tween


func _set_gears(value: Array[Gear]) -> void:
	gears = value
	update_configuration_warnings()


## The multiplier [param effect] asks for while toggled on.
static func _multiplier_for(effect: Effect) -> float:
	match effect:
		Effect.STOPPED:
			return 0.0
		Effect.REVERSED:
			return -1.0
		_:
			return 1.0


func set_toggled(value: bool, immediate: bool = false) -> void:
	if _tween:
		_tween.kill()
		_tween = null

	# A channel left Unchanged is never touched, not even to put it back to 1: another toggle may
	# own it. Toggled off is always the authored behaviour, whatever the effects are.
	var targets: Dictionary[StringName, float] = {}
	if spin_effect != Effect.UNCHANGED:
		targets[&"spin_multiplier"] = _multiplier_for(spin_effect) if value else 1.0
	if motion_effect != Effect.UNCHANGED:
		targets[&"motion_multiplier"] = _multiplier_for(motion_effect) if value else 1.0

	var valid_gears := gears.filter(func(gear: Gear) -> bool: return is_instance_valid(gear))
	if targets.is_empty() or valid_gears.is_empty():
		return

	if immediate or transition_duration <= 0.0 or Engine.is_editor_hint():
		for gear: Gear in valid_gears:
			for property: StringName in targets:
				gear.set(property, targets[property])
		return

	_tween = create_tween().set_parallel()
	for gear: Gear in valid_gears:
		for property: StringName in targets:
			_tween.tween_property(gear, NodePath(property), targets[property], transition_duration)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if gears.is_empty():
		warnings.append("No gears listed: this toggle will not do anything.")
	if spin_effect == Effect.UNCHANGED and motion_effect == Effect.UNCHANGED:
		warnings.append("Both effects are Unchanged: this toggle will not do anything.")
	return warnings
