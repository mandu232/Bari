extends CanvasLayer
class_name PlayerHUD
## 플레이어 체력·마나 바 HUD (좌측 상단)

var _hp_bar:   ProgressBar = null
var _hp_label: Label       = null
var _mp_bar:   ProgressBar = null
var _mp_label: Label       = null
var _font:     Font        = null

var _coin_label: Label        = null
var _coin_panel: PanelContainer = null
var _last_coins: int          = -1

var _player_connected:   bool  = false
var _talisman_panel:     Control = null
var _talisman_cells:     Array  = []   # Array[Control], 슬롯 3개
var _shield_indicator:   Label  = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 9
	_font        = load("res://AutoLoad/assets/Font/DungGeunMo.ttf")
	_build_layout()
	_build_coin_counter()
	_build_talisman_slots()
	TalismanManager.talisman_changed.connect(_refresh_talisman_slots)
	add_to_group("player_hud")

func _process(_delta: float) -> void:
	if not _player_connected:
		_try_connect_player()
	# 코인/부적 패널은 던전 런 중에만 표시
	var in_run: bool = GameManager.current_run_active
	if _coin_panel and _coin_panel.visible != in_run:
		_coin_panel.visible = in_run
	# 부적 패널은 런 중이고 하나라도 장착됐을 때만 표시
	var show_talisman: bool = in_run and not TalismanManager.equipped.is_empty()
	if _talisman_panel and _talisman_panel.visible != show_talisman:
		_talisman_panel.visible = show_talisman
	# 코인 수 변경 시 갱신
	if in_run:
		var coins: int = GameManager.dungeon_coins
		if coins != _last_coins:
			_last_coins = coins
			if _coin_label:
				_coin_label.text = "● %d" % coins

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

# ───────────────────────────────
#  부적 슬롯 (우측 하단)
# ───────────────────────────────
func _build_talisman_slots() -> void:
	# 배경 없는 VBoxContainer — 아이콘만 우측 하단에 세로로 쌓임
	var container := HBoxContainer.new()
	_talisman_panel = container
	container.visible           = false
	container.anchor_left       = 1.0
	container.anchor_right      = 1.0
	container.anchor_top        = 1.0
	container.anchor_bottom     = 1.0
	container.grow_horizontal   = Control.GROW_DIRECTION_BEGIN
	container.grow_vertical     = Control.GROW_DIRECTION_BEGIN
	container.offset_right      = -12
	container.offset_bottom     = -12
	container.add_theme_constant_override("separation", 5)
	add_child(container)

	_talisman_cells.clear()
	for _i in TalismanManager.MAX_SLOTS:
		var cell := _make_talisman_cell()
		cell.visible = false
		container.add_child(cell)
		_talisman_cells.append(cell)

	_refresh_talisman_slots()

func _make_talisman_cell() -> TextureRect:
	# 원본 36×64 의 3배(108×192), 비율 유지
	var icon_rect := TextureRect.new()
	icon_rect.stretch_mode       = TextureRect.STRETCH_KEEP_ASPECT
	icon_rect.custom_minimum_size = Vector2(72, 128)
	icon_rect.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	icon_rect.visible            = false
	return icon_rect

func _refresh_talisman_slots() -> void:
	var equipped := TalismanManager.equipped

	# 패널: 런 중이고 하나라도 장착됐을 때만
	if _talisman_panel:
		_talisman_panel.visible = GameManager.current_run_active and not equipped.is_empty()

	for i in _talisman_cells.size():
		var icon_rect := _talisman_cells[i] as TextureRect
		if icon_rect == null:
			continue

		if i >= equipped.size():
			icon_rect.visible = false
			continue

		# 장착됨 → 이미지 원본 크기로 표시
		var data := equipped[i] as TalismanData
		icon_rect.texture = data.icon
		icon_rect.visible = (data.icon != null)
		# 방어막 활성 시 황금 틴트, 소진 시 회색
		if data.effect == TalismanData.Effect.SHIELD:
			icon_rect.modulate = Color(1.0, 1.0, 0.4) if TalismanManager.is_shield_active() \
							  else Color(0.45, 0.45, 0.45)
		else:
			icon_rect.modulate = Color.WHITE

# ───────────────────────────────
#  코인 카운터 (우측 상단)
# ───────────────────────────────
func _build_coin_counter() -> void:
	var panel := PanelContainer.new()
	_coin_panel = panel
	panel.visible = false   # 던전 런 중에만 표시
	panel.anchor_left    = 1.0
	panel.anchor_right   = 1.0
	panel.anchor_top     = 0.0
	panel.anchor_bottom  = 0.0
	panel.offset_right   = -12
	panel.offset_top     = 12
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.06, 0.02, 0.82)
	bg.set_corner_radius_all(5)
	bg.border_color = Color(1.0, 0.78, 0.08, 0.7)
	bg.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_bottom",  8)
	panel.add_child(margin)

	_coin_label = Label.new()
	_coin_label.text                 = "● 0"
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coin_label.modulate             = Color(1.0, 0.85, 0.1)
	_apply_font(_coin_label, 14)
	_coin_label.add_theme_color_override("font_shadow_color",  Color(0.0, 0.0, 0.0, 0.9))
	_coin_label.add_theme_constant_override("shadow_offset_x", 1)
	_coin_label.add_theme_constant_override("shadow_offset_y", 1)
	margin.add_child(_coin_label)
