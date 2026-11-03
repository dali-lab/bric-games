# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
## A small apple knocked loose from the player's basket when they are hit.
##
## It pops out, bounces once where it lands, and dries away. Spilled apples are
## purely decorative: they never block the player, hurt them, or count towards
## the basket, so losing a handful reads at a glance without changing the rules.
class_name SpilledApple
extends Node2D

const APPLE_TEXTURES: Array[Texture2D] = [
	preload(
		"res://scenes/quests/story_quests/apple_festival/4_cider_press/cider_press_components/apple_red.tres"
	),
	preload(
		"res://scenes/quests/story_quests/apple_festival/4_cider_press/cider_press_components/apple_golden.tres"
	),
	preload(
		"res://scenes/quests/story_quests/apple_festival/4_cider_press/cider_press_components/apple_green.tres"
	),
	preload(
		"res://scenes/quests/story_quests/apple_festival/4_cider_press/cider_press_components/apple_yellow.tres"
	),
]

# A spilled apple is a bite-sized version of the ones falling from the tree.
const SPRITE_SCALE: float = 0.18
# How far the apple sits into its shadow, as a fraction of its own height.
const SHADOW_SINK: float = 0.08
const SHADOW_SCALE := Vector2(0.5, 0.25)

# How far from the player the apple comes to rest, and how high it arcs.
const TRAVEL_DISTANCE := Vector2(45.0, 110.0)
const HOP_HEIGHT := Vector2(40.0, 75.0)
const FLIGHT_TIME := Vector2(0.35, 0.5)
# The second, much smaller hop the apple makes when it first touches down.
const BOUNCE_HEIGHT_RATIO: float = 0.25
const BOUNCE_TIME_RATIO: float = 0.45
const REST_TIME: float = 0.6
const FADE_TIME: float = 0.4

# One radial gradient, shared by every spilled apple there will ever be.
static var _shadow_texture: GradientTexture2D

var travel: Vector2 = Vector2.RIGHT

@onready var sprite: Sprite2D = $AppleSprite
@onready var shadow: Sprite2D = $AppleShadow


## Throws one apple out of [param origin] (in global coordinates) roughly along
## [param direction], under [param parent]. Pass the y-sorted ground node so the
## apples sort against the player like everything else in the field does.
static func spill(parent: Node2D, origin: Vector2, direction: Vector2) -> SpilledApple:
	var apple := SpilledApple.new()
	# The ground is seen at an angle, so apples travel less in depth than across.
	var distance: float = randf_range(TRAVEL_DISTANCE.x, TRAVEL_DISTANCE.y)
	apple.travel = direction.normalized() * distance * Vector2(1.0, 0.55)
	apple._build()
	# Placed before entering the tree: the flight tween reads this position the
	# moment the apple is ready, and tweens away from it.
	apple.position = parent.to_local(origin)
	parent.add_child(apple)
	return apple


# Built in code rather than in a scene file: a spilled apple is two sprites and
# a tween, and keeping it here keeps it beside the animation that drives it.
func _build() -> void:
	var new_shadow := Sprite2D.new()
	new_shadow.name = "AppleShadow"
	new_shadow.texture = _get_shadow_texture()
	new_shadow.z_index = -1
	new_shadow.scale = SHADOW_SCALE
	new_shadow.modulate.a = 0.0
	add_child(new_shadow)

	var new_sprite := Sprite2D.new()
	new_sprite.name = "AppleSprite"
	new_sprite.texture = APPLE_TEXTURES[randi() % APPLE_TEXTURES.size()]
	new_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	new_sprite.scale = Vector2.ONE * SPRITE_SCALE
	# Put the bottom of the apple at the sprite's origin, then push it down into
	# the shadow, so the apple rests on the ground instead of hovering over it.
	var texture_height: float = new_sprite.texture.get_height()
	new_sprite.offset.y = -texture_height * (0.5 - SHADOW_SINK)
	add_child(new_sprite)

	# Same outline the falling apples wear, so the spill looks like it came from
	# the same orchard.
	var outline := NAtlasOutline.new()
	outline.name = "SpriteOutline"
	outline.outline_tint = Color.BLACK
	new_sprite.add_child(outline)
	outline.target = new_sprite


func _ready() -> void:
	var flight_time: float = randf_range(FLIGHT_TIME.x, FLIGHT_TIME.y)
	var hop_height: float = randf_range(HOP_HEIGHT.x, HOP_HEIGHT.y)
	var bounce_time: float = flight_time * BOUNCE_TIME_RATIO
	var spin: float = randf_range(-TAU, TAU)

	# The apple drifts away from the player for the whole arc. Moving the root
	# rather than the sprite keeps the y-sorting honest, so an apple that lands
	# behind the player is drawn behind her. This runs on its own tween so the
	# hop below, which only decides how high off the ground the apple is, can
	# bounce on its own schedule.
	var travel_tween: Tween = create_tween()
	travel_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var drift: PropertyTweener = travel_tween.tween_property(
		self, "position", position + travel, flight_time
	)
	drift.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	travel_tween.parallel().tween_property(sprite, "rotation", spin, flight_time)
	# The shadow fades in as the apple comes back down to meet it.
	travel_tween.parallel().tween_property(shadow, "modulate:a", 0.75, flight_time)

	var hop: Tween = create_tween()
	hop.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween_hop(hop, hop_height, flight_time)
	_tween_hop(hop, hop_height * BOUNCE_HEIGHT_RATIO, bounce_time)
	hop.tween_interval(REST_TIME)
	hop.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	hop.tween_callback(queue_free)


# One up-and-down arc: quick to rise, accelerating into the ground.
func _tween_hop(hop: Tween, height: float, duration: float) -> void:
	var rise: PropertyTweener = hop.tween_property(sprite, "position:y", -height, duration * 0.45)
	rise.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fall: PropertyTweener = hop.tween_property(sprite, "position:y", 0.0, duration * 0.55)
	fall.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


static func _get_shadow_texture() -> GradientTexture2D:
	if _shadow_texture != null:
		return _shadow_texture
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	gradient.offsets = PackedFloat32Array([0.0, 0.85])
	gradient.colors = PackedColorArray(
		[Color(0.08, 0.04, 0.02, 0.9), Color(0.08, 0.04, 0.02, 0.0)]
	)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	_shadow_texture = texture
	return texture
