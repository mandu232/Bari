extends Node2D

func _ready() -> void:
	var hud := PlayerHUD.new()
	add_child(hud)
	# TileMap을 최하위 레이어로 고정 — 플레이어/적이 음수 y에서도 타일 앞에 렌더링되도록
	$TileMap.z_index = -4096
