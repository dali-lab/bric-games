# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D
## Nudges the player toward the canopy path when they seem lost at the bus.
##
## The nudge shows when the player walks into [member wrong_way_area], or after
## they've been free to move inside [member bus_area] for [member linger_time]
## seconds. While it shows, arrows on screen point from the player to
## [member path_entrance]. While the player is inside [member leave_area] (the
## canopy passage) the arrows hide. If they turn back into the bus area the
## arrows return; once they leave the passage on the far side, past
## [member farm_side_x], the nudge is gone for good.

## While the player can move inside this area, the linger timer counts up.
@export var bus_area: Area2D
## Walking into this area (the end of the bus area away from the path) shows the nudge right away.
@export var wrong_way_area: Area2D
## The canopy passage. The arrows hide while the player is inside it.
@export var leave_area: Area2D
## Leaving [member leave_area] east of this global x means the player reached the
## farm, so the nudge stops for good.
@export var farm_side_x: float = -300.0
## Where the arrows point to.
@export var path_entrance: Node2D
## Seconds the player can stay in the bus area before the nudge shows.
@export var linger_time: float = 12.0
## How long the nudge takes to fade in or out.
@export var fade_time: float = 0.6

const NudgeArrows = preload("nudge_arrows.gd")

var _player: Player
var _in_bus_area: bool = false
var _linger: float = 0.0
var _showing: bool = false
var _in_passage: bool = false
var _done: bool = false
var _arrows: NudgeArrows


func _ready() -> void:
	_arrows = NudgeArrows.new()
	_arrows.target = path_entrance
	add_child(_arrows)

	bus_area.body_entered.connect(_on_bus_area_body_entered)
	bus_area.body_exited.connect(_on_bus_area_body_exited)
	wrong_way_area.body_entered.connect(_on_wrong_way_body_entered)
	leave_area.body_entered.connect(_on_leave_area_body_entered)
	leave_area.body_exited.connect(_on_leave_area_body_exited)


func _process(delta: float) -> void:
	if _done:
		return
	if (
		not _showing
		and _in_bus_area
		and _player
		and _player.mode == Player.Mode.USER_CONTROLLED
	):
		_linger += delta
		if _linger >= linger_time:
			_show()


func _on_bus_area_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body
		_arrows.player = body
		_in_bus_area = true


func _on_bus_area_body_exited(body: Node2D) -> void:
	if body is Player:
		_in_bus_area = false


func _on_wrong_way_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body
		_arrows.player = body
		_show()


func _on_leave_area_body_entered(body: Node2D) -> void:
	if body is Player and not _done:
		_in_passage = true
		if _showing:
			_fade_to(0.0)


func _on_leave_area_body_exited(body: Node2D) -> void:
	if not body is Player or _done:
		return
	_in_passage = false
	if body.global_position.x > farm_side_x:
		_done = true
	elif _showing:
		_fade_to(1.0)


func _show() -> void:
	if _showing or _done:
		return
	_showing = true
	if not _in_passage:
		_fade_to(1.0)


func _fade_to(value: float) -> void:
	_arrows.fade_to(value, fade_time)
