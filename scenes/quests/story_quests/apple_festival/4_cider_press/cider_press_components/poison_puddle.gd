# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Area2D

signal player_hit

@export_range(0.5, 10.0, 0.5) var lifetime: float = 4.0

var has_hit_player: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Lifetime.timeout.connect(queue_free)
	$Lifetime.start(lifetime)
	# A gentle pulse makes the bubbling poison look active.
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property($PuddleSprite, "modulate", Color(0.8, 1.2, 0.6), 0.45)
	pulse.tween_property($PuddleSprite, "modulate", Color.WHITE, 0.45)


func _on_body_entered(body: Node2D) -> void:
	if has_hit_player or is_queued_for_deletion():
		return
	if body.is_in_group("player"):
		has_hit_player = true
		player_hit.emit()
