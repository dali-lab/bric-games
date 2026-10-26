# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name AppleSpawner extends Node2D

const APPLE = preload("uid://qd0gwan0lc4s")
const GOLDEN_APPLE = preload("uid://r4utk1wn7shc")
const GREEN_APPLE = preload("uid://cr70bynm68g03")
const YELLOW_APPLE = preload("uid://4b5oxxkj0s8l")
const POISON_PUDDLE = preload(
	"res://scenes/quests/story_quests/apple_festival/4_cider_press/cider_press_components/poison_puddle.tscn"
)
const STICKY_PUDDLE = preload(
	"res://scenes/quests/story_quests/apple_festival/4_cider_press/cider_press_components/sticky_puddle.tscn"
)

@onready var scene_link: SceneLink = $"../SceneLink"

@export_range(0.1, 10.0, 0.1) var spawn_interval: float = 0.5
# Landing positions are relative to the AppleSpawner node.
@export var spawn_area: Rect2 = Rect2(-435, -175, 870, 350)
@export_range(0.25, 5.0, 0.05) var minimum_apple_size: float = 1.50
@export_range(0.25, 5.0, 0.05) var maximum_apple_size: float = 4.50
@export_range(0.0, 1.0, 0.01) var big_apple_chance: float = 0.10
@export_range(0.0, 1.0, 0.05) var aimed_apple_chance: float = 0.65
@export_range(0.0, 2.0, 0.05) var prediction_time: float = 1.2
@export_range(0.0, 200.0, 5.0) var aim_spread: float = 65.0

var restarting: bool = false
var started: bool = false
var applesCollected: int = 0
const appleThreshold: int = 100
var loss_tween: Tween

@onready var spawn_timer: Timer = $SpawnTimer
@onready var poison_puddles: Node2D = $PuddleMask/PoisonPuddles
@onready var sticky_puddles: Node2D = $PuddleMask/StickyPuddles
@onready var apple_count_label: Label = $"../ScreenOverlay/GoalHUD/AppleCount"
@onready var impact_shaker: Shaker = $"../ImpactShaker"
@onready var player: CharacterBody2D = $"../OnTheGround/Player"


func _ready() -> void:
	_update_apple_count()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_spawn_apple)


func start_spawning() -> void:
	if started:
		return
	started = true
	spawn_timer.start()
	_spawn_apple()


func _spawn_apple() -> void:
	if restarting or not started:
		return
	var random_number: int = randi_range(1, 4)
	var apple: Node2D
	if random_number == 1:
		apple = APPLE.instantiate()
	elif random_number == 2:
		apple = APPLE.instantiate()
		apple.get_node("%AppleSprite").texture = GOLDEN_APPLE
	elif random_number == 3:
		apple = APPLE.instantiate()
		apple.get_node("%AppleSprite").texture = GREEN_APPLE
		apple.leaves_poison = true
	else:
		apple = APPLE.instantiate()
		apple.get_node("%AppleSprite").texture = YELLOW_APPLE
		apple.leaves_sticky_juice = true
	# Lock the landing spot before the warning shadow appears.
	apple.position = _pick_landing_position()
	# Most apples are small. Only one in ten can use the largest sizes.
	var regular_max: float = minf(maximum_apple_size, 2.5)
	var apple_size: float = randf_range(minf(minimum_apple_size, regular_max), regular_max)
	if maximum_apple_size >= 3.0 and randf() < big_apple_chance:
		apple_size = randf_range(clampf(minimum_apple_size, 3.0, maximum_apple_size), maximum_apple_size)
	apple.is_big = apple_size >= 3.0
	# Scale the apple, its shadow, and its hit area together.
	apple.scale = Vector2.ONE * apple_size
	apple.connect("player_hit", _on_player_hit)
	apple.connect("apple_land", _on_apple_land.bind(apple))
	add_child(apple)


func _pick_landing_position() -> Vector2:
	var landing_position: Vector2 = Vector2(
		randf_range(spawn_area.position.x, spawn_area.end.x),
		randf_range(spawn_area.position.y, spawn_area.end.y)
	)
	if randf() < aimed_apple_chance:
		# Aim ahead of movement, with some scatter so apples don't all pile up.
		landing_position = to_local(player.global_position + player.velocity * prediction_time)
		landing_position += Vector2(
			randf_range(-aim_spread, aim_spread), randf_range(-aim_spread, aim_spread)
		)
	return landing_position.clamp(spawn_area.position, spawn_area.end)


func _on_apple_land(apple: Node2D) -> void:
	if restarting:
		return
	# Don't let a small landing interrupt the stronger shake from losing apples.
	var landing_strength: float = 12.0 if apple.is_big else 3.0
	if impact_shaker.current_intensity < landing_strength:
		impact_shaker.shake(landing_strength, 0.22 if apple.is_big else 0.1)
	applesCollected = mini(applesCollected + 1, appleThreshold)
	_update_apple_count()

	if apple.leaves_poison:
		var puddle: Area2D = POISON_PUDDLE.instantiate()
		puddle.position = poison_puddles.to_local(apple.global_position)
		puddle.scale = apple.scale
		puddle.connect("player_hit", _on_player_hit)
		# Keep poison separate so it survives when the apple disappears.
		poison_puddles.add_child(puddle)
	elif apple.leaves_sticky_juice:
		var puddle: Area2D = STICKY_PUDDLE.instantiate()
		puddle.position = sticky_puddles.to_local(apple.global_position)
		puddle.scale = apple.scale
		sticky_puddles.add_child(puddle)

	if applesCollected >= appleThreshold:
		# Let this apple's impact check finish before declaring a win.
		_finish_goal.call_deferred()


func _update_apple_count() -> void:
	apple_count_label.text = "%d/%d apples" % [applesCollected, appleThreshold]


func _finish_goal() -> void:
	if restarting or applesCollected < appleThreshold:
		return
	restarting = true
	spawn_timer.stop()
	if loss_tween:
		loss_tween.kill()
	apple_count_label.modulate = Color.WHITE
	scene_link.switch()


func _on_player_hit() -> void:
	if restarting:
		return
	restarting = true
	# Finish collision callbacks before clearing poison or switching scenes.
	_reset_after_hit.call_deferred()


func _reset_after_hit() -> void:
	for puddle: Node in poison_puddles.get_children():
		puddle.queue_free()
	for puddle: Node in sticky_puddles.get_children():
		puddle.queue_free()

	impact_shaker.shake(30.0, 0.5)
	_flash_apple_count()
	applesCollected = 0
	_update_apple_count()
	restarting = false


func _flash_apple_count() -> void:
	if loss_tween:
		loss_tween.kill()
	apple_count_label.modulate = Color(1.0, 0.35, 0.25)
	loss_tween = create_tween()
	loss_tween.tween_property(apple_count_label, "modulate", Color.WHITE, 0.5)
