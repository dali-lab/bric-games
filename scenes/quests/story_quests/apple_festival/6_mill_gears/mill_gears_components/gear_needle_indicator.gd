# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
## Holds a hookable's aiming indicator upright, directly above the hookable.
##
## [HookableArea] hangs its indicator -- the arrow that bobs over whatever the player is pointing
## at -- off an [member HookableArea.indicator_point] of its own making, placed a little above the
## anchor and then left alone. That is fine for a hookable standing straight up. The needles in
## the mill are planted at angles, and some are bolted to gears that turn under them, so an
## indicator that simply hangs where it was put ends up leaning over, or off to one side of the
## needle it is supposed to be labelling.
##
## Set this as the area's [member HookableArea.indicator_point] instead. It keeps itself at a
## fixed distance straight above the anchor and square to the screen, whatever the needle is
## doing, so the arrow always points down at its own needle from above. The needle itself still
## leans as it was placed -- only the indicator is held level.
class_name GearNeedleIndicator
extends Marker2D

## How far above the anchor the arrow sits, in screen pixels. Matches what [HookableArea] uses
## when it makes an indicator point of its own.
@export var offset: Vector2 = Vector2(0, -32)

## The area whose anchor this hangs over. Defaults to the parent.
@export var hookable_area: HookableArea


func _enter_tree() -> void:
	if not hookable_area and get_parent() is HookableArea:
		hookable_area = get_parent()


func _ready() -> void:
	if is_instance_valid(hookable_area):
		hookable_area.observers_changed.connect(_on_observers_changed)
	_on_observers_changed()


## The arrow is only drawn while something is pointing at the area, so that is the only time
## this is worth keeping level.
func _on_observers_changed() -> void:
	set_process(Engine.is_editor_hint() or _is_observed())
	_stay_level()


func _is_observed() -> bool:
	return is_instance_valid(hookable_area) and hookable_area.is_being_observed


func _process(_delta: float) -> void:
	_stay_level()


func _stay_level() -> void:
	if not is_instance_valid(hookable_area):
		return
	global_position = hookable_area.get_anchor_position() + offset
	global_rotation = 0.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not hookable_area:
		warnings.append("Hookable Area must be set, or this must be a child of one.")
	elif hookable_area.indicator_point != self:
		warnings.append("Set the HookableArea's Indicator Point to this node.")
	return warnings
