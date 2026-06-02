extends CanvasLayer
class_name PlayerStatsUI
## 플레이어 현재 스탯을 표시하는 패널

const STAT_ICON_PATHS := {
	"atk":     "res://AutoLoad/assets/Stats/icon_atk.png",
	"atk_spd": "res://AutoLoad/assets/Stats/icon_atk_spd.png",
	"def":     "res://AutoLoad/assets/Stats/icon_def.png",
	"spd":     "res://AutoLoad/assets/Stats/icon_move_spd.png",
	"hp":      "res://AutoLoad/assets/Stats/icon_hp.png",
}

@onready var _stats_container: VBoxContainer = $Panel/VBox/StatsContainer
@onready var _close_btn:       Button        = $Panel/VBox/CloseButton

var _font: Font = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_font = load("res://AutoLoad/assets/Font/DungGeunMo.ttf")
	_close_btn.pressed.connect(close)

func open() -> void:
	_refresh_stats()
	show()

func close() -> void:
	hide()

# ───────────────────────────────
#  스탯 갱신
# ───────────────────────────────
func _refresh_stats() -> void:
	for child in _stats_container.get_children():
		child.queue_free()

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		var err_lbl := Label.new()
		err_lbl.text = "플레이어를 찾을 수 없습니다"
		_set_font(err_lbl, 16)
		_stats_container.add_child(err_lbl)
		return

	var rows: Array = [
		["atk",     "공격력",   "%d"         % player.get("attack_damage")],
		["atk_spd", "공격속도", "%d%%"       % player.get("attack_speed")],
		["hp",      "체력",     "%d / %d"    % [player.get("health"), player.get("max_health")]],
		["def",     "방어력",   "%d"         % player.get("defense")],
		["spd",     "이동속도", "%.1f"       % player.get("move_speed")],
	]

	for row in rows:
		_stats_container.add_child(_make_stat_row(row[0], row[1], row[2]))

# ───────────────────────────────
#  행 생성 (아이콘 + 이름 + 값)
# ───────────────────────────────
func _make_stat_row(icon_key: String, stat_name: String, value_str: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# 아이콘 (24×24)
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(24, 24)
	tex_rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_path: String = STAT_ICON_PATHS.get(icon_key, "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		tex_rect.texture = load(icon_path)
	row.add_child(tex_rect)

	# 스탯 이름
	var name_lbl := Label.new()
	name_lbl.text                = stat_name
	name_lbl.custom_minimum_size = Vector2(80, 0)
	_set_font(name_lbl, 18)
	row.add_child(name_lbl)

	# 수치 (연두색)
	var val_lbl := Label.new()
	val_lbl.text     = value_str
	val_lbl.modulate = Color(0.85, 1.0, 0.65)
	_set_font(val_lbl, 18)
	row.add_child(val_lbl)

	return row

func _set_font(node: Control, size: int) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
		node.add_theme_font_size_override("font_size", size)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			close()
