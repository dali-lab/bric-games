class_name NAtlasOutline
extends Node

const OUTER_OUTLINE_SHADER: Shader = preload("uid://dvhdcqbsexp6h")
const OUTLINE_WIDTH_PARAM := &"outline_width"
const OUTLINE_TINT_PARAM := &"outline_tint"
const ATLAS_REGION_POS_PARAM := &"atlas_region_pos"
const ATLAS_REGION_SIZE_PARAM := &"atlas_region_size"
const DRAW_SIZE_PARAM := &"draw_size"

@export var target: CanvasItem:
	set(value):
		target = value
		_reset_tracked_state()
		apply_outline_parameters()

@export_range(0.0, 32.0, 0.5) var outline_width: float = 4.0:
	set(value):
		outline_width = maxf(0.0, value)
		apply_outline_parameters()

@export var outline_tint: Color = Color.WHITE:
	set(value):
		outline_tint = value
		apply_outline_parameters()

var _material: ShaderMaterial
var _last_texture: Texture2D
var _last_region: Rect2
var _last_draw_size: Vector2


func _ready() -> void:
	apply_outline_parameters()


func _process(_delta: float) -> void:
	var resolved := _resolve_target()
	var texture := _texture_for(resolved)
	var region := _region_for(texture)
	var draw_size := _draw_size_for(resolved, texture)
	var current_material: Material = resolved.material if resolved else null
	if texture != _last_texture \
			or region != _last_region \
			or draw_size != _last_draw_size \
			or current_material != _material:
		apply_outline_parameters()


func apply_outline_parameters() -> void:
	if not is_inside_tree():
		return

	var resolved := _resolve_target()
	var texture := _texture_for(resolved)
	if resolved == null or texture == null:
		return

	var region := _region_for(texture)
	var draw_size := _draw_size_for(resolved, texture)
	var material := _local_material_for(resolved)
	material.set_shader_parameter(OUTLINE_WIDTH_PARAM, outline_width)
	material.set_shader_parameter(OUTLINE_TINT_PARAM, outline_tint)
	material.set_shader_parameter(ATLAS_REGION_POS_PARAM, region.position)
	material.set_shader_parameter(ATLAS_REGION_SIZE_PARAM, region.size)
	material.set_shader_parameter(DRAW_SIZE_PARAM, draw_size)

	_last_texture = texture
	_last_region = region
	_last_draw_size = draw_size


func _resolve_target() -> CanvasItem:
	if is_instance_valid(target):
		return target
	return get_parent() as CanvasItem


func _local_material_for(item: CanvasItem) -> ShaderMaterial:
	if is_instance_valid(_material) and item.material == _material:
		return _material

	var existing := item.material as ShaderMaterial
	if existing != null and existing.shader == OUTER_OUTLINE_SHADER:
		_material = existing.duplicate() as ShaderMaterial
	else:
		_material = ShaderMaterial.new()
		_material.shader = OUTER_OUTLINE_SHADER

	_material.resource_local_to_scene = true
	item.material = _material
	return _material


static func _texture_for(item: CanvasItem) -> Texture2D:
	if item is Sprite2D:
		return (item as Sprite2D).texture
	if item is TextureRect:
		return (item as TextureRect).texture
	return null


static func _region_for(texture: Texture2D) -> Rect2:
	if texture is AtlasTexture:
		return (texture as AtlasTexture).region
	if texture == null:
		return Rect2()
	return Rect2(Vector2.ZERO, texture.get_size())


static func _draw_size_for(item: CanvasItem, texture: Texture2D) -> Vector2:
	var draw_size := Vector2.ONE
	if item is TextureRect:
		draw_size = (item as TextureRect).size
	elif item is Sprite2D:
		var sprite := item as Sprite2D
		if sprite.region_enabled:
			draw_size = sprite.region_rect.size
		elif texture != null:
			draw_size = texture.get_size() / Vector2(maxi(1, sprite.hframes), maxi(1, sprite.vframes))
	return draw_size.max(Vector2.ONE)


func _reset_tracked_state() -> void:
	_material = null
	_last_texture = null
	_last_region = Rect2()
	_last_draw_size = Vector2.ZERO
