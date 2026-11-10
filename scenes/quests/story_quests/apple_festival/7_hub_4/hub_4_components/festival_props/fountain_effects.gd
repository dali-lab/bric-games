# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

# Each cider stream follows a short arc: start, highest control point, end.
const STREAMS: Array[Array] = [
	[Vector2(192, 76), Vector2(158, -20), Vector2(128, 117)],
	[Vector2(192, 89), Vector2(167, -26), Vector2(151, 120)],
	[Vector2(192, 77), Vector2(222, -22), Vector2(246, 117)],
	[Vector2(192, 90), Vector2(214, -25), Vector2(219, 118)],
]
const SPLASH_POINTS: Array[Vector2] = [
	Vector2(133, 123), Vector2(241, 123), Vector2(104, 279), Vector2(282, 279),
]

var elapsed: float = 0.0


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	# Small moving highlights make the painted streams look like flowing cider.
	for stream_index in STREAMS.size():
		var stream: Array = STREAMS[stream_index]
		for drop in 3:
			var progress: float = fposmod(elapsed * 0.75 + drop / 3.0 + stream_index * 0.17, 1.0)
			var head: Vector2 = _stream_point(stream, progress)
			var tail: Vector2 = _stream_point(stream, maxf(0.0, progress - 0.05))
			draw_line(tail, head, Color(1.0, 0.83, 0.51, 0.85), 2.5, true)

	# Front-facing half rings stay on the cider and clear of the stone pillar.
	for ring in 2:
		var progress: float = fposmod(elapsed * 0.5 + ring * 0.5, 1.0)
		_draw_ripple(Vector2(191, 123), Vector2(24, 7), Vector2(62, 18), progress)
		_draw_ripple(Vector2(191, 272), Vector2(80, 40), Vector2(113, 52), progress)

	# A pair of tiny droplets hops out of the cider, then falls back into each bowl.
	for splash in SPLASH_POINTS.size():
		for drop in 2:
			var progress: float = fposmod(elapsed * 1.4 + splash * 0.23 + drop * 0.5, 1.0)
			var offset := Vector2((drop * 2 - 1) * progress * 10.0, -sin(progress * PI) * 8.0)
			var opacity: float = sin(progress * PI) * 0.8
			draw_circle(
				SPLASH_POINTS[splash] + offset, 2.0, Color(1.0, 0.83, 0.51, opacity)
			)


func _stream_point(stream: Array, progress: float) -> Vector2:
	return stream[0].lerp(stream[1], progress).lerp(
		stream[1].lerp(stream[2], progress), progress
	)


func _draw_ripple(center: Vector2, start: Vector2, finish: Vector2, progress: float) -> void:
	var radius: Vector2 = start.lerp(finish, progress)
	var points := PackedVector2Array()
	for point in 25:
		var angle: float = PI * point / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	var opacity: float = sin(progress * PI) * 0.55
	draw_polyline(points, Color(1.0, 0.85, 0.57, opacity), 1.8, true)
