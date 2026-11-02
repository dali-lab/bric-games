# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends "puddle.gd"

signal player_poisoned

# How often standing in the puddle costs the player apples. The spawner
# overrides this so the whole penalty is tuned from the level.
@export_range(0.1, 5.0, 0.1) var drain_interval: float = 1.0

var time_until_drain: float = 0.0


func _ready() -> void:
	super._ready()
	# A gentle pulse makes the bubbling poison look active.
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property($PuddleFill, "modulate", Color(0.8, 1.2, 0.6), 0.45)
	pulse.tween_property($PuddleFill, "modulate", Color.WHITE, 0.45)


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if not _player_inside():
		# Stepping out resets the clock, so re-entering costs straight away.
		time_until_drain = 0.0
		return
	time_until_drain -= delta
	if time_until_drain <= 0.0:
		# The first tick lands on contact; the rest follow once per interval.
		time_until_drain = drain_interval
		player_poisoned.emit()


func _player_inside() -> bool:
	for body: Node2D in get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false
