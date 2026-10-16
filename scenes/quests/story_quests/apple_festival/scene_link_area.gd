class_name SceneLinkArea extends Area2D


@export var scene_link: SceneLink


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		scene_link.switch()
