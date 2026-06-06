extends Node2D

func _ready() -> void:
	var hud := PlayerHUD.new()
	add_child(hud)
