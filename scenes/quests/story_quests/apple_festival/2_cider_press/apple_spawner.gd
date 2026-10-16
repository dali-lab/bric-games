# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

const APPLE = preload(
	"res://scenes/quests/story_quests/apple_festival/2_cider_press/cider_press_components/apple.tscn"
)

@export_range(0.1, 10.0, 0.1) var spawn_interval: float = 1.2
# Landing positions are relative to the AppleSpawner node.
@export var spawn_area: Rect2 = Rect2(-435, -175, 870, 350)
@export_range(0.25, 5.0, 0.05) var minimum_apple_size: float = 0.75
@export_range(0.25, 5.0, 0.05) var maximum_apple_size: float = 3.0

var survival_time: float = 0.0
var restarting: bool = false

@onready var spawn_timer: Timer = $SpawnTimer
@onready var time_label: Label = $"../ScreenOverlay/SurvivalTime"


func _ready() -> void:
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_spawn_apple)
	spawn_timer.start()
	_spawn_apple()


func _process(delta: float) -> void:
	survival_time += delta
	time_label.text = "Survived: %.1f s" % survival_time


func _spawn_apple() -> void:
	var apple: Node2D = APPLE.instantiate()
	apple.position = Vector2(
		randf_range(spawn_area.position.x, spawn_area.end.x),
		randf_range(spawn_area.position.y, spawn_area.end.y)
	)
	# Scale the apple, its shadow, and its hit area together.
	apple.scale = Vector2.ONE * randf_range(minimum_apple_size, maximum_apple_size)
	apple.connect("player_hit", _on_player_hit)
	add_child(apple)


func _on_player_hit() -> void:
	if restarting:
		return
	restarting = true
	spawn_timer.stop()
	set_process(false)
	# Wait until the impact callback finishes before replacing the scene.
	get_tree().reload_current_scene.call_deferred()
