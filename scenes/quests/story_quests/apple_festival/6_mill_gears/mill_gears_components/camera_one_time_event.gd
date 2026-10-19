extends Node2D

@onready var phantom_camera_2d: PhantomCamera2D = $PhantomCamera2D

func _ready() -> void:
	var p = get_parent()
	if p.has_signal("toggled"):
		p.toggled.connect(func(b):
			_set_priority(3.0)
		)


func _set_priority(time: float = 1.5):
	var timer = get_tree().create_timer(time).timeout.connect(func():
		phantom_camera_2d.priority = 0
		get_parent().toggled.disconnect(_set_priority)
	)
	
	phantom_camera_2d.priority = 25
