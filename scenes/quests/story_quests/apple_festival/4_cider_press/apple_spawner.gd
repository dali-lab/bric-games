# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name AppleSpawner extends Node2D

const APPLE = preload("uid://qd0gwan0lc4s")
# Every apple variant is a region of the shared texture atlas, so they all
# share one draw size and one outline.
const GOLDEN_APPLE = preload(
	"res://scenes/quests/story_quests/apple_festival/4_cider_press/cider_press_components/apple_golden.tres"
)
const GREEN_APPLE = preload(
	"res://scenes/quests/story_quests/apple_festival/4_cider_press/cider_press_components/apple_green.tres"
)
const YELLOW_APPLE = preload(
	"res://scenes/quests/story_quests/apple_festival/4_cider_press/cider_press_components/apple_yellow.tres"
)
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
# An apple hits the ground exactly this long after it spawns, and aims at where
# the player will be by then. Fast apples barely telegraph; slow ones give the
# player time to read the shadow and walk out.
@export_range(0.1, 3.0, 0.05) var slow_prediction_time: float = 1.2
@export_range(0.1, 3.0, 0.05) var fast_prediction_time: float = 0.5
@export_range(0.0, 1.0, 0.05) var fast_apple_chance: float = 0.35
@export_range(0.0, 200.0, 5.0) var aim_spread: float = 65.0
# Clearance radius of a size-1.0 apple. Two apples have to land at least the
# sum of their radii apart, so the circle keeps outlining the apple at any size.
@export_range(0.0, 200.0, 1.0) var minimum_spacing_radius: float = 40.0
# Taking an apple to the head costs a few collected apples, not the whole run.
@export_range(0, 50, 1) var hit_penalty_minimum: int = 5
@export_range(0, 50, 1) var hit_penalty_maximum: int = 7
# Standing in poison keeps costing apples for as long as the player stays in it.
@export_range(0, 50, 1) var poison_penalty_per_tick: int = 1
@export_range(0.1, 5.0, 0.1) var poison_tick_interval: float = 1.0
# After an apple connects, nothing can hurt the player again until they have had
# a moment to walk out of the mess they are standing in.
@export_range(0.0, 5.0, 0.1) var invulnerability_time: float = 1.4
# Half a blink: the time the player takes to fade out, and again to fade back in.
@export_range(0.02, 0.5, 0.01) var blink_interval: float = 0.09
@export_range(0.0, 1.0, 0.05) var blink_opacity: float = 0.25
# However many apples are lost, only this many are thrown out of the basket, so
# a big hit never buries the field in fruit.
@export_range(1, 20, 1) var spilled_apples_maximum: int = 7

# How many landing spots to try before settling for the roomiest one.
const SPACING_ATTEMPTS: int = 12

# Apples currently in the air or resting, so the next one can keep its distance.
var live_apples: Array[Node2D] = []
var restarting: bool = false
var started: bool = false
var applesCollected: int = 0
const appleThreshold: int = 50
var loss_tween: Tween
var invulnerable: bool = false
var blink_tween: Tween

@onready var spawn_timer: Timer = $SpawnTimer
# Apples live under the y-sorted ground node so the player passes in front of
# the ones below them and behind the ones above.
@onready var apple_container: Node2D = $"../OnTheGround"
@onready var poison_puddles: Node2D = $PuddleMask/PoisonPuddles
@onready var sticky_puddles: Node2D = $PuddleMask/StickyPuddles
@onready var apple_count_label: Label = $"../ScreenOverlay/GoalHUD/AppleCount"
@onready var impact_shaker: Shaker = $"../ImpactShaker"
@onready var player: Player = $"../OnTheGround/Player"


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
	# Speed and weight read together: the quick ones are small, and only the
	# slow, well-telegraphed ones are allowed to be heavy.
	var is_fast: bool = randf() < fast_apple_chance
	var prediction_time: float = fast_prediction_time if is_fast else slow_prediction_time
	# Most apples are small. Only one in ten can use the largest sizes.
	var regular_max: float = minf(maximum_apple_size, 2.5)
	var regular_min: float = minf(minimum_apple_size, regular_max)
	# Bend the roll toward whichever end of the range this apple belongs at.
	var size_roll: float = randf()
	size_roll = size_roll * size_roll if is_fast else sqrt(size_roll)
	var apple_size: float = lerpf(regular_min, regular_max, size_roll)
	if not is_fast and maximum_apple_size >= 3.0 and randf() < big_apple_chance:
		apple_size = randf_range(clampf(minimum_apple_size, 3.0, maximum_apple_size), maximum_apple_size)
	apple.is_big = apple_size >= 3.0
	# Scale the apple, its shadow, and its hit area together.
	apple.scale = Vector2.ONE * apple_size
	# Land on the beat the aim was predicted for.
	apple.set_approach_time(prediction_time)
	# The size decides how much room this apple needs, so lock the landing spot
	# after it, and before the warning shadow appears.
	var landing_position: Vector2 = _pick_landing_position(apple_size, prediction_time)
	apple.connect("player_hit", _on_player_hit)
	apple.connect("apple_land", _on_apple_land.bind(apple))
	apple.connect("apple_fade", _on_apple_fade.bind(apple))
	attach_apple(apple, landing_position)


# Landing spots are picked in spawner space, but apples are parented to the
# y-sorted ground node, so the position is converted on the way in.
func attach_apple(apple: Node2D, spawner_position: Vector2) -> void:
	apple_container.add_child(apple)
	apple.global_position = to_global(spawner_position)
	live_apples.append(apple)
	apple.tree_exited.connect(_forget_apple.bind(apple))


func _forget_apple(apple: Node2D) -> void:
	live_apples.erase(apple)


func _pick_landing_position(apple_size: float, prediction_time: float) -> Vector2:
	# Decide aim once so every retry keeps hunting the player if this apple was
	# meant to, instead of drifting into a plain random drop.
	var aimed: bool = randf() < aimed_apple_chance
	var roomiest_position: Vector2 = Vector2.ZERO
	var roomiest_clearance: float = -INF
	for attempt: int in range(SPACING_ATTEMPTS):
		var candidate: Vector2 = _random_landing_position(aimed, prediction_time)
		var clearance: float = _clearance_at(candidate, apple_size)
		if clearance >= 0.0:
			return candidate
		if clearance > roomiest_clearance:
			roomiest_clearance = clearance
			roomiest_position = candidate
	# Nowhere was clear enough. The widest gap still beats stacking apples, and
	# spawning never stalls just because the ground is crowded.
	return roomiest_position


func _random_landing_position(aimed: bool, prediction_time: float) -> Vector2:
	var landing_position: Vector2 = Vector2(
		randf_range(spawn_area.position.x, spawn_area.end.x),
		randf_range(spawn_area.position.y, spawn_area.end.y)
	)
	if aimed:
		# Aim ahead of movement, with some scatter so apples don't all pile up.
		landing_position = to_local(player.global_position + player.velocity * prediction_time)
		landing_position += Vector2(
			randf_range(-aim_spread, aim_spread), randf_range(-aim_spread, aim_spread)
		)
	return landing_position.clamp(spawn_area.position, spawn_area.end)


# Distance between this spot and the nearest apple, minus the room the two of
# them need. Negative means they would overlap; INF means the field is empty.
func _clearance_at(landing_position: Vector2, apple_size: float) -> float:
	var smallest_gap: float = INF
	for other: Node2D in live_apples:
		if not is_instance_valid(other):
			continue
		var required: float = (apple_size + other.scale.x) * minimum_spacing_radius
		var gap: float = landing_position.distance_to(to_local(other.global_position)) - required
		smallest_gap = minf(smallest_gap, gap)
	return smallest_gap


func _on_apple_land(apple: Node2D) -> void:
	if restarting:
		return
	# Don't let a small landing interrupt the stronger shake from losing apples.
	var landing_strength: float = 12.0 if apple.is_big else 3.0
	if impact_shaker.current_intensity < landing_strength:
		impact_shaker.shake(landing_strength, 0.22 if apple.is_big else 0.1)
	applesCollected = mini(applesCollected + 1, appleThreshold)
	_update_apple_count()

	if applesCollected >= appleThreshold:
		# Let this apple's impact check finish before declaring a win.
		_finish_goal.call_deferred()


# Puddles are laid down as the apple dissolves away, not the moment it lands,
# so the liquid is never hidden under the apple that left it.
func _on_apple_fade(apple: Node2D) -> void:
	if restarting:
		return
	if apple.leaves_poison:
		var puddle: Area2D = POISON_PUDDLE.instantiate()
		puddle.position = poison_puddles.to_local(apple.global_position)
		puddle.scale = apple.scale
		puddle.drain_interval = poison_tick_interval
		puddle.connect("player_poisoned", _on_player_poisoned)
		# Keep poison separate so it survives when the apple disappears.
		poison_puddles.add_child(puddle)
	elif apple.leaves_sticky_juice:
		var puddle: Area2D = STICKY_PUDDLE.instantiate()
		puddle.position = sticky_puddles.to_local(apple.global_position)
		puddle.scale = apple.scale
		sticky_puddles.add_child(puddle)


func _update_apple_count() -> void:
	apple_count_label.text = "%d/%d apples" % [applesCollected, appleThreshold]


func _finish_goal() -> void:
	if restarting or applesCollected < appleThreshold:
		return
	restarting = true
	spawn_timer.stop()
	if loss_tween:
		loss_tween.kill()
	_end_invulnerability()
	apple_count_label.modulate = Color.WHITE
	scene_link.switch()


func _on_player_hit() -> void:
	if restarting or invulnerable:
		return
	# An empty basket means there is nothing left to drop but the player.
	if applesCollected <= 0:
		_lose_game()
		return
	impact_shaker.shake(30.0, 0.5)
	var lost: int = _lose_apples(
		randi_range(
			mini(hit_penalty_minimum, hit_penalty_maximum),
			maxi(hit_penalty_minimum, hit_penalty_maximum)
		)
	)
	_spill_apples(lost)
	# Only a direct hit buys the player time; poison is escaped by walking out.
	_start_invulnerability()


func _on_player_poisoned() -> void:
	if restarting or invulnerable:
		return
	if applesCollected <= 0:
		_lose_game()
		return
	_spill_apples(_lose_apples(poison_penalty_per_tick))


# Returns how many apples were actually lost, which is fewer than asked for when
# the basket runs out partway through.
func _lose_apples(amount: int) -> int:
	if amount <= 0:
		return 0
	var lost: int = mini(amount, applesCollected)
	applesCollected -= lost
	_update_apple_count()
	_flash_apple_count()
	return lost


# Throws a few apples out of the player, fanned out so they do not all land in
# the same spot. They are decoration only; the count above is the real loss.
func _spill_apples(amount: int) -> void:
	if amount <= 0:
		return
	var count: int = mini(amount, spilled_apples_maximum)
	var origin: Vector2 = player.global_position
	var angle_offset: float = randf() * TAU
	for index: int in range(count):
		var angle: float = angle_offset + TAU * (index + randf_range(-0.2, 0.2)) / count
		SpilledApple.spill(apple_container, origin, Vector2.RIGHT.rotated(angle))


func _start_invulnerability() -> void:
	if invulnerability_time <= 0.0:
		return
	invulnerable = true
	# Blinking is the only tell the player gets that the next apple is free.
	if blink_tween:
		blink_tween.kill()
	blink_tween = create_tween().set_loops()
	blink_tween.tween_property(player, "modulate:a", blink_opacity, blink_interval)
	blink_tween.tween_property(player, "modulate:a", 1.0, blink_interval)
	get_tree().create_timer(invulnerability_time).timeout.connect(_end_invulnerability)


func _end_invulnerability() -> void:
	invulnerable = false
	if blink_tween:
		blink_tween.kill()
		blink_tween = null
	# However the blink was interrupted, the player ends up solid again.
	player.modulate.a = 1.0


# Getting hit with an empty basket ends the run: the player goes down and the
# scene starts over.
func _lose_game() -> void:
	restarting = true
	spawn_timer.stop()
	if loss_tween:
		loss_tween.kill()
	_end_invulnerability()
	impact_shaker.shake(45.0, 0.7)
	apple_count_label.modulate = Color(1.0, 0.35, 0.25)
	player.defeat()


func _flash_apple_count() -> void:
	if loss_tween:
		loss_tween.kill()
	apple_count_label.modulate = Color(1.0, 0.35, 0.25)
	loss_tween = create_tween()
	loss_tween.tween_property(apple_count_label, "modulate", Color.WHITE, 0.5)
