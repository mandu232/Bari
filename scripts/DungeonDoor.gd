extends Node2D
class_name DungeonDoor

const FONT := preload("res://AutoLoad/assets/Font/DungGeunMo.ttf")

var _unlocked:      bool  = false
var _player_nearby: bool  = false
var _pulse_time:    float = 0.0

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

func _process(delta: float) -> void:
	z_as_relative = false
	z_index = int(global_position.y)
	if _unlocked:
		_pulse_time += delta
		var glow := 0.85 + sin(_pulse_time * 2.6) * 0.15
		_sprite.modulate = Color(glow * 1.1, glow, glow * 0.65, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if not _unlocked or not _player_nearby:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.keycode == KEY_E and ke.pressed and not ke.echo:
			get_viewport().set_input_as_handled()
			_enter_next_stage()

# 던전 클리어 시 Dungeon.gd에서 호출
func open() -> void:
	if _unlocked:
		return
	_unlocked = true
	_sprite.region_rect = Rect2(0, 0, 48, 64)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(2.0, 1.8, 0.6, 1.0), 0.10) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if _player_nearby:
		_hint_label.visible = true

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_nearby = true
	if _unlocked:
		_hint_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_nearby = false
	_hint_label.visible = false

func _enter_next_stage() -> void:
	_hint_label.visible = false
	_player_nearby = false
	set_process(false)
	set_process_unhandled_input(false)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.15) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): DungeonRunner.next_room())
