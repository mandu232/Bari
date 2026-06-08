extends Node2D
class_name DungeonDoor

const FONT := preload("res://AutoLoad/assets/Font/DungGeunMo.ttf")

var _unlocked:      bool  = false
var _player_nearby: bool  = false

@onready var _sprite:     Sprite2D = $Sprite2D
@onready var _hint_label: Label    = $HintLabel
@onready var _area:       Area2D   = $InteractArea

func _ready() -> void:
	_hint_label.add_theme_font_override("font", FONT)
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color",        Color(1.0, 0.95, 0.5))
	_hint_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	z_as_relative = false
	z_index = int(global_position.y)


# 던전 클리어 시 Dungeon.gd에서 호출
func open() -> void:
	if _unlocked:
		return
	_unlocked = true
	_sprite.region_rect = Rect2(0, 0, 48, 64)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_nearby = true
	if _unlocked:
		_enter_next_stage()

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_nearby = false

func _enter_next_stage() -> void:
	_hint_label.visible = false
	_player_nearby = false
	set_process(false)
	set_process_unhandled_input(false)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.15) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		var p := get_tree().get_first_node_in_group("player")
		if is_instance_valid(p):
			GameManager.player_current_health = p.health
		DungeonRunner.next_room()
	)
