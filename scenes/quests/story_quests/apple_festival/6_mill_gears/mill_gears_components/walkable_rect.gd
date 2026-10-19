# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
## A plain rectangular ledge the player can stand on.
##
## The counterpart to [Gear]: somewhere to stand that does not spin. Use it for landings between
## gears, or a porch to set off from. It is a [WalkableSurface] like the gears are, so it has to
## be found by the same [GearField], and the player walks between the two without noticing the
## difference.
##
## Overlap it with whatever it joins onto. Two surfaces that only just touch leave a seam the
## player can be clamped out of.
##
## Rotating the node rotates the ledge. Scaling works too, but prefer [member size].
class_name WalkableRect
extends WalkableSurface

## Size of the ledge in pixels, centred on the node's own position.
@export var size: Vector2 = Vector2(256.0, 128.0):
	set = _set_size

@export_group("Appearance")

@export var color: Color = Color(0.3, 0.32, 0.38):
	set = _set_color

## Drawn as an inset band around the edge, so the ledge reads as a solid slab rather than a flat
## patch of colour. Set its alpha to zero for no edge at all.
@export var edge_color: Color = Color(0.2, 0.22, 0.28):
	set = _set_edge_color

## Thickness of the drawn edge, in pixels.
@export_range(0.0, 32.0, 1.0) var edge_width: float = 6.0:
	set = _set_edge_width


func _set_size(value: Vector2) -> void:
	size = value
	queue_redraw()
	update_configuration_warnings()


func _set_color(value: Color) -> void:
	color = value
	queue_redraw()


func _set_edge_color(value: Color) -> void:
	edge_color = value
	queue_redraw()


func _set_edge_width(value: float) -> void:
	edge_width = value
	queue_redraw()


## The ledge in the node's own coordinates.
func _local_rect() -> Rect2:
	return Rect2(-size * 0.5, size)


func is_point_inside(global_point: Vector2) -> bool:
	return _local_rect().has_point(to_local(global_point))


func project_inside(global_point: Vector2) -> Vector2:
	# Clamping each axis independently is the nearest point on a rectangle, so walking into a
	# side keeps the player sliding along it instead of stopping dead.
	var half := (size * 0.5 - Vector2.ONE * SURFACE_EPSILON).maxf(0.0)
	return to_global(to_local(global_point).clamp(-half, half))


func distance_to_point(global_point: Vector2) -> float:
	var outside := (to_local(global_point).abs() - size * 0.5).maxf(0.0)
	return outside.length()


func _draw() -> void:
	var rect := _local_rect()
	draw_rect(rect, color)
	if edge_width > 0.0 and edge_color.a > 0.0:
		# Inset by half the width, because draw_rect centres an outline on the edge it traces.
		draw_rect(rect.grow(-edge_width * 0.5), edge_color, false, edge_width)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if size.x <= 0.0 or size.y <= 0.0:
		warnings.append("Size must be greater than zero on both axes.")
	return warnings
