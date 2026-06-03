extends CanvasLayer
class_name PlayerHUD
## 플레이어 체력·마나 바 HUD (좌측 상단)

var _hp_bar:   ProgressBar = null
var _hp_label: Label       = null
var _mp_bar:   ProgressBar = null
var _mp_label: Label       = null
var _font:     Font        = null

var _player_connected: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 9
	_font        = load("res://AutoLoad/assets/Font/DungGeunMo.ttf")
	_build_layout()

func _process(_delta: float) -> void:
	if not _player_connected:
		_try_connect_player()

# ───────────────────────────────
#  레이아웃
# ───────────────────────────────
func _build_layout() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left   = 0.0
	panel.anchor_right  = 0.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left   = 12
	panel.offset_top    = 12
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(210, 0)
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	vbox.add_child(_make_bar_row(true))
	vbox.add_child(_make_bar_row(false))

func _make_bar_row(is_hp: bool) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)

	# 라벨 행 (아이콘 텍스트 + 수치)
	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var icon_lbl := Label.new()
	icon_lbl.text     = "HP" if is_hp else "MP"
	icon_lbl.modulate = Color(1.0, 0.45, 0.45) if is_hp else Color(0.4, 0.65, 1.0)
	_apply_font(icon_lbl, 13)
	top_row.add_child(icon_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var val_lbl := Label.new()
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_font(val_lbl, 13)
	top_row.add_child(val_lbl)

	# 바
	var bar := ProgressBar.new()
	bar.min_value         = 0
	bar.max_value         = 100
	bar.value             = 100
	bar.show_percentage   = false
	bar.custom_minimum_size       = Vector2(0, 14)
	bar.size_flags_horizontal     = Control.SIZE_EXPAND_FILL

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.85, 0.3) if is_hp else Color(0.3, 0.55, 1.0)
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.12, 0.85)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)

	vbox.add_child(bar)

	if is_hp:
		_hp_bar   = bar
		_hp_label = val_lbl
	else:
		_mp_bar   = bar
		_mp_label = val_lbl

	return vbox

# ───────────────────────────────
#  플레이어 연결
# ───────────────────────────────
func _try_connect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_player_connected = true
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.get("health"), player.get("max_health"))
	if player.has_signal("mana_changed"):
		player.mana_changed.connect(_on_mana_changed)
		_on_mana_changed(player.get("mana"), player.get("max_mana"))

# ───────────────────────────────
#  콜백
# ───────────────────────────────
func _on_health_changed(current: int, maximum: int) -> void:
	if _hp_bar:
		_hp_bar.max_value = maximum
		_hp_bar.value     = current
		# 비율에 따라 색상 변경
		var ratio := float(current) / float(maximum) if maximum > 0 else 0.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = (
			Color(0.2, 0.85, 0.3)  if ratio > 0.5  else
			Color(1.0, 0.75, 0.1)  if ratio > 0.25 else
			Color(0.9, 0.2, 0.15)
		)
		fill.set_corner_radius_all(3)
		_hp_bar.add_theme_stylebox_override("fill", fill)
	if _hp_label:
		_hp_label.text = "%d / %d" % [current, maximum]

func _on_mana_changed(current: float, maximum: int) -> void:
	if _mp_bar:
		_mp_bar.max_value = maximum
		_mp_bar.value     = current
	if _mp_label:
		_mp_label.text = "%.0f / %d" % [current, maximum]

func _apply_font(node: Control, size: int) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
		node.add_theme_font_size_override("font_size", size)
