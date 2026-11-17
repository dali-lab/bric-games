# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends CanvasLayer
## On-screen arrows that point the player toward [member target].
##
## Draws a trail of chevrons from the player toward the target, plus a bouncing
## arrow over the target while it is on screen. Starts hidden; call
## [method fade_to] to show or hide it.

## The character the trail starts from.
var player: Node2D
## Where the arrows point to.
var target: Node2D
## Added to [member target]'s position, e.g. to point at a character's head.
var target_offset := Vector2.ZERO

var _drawing: _Drawing
var _tween: Tween


func _init() -> void:
	layer = 5
	_drawing = _Drawing.new()
	_drawing.modulate.a = 0.0
	add_child(_drawing)


func _process(_delta: float) -> void:
	if _drawing.modulate.a <= 0.0 or not player or not target:
		return
	var canvas := get_viewport().get_canvas_transform()
	_drawing.from = canvas * (player.global_position + Vector2(0, -60))
	_drawing.to = canvas * (target.global_position + target_offset)
	_drawing.queue_redraw()


## Fades the arrows to [param alpha] (1 shows them, 0 hides them).
func fade_to(alpha: float, time: float = 0.6) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_drawing, "modulate:a", alpha, time)


class _Drawing:
	extends Node2D

	const FILL := Color(1.0, 0.93, 0.6)
	const OUTLINE := Color(0.18, 0.12, 0.05)
	const CHEVRON_COUNT := 3
	const START_GAP := 90.0
	const SPACING := 66.0

	var from := Vector2.ZERO
	var to := Vector2.ZERO

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var direction := to - from
		if direction.length() < 1.0:
			return
		direction = direction.normalized()

		var room := maxf(from.distance_to(to) - START_GAP - 80.0, 0.0)
		for i in CHEVRON_COUNT:
			var distance := START_GAP + i * SPACING
			if distance > START_GAP + room:
				break
			# Each chevron lights up in turn, so the trail seems to move forward.
			var wave := 0.65 + 0.35 * (0.5 + 0.5 * sin(t * 4.0 - i * 0.9))
			_draw_chevron(from + direction * distance, direction, 28.0, wave)

		var screen := get_viewport_rect().grow(-40.0)
		if screen.has_point(to):
			var bob := sin(t * 3.0) * 10.0
			_draw_chevron(to + Vector2(0, -130 + bob), Vector2.DOWN, 34.0, 1.0)

	func _draw_chevron(center: Vector2, direction: Vector2, size: float, alpha: float) -> void:
		var side := direction.orthogonal()
		var tip := center + direction * size
		var back := center - direction * size * 0.6
		var points := PackedVector2Array(
			[
				tip,
				back + side * size,
				back + side * size * 0.45 + direction * size * 0.35,
				back - side * size * 0.45 + direction * size * 0.35,
				back - side * size,
			]
		)
		var fill := FILL
		fill.a = alpha
		var outline := OUTLINE
		outline.a = alpha
		draw_colored_polygon(points, fill)
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, outline, 5.0, true)
