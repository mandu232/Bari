extends CanvasLayer
class_name MuseumHQUI
## 박물관 본관 관리 UI — 화면 90% 크기 패널

signal closed

var _hq:      MuseumHQ      = null
var _font:    Font          = null
var _content: VBoxContainer = null
var _panel:   PanelContainer = null

# ─── 초기화 ──────────────────────────────────────────────────────────
func setup(hq: MuseumHQ) -> void:
	_hq   = hq
	_font = load("res://AutoLoad/assets/Font/DungGeunMo.ttf") as Font
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_skeleton()
	visible = false

func open() -> void:
	_rebuild_content()
	visible = true

# ─── 뼈대 (한 번만 생성) ─────────────────────────────────────────────
func _build_skeleton() -> void:
	# 반투명 전체 화면 배경
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.50)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# 화면 전체 크기 컨테이너
	var fullrect := Control.new()
	fullrect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fullrect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fullrect)

	# 패널 — 화면의 90% 차지 (앵커 기반)
	_panel = PanelContainer.new()
	_panel.anchor_left   = 0.05
	_panel.anchor_top    = 0.05
	_panel.anchor_right  = 0.95
	_panel.anchor_bottom = 0.95
	var style := StyleBoxFlat.new()
	style.bg_color              = Color(0.07, 0.05, 0.04, 0.97)
	style.border_color          = Color(0.85, 0.65, 0.20, 0.90)
	style.border_width_left     = 2
	style.border_width_right    = 2
	style.border_width_top      = 2
	style.border_width_bottom   = 2
	style.content_margin_left   = 30
	style.content_margin_right  = 30
	style.content_margin_top    = 24
	style.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", style)
	fullrect.add_child(_panel)

	# 패널 내부: 세로 레이아웃
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_content)

# ─── 내용 재구성 ─────────────────────────────────────────────────────
func _rebuild_content() -> void:
	for ch in _content.get_children():
		ch.queue_free()

	var lv     := GameManager.museum_hq_level
	var max_lv := _hq.MAX_LEVEL
	var is_max := lv >= max_lv
	var nxt    := lv + 1 if not is_max else lv

	# ─── 타이틀 ───────────────────────────────────────────────────────
	var stars := "★".repeat(lv) + "☆".repeat(max_lv - lv)
	_add_label("박물관 본관   %s" % stars, 20, Color(1.0, 0.85, 0.30))
	_add_label("현재 레벨:  Lv.%d" % lv, 13, Color(0.72, 0.72, 0.72))
	_add_sep()

	if is_max:
		# ─── 최대 레벨 ────────────────────────────────────────────────
		_add_label("✦  최대 레벨 달성", 16, Color(1.0, 0.90, 0.40))
		_add_sep()
		_add_label("현재 효과", 13, Color(0.80, 0.80, 0.80))

		var stats_box := HBoxContainer.new()
		stats_box.add_theme_constant_override("separation", 50)
		_content.add_child(stats_box)

		var left := _make_section_vbox()
		stats_box.add_child(left)
		_section_row(left, "영력 생산",   "×%.1f" % _hq.LEVEL_MULT[lv],                    null)
		_section_row(left, "전시대 한도", "%d개"  % GameManager.max_dynamic_artifact_slots, null)

		var right := _make_section_vbox()
		stats_box.add_child(right)
		_section_row(right, "최대 체력", "+%d"   % _sum_i(_hq.LEVEL_HEALTH, lv), null)
		_section_row(right, "공격력",    "+%d"   % _sum_i(_hq.LEVEL_DAMAGE, lv), null)
		if _sum_f(_hq.LEVEL_SPEED, lv) > 0.0:
			_section_row(right, "이동속도", "+%.1f" % _sum_f(_hq.LEVEL_SPEED, lv), null)

		_add_spacer()
		_add_sep()
		_add_buttons(null, "닫기")

	else:
		# ─── 두 열 레이아웃 (박물관 강화 / 플레이어 강화) ─────────────
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 40)
		cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content.add_child(cols)

		# 왼쪽 열 — 박물관 강화
		var left_wrap := _make_col_panel(Color(0.10, 0.18, 0.10, 0.70), Color(0.40, 0.80, 0.45, 0.60))
		cols.add_child(left_wrap)

		var left := _make_section_vbox()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_wrap.add_child(left)

		_section_header(left, "▣  박물관 강화", Color(0.45, 1.00, 0.55))
		_section_sep(left)
		_section_row(left, "영력 생산",
			"×%.1f" % _hq.LEVEL_MULT[lv],
			"×%.1f" % _hq.LEVEL_MULT[nxt])
		_section_row(left, "전시대 한도",
			"%d개"  % GameManager.max_dynamic_artifact_slots,
			"%d개"  % (GameManager.max_dynamic_artifact_slots + _hq.LEVEL_SLOTS[nxt]))

		# 오른쪽 열 — 플레이어 강화
		var right_wrap := _make_col_panel(Color(0.08, 0.12, 0.22, 0.70), Color(0.40, 0.55, 0.90, 0.60))
		cols.add_child(right_wrap)

		var right := _make_section_vbox()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_wrap.add_child(right)

		_section_header(right, "▣  플레이어 강화", Color(0.50, 0.75, 1.00))
		_section_sep(right)
		_section_row(right, "최대 체력",
			"+%d" % _sum_i(_hq.LEVEL_HEALTH, lv),
			"+%d" % (_sum_i(_hq.LEVEL_HEALTH, lv) + _hq.LEVEL_HEALTH[nxt]))
		if _sum_i(_hq.LEVEL_DAMAGE, lv) > 0 or _hq.LEVEL_DAMAGE[nxt] > 0:
			_section_row(right, "공격력",
				"+%d" % _sum_i(_hq.LEVEL_DAMAGE, lv),
				"+%d" % (_sum_i(_hq.LEVEL_DAMAGE, lv) + _hq.LEVEL_DAMAGE[nxt]))
		if _sum_f(_hq.LEVEL_SPEED, lv) > 0.0 or _hq.LEVEL_SPEED[nxt] > 0.0:
			_section_row(right, "이동속도",
				"+%.1f" % _sum_f(_hq.LEVEL_SPEED, lv),
				"+%.1f" % (_sum_f(_hq.LEVEL_SPEED, lv) + _hq.LEVEL_SPEED[nxt]))

		# ─── 비용 + 버튼 ──────────────────────────────────────────────
		_add_sep()
		var cost       := _hq.UPGRADE_COST[nxt]
		var affordable := GameManager.echo_essence >= cost
		var cost_col   := Color(1.0, 0.85, 0.30) if affordable else Color(1.0, 0.35, 0.35)
		_add_label("업그레이드 비용:  영력 %d" % cost, 13, cost_col)
		_add_buttons("Lv.%d 업그레이드" % nxt if affordable else "영력 부족", "닫기", affordable)

# ─── 레이아웃 헬퍼 ───────────────────────────────────────────────────
func _make_col_panel(bg: Color, border: Color) -> PanelContainer:
	var pc  := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	var st := StyleBoxFlat.new()
	st.bg_color             = bg
	st.border_color         = border
	st.border_width_left    = 1
	st.border_width_right   = 1
	st.border_width_top     = 1
	st.border_width_bottom  = 1
	st.content_margin_left  = 20
	st.content_margin_right = 20
	st.content_margin_top   = 16
	st.content_margin_bottom = 16
	pc.add_theme_stylebox_override("panel", st)
	return pc

func _make_section_vbox() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	return vb

func _section_header(parent: VBoxContainer, text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", col)
	if _font:
		lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", 14)
	parent.add_child(lbl)

func _section_sep(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.85, 0.65, 0.2, 0.25))
	parent.add_child(sep)

func _section_row(parent: VBoxContainer, label: String, current: String, next_val) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	if _font:
		lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(lbl)

	var cur := Label.new()
	cur.text = current
	cur.add_theme_color_override("font_color",
		Color(0.68, 0.68, 0.68) if next_val != null else Color(1.0, 0.92, 0.50))
	if _font:
		cur.add_theme_font_override("font", _font)
		cur.add_theme_font_size_override("font_size", 12)
	hbox.add_child(cur)

	if next_val != null:
		var arrow := Label.new()
		arrow.text = "  →  "
		arrow.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30, 0.75))
		if _font:
			arrow.add_theme_font_override("font", _font)
			arrow.add_theme_font_size_override("font_size", 12)
		hbox.add_child(arrow)

		var nxt := Label.new()
		nxt.text = str(next_val)
		nxt.add_theme_color_override("font_color", Color(0.45, 1.00, 0.55))
		if _font:
			nxt.add_theme_font_override("font", _font)
			nxt.add_theme_font_size_override("font_size", 12)
		hbox.add_child(nxt)

# ─── 공통 UI 빌더 ────────────────────────────────────────────────────
func _add_label(text: String, size: int, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", col)
	if _font:
		lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", size)
	_content.add_child(lbl)

func _add_sep() -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.85, 0.65, 0.2, 0.35))
	_content.add_child(sep)

func _add_spacer() -> void:
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(sp)

func _add_buttons(upgrade_text, close_text: String, upgrade_enabled: bool = true) -> void:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 16)
	_content.add_child(hbox)

	if upgrade_text != null:
		var btn := _make_button(str(upgrade_text), true)
		btn.disabled = not upgrade_enabled
		btn.pressed.connect(_on_upgrade_pressed)
		hbox.add_child(btn)

	var close := _make_button(close_text, false)
	close.pressed.connect(_on_close_pressed)
	hbox.add_child(close)

func _make_button(text: String, is_primary: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(110, 0)
	if _font:
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 12)
	var accent := Color(0.85, 0.65, 0.20) if is_primary else Color(0.55, 0.50, 0.40)
	var normal := StyleBoxFlat.new()
	normal.bg_color             = Color(0.16, 0.12, 0.05, 0.92) if is_primary else Color(0.12, 0.11, 0.09, 0.90)
	normal.border_color         = accent.darkened(0.1)
	normal.border_width_left    = 1
	normal.border_width_right   = 1
	normal.border_width_top     = 1
	normal.border_width_bottom  = 1
	normal.content_margin_left  = 16
	normal.content_margin_right = 16
	normal.content_margin_top   = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color    = Color(0.28, 0.20, 0.07, 0.96) if is_primary else Color(0.22, 0.20, 0.16, 0.96)
	hover.border_color = accent
	var pressed_st := normal.duplicate() as StyleBoxFlat
	pressed_st.bg_color = Color(0.10, 0.08, 0.03, 0.96)
	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover)
	btn.add_theme_stylebox_override("pressed",  pressed_st)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_color_override("font_color",
		Color(1.0, 0.92, 0.50) if is_primary else Color(0.78, 0.76, 0.72))
	btn.add_theme_color_override("font_color_hover",
		Color(1.0, 0.98, 0.70) if is_primary else Color(0.92, 0.90, 0.86))
	btn.add_theme_color_override("font_color_pressed",  Color(0.75, 0.65, 0.28))
	btn.add_theme_color_override("font_color_disabled", Color(0.45, 0.42, 0.35))
	return btn

# ─── 콜백 ────────────────────────────────────────────────────────────
func _on_upgrade_pressed() -> void:
	_hq.try_upgrade()
	_rebuild_content()

func _on_close_pressed() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

# ─── 통계 합산 헬퍼 ──────────────────────────────────────────────────
func _sum_i(arr: Array, lv: int) -> int:
	var t := 0
	for i in range(1, lv + 1): t += arr[i]
	return t

func _sum_f(arr: Array, lv: int) -> float:
	var t := 0.0
	for i in range(1, lv + 1): t += arr[i]
	return t
