# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

var tutorial_active: bool = true
var tutorial_hit: bool = false
var tutorial_apple: Node2D
var move_flash: Tween

@onready var player: Player = $OnTheGround/Player
@onready var sticky_puddles: Node2D = $AppleSpawner/PuddleMask/StickyPuddles
@onready var spawner: AppleSpawner = $AppleSpawner
@onready var hint: Label = $ScreenOverlay/StartHint
@onready var intro_text: Label = $ScreenOverlay/IntroText


func _ready() -> void:
	# This dodging game only needs the shared player's movement controls.
	for ability: Node2D in [player.player_hook, player.player_repel]:
		ability.hide()
		ability.process_mode = Node.PROCESS_MODE_DISABLED
	_start_tutorial.call_deferred()


func _start_tutorial() -> void:
	hint.hide()
	intro_text.text = "MOVE!"
	intro_text.modulate.a = 1.0
	intro_text.show()
	move_flash = create_tween().set_loops()
	move_flash.tween_property(intro_text, "modulate:a", 0.15, 0.35)
	move_flash.tween_property(intro_text, "modulate:a", 1.0, 0.35)
	tutorial_hit = false
	player.global_position = spawner.global_position
	player.velocity = Vector2.ZERO
	player.input_walk_behavior.input_vector = Vector2.ZERO
	tutorial_apple = AppleSpawner.APPLE.instantiate()
	tutorial_apple.scale = Vector2.ONE * 3.0
	tutorial_apple.is_big = true
	tutorial_apple.warning_time = 0.6
	tutorial_apple.wait_for_dodge = true
	tutorial_apple.connect("apple_land", _on_tutorial_landed)
	tutorial_apple.connect("player_hit", _on_tutorial_hit)
	tutorial_apple.tree_exited.connect(_on_tutorial_finished, CONNECT_DEFERRED)
	# This practice apple never connects to the score or puddle callbacks.
	spawner.add_child(tutorial_apple)


func _update_tutorial_fall() -> void:
	if not is_instance_valid(tutorial_apple) or not tutorial_apple.waiting_for_dodge:
		return
	if tutorial_apple.hit_area.overlaps_body(player):
		return
	tutorial_apple.waiting_for_dodge = false
	tutorial_apple.animation.play()
	move_flash.kill()
	intro_text.hide()


func _on_tutorial_landed() -> void:
	$ImpactShaker.shake(12.0, 0.22)


func _on_tutorial_hit() -> void:
	tutorial_hit = true
	hint.text = "Try again. Move aside!"
	hint.show()


func _on_tutorial_finished() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	tutorial_apple = null
	if tutorial_hit:
		_start_tutorial.call_deferred()
		return
	# Wait until the apple is gone, so walking into it after landing still counts.
	hint.text = "Get 100 apples in the basket. Dodge the falling apples."
	hint.show()
	var intro: Tween = create_tween().set_ignore_time_scale(true)
	intro.tween_interval(3.0)
	for number: int in [3, 2, 1]:
		intro.tween_callback(_show_countdown.bind(str(number)))
		intro.tween_interval(1.0)
	intro.tween_callback(_begin_game)
	intro.tween_interval(0.7)
	intro.tween_property(intro_text, "modulate:a", 0.0, 0.3)
	intro.tween_callback(intro_text.hide)


func _show_countdown(text: String) -> void:
	intro_text.text = text
	intro_text.modulate.a = 1.0
	intro_text.show()


func _begin_game() -> void:
	tutorial_active = false
	hint.hide()
	_show_countdown("GO!")
	spawner.start_spawning()


func _physics_process(_delta: float) -> void:
	if tutorial_active:
		_update_tutorial_fall()
	var speed_multiplier: float = 1.0
	for puddle: Area2D in sticky_puddles.get_children():
		if not puddle.is_queued_for_deletion() and puddle.overlaps_body(player):
			speed_multiplier = 0.35
			break

	var movement: InputWalkBehavior = player.input_walk_behavior
	var speed: float = (
		movement.speeds.run_speed if Input.is_action_pressed("running") else movement.speeds.walk_speed
	)
	# Refresh held movement too; the shared movement script normally waits for input events.
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	movement.input_vector = direction * speed * speed_multiplier
