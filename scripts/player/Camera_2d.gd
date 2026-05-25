extends Camera2D

@onready var camera: Camera2D = $"."

func _ready():
	camera.zoom = Vector2(3, 3)
	camera.position_smoothing_enabled = true 
	camera.position_smoothing_speed = 3.5
