extends CanvasLayer
class_name TalismanSwapUI
## 부적 획득 UI — 부적 정보(이미지·설명·스탯)와 장착 슬롯을 보여준다
## 빈 슬롯이 있어도 어느 칸에 넣을지 직접 선택, 차 있으면 교체

const FONT := preload("res://AutoLoad/assets/Font/DungGeunMo.ttf")

var _new_data:    TalismanData = null
var _source_card: Node         = null

func setup(new_data: TalismanData, source_card: Node) -> void:
	_new_data    = new_data
	_source_card = source_card

func _ready() -> void:
	layer        = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

# ─────────────────────────────────────────────
#  UI 구성
# ─────────────────────────────────────────────
func _build_ui() -> void:
	# 반투명 오버레이
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color        = Color(0.0, 0.0, 0.0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 중앙 패널 (640 × 420)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	panel.offset_left     = -320
	panel.offset_right    =  320
	panel.offset_top      = -210
	panel.offset_bottom   =  210

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.06, 0.11, 0.97)
	panel_style.set_corner_radius_all(10)
	panel_style.border_color = Color(0.55, 0.45, 0.20, 0.95)
	panel_style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   26)
	margin.add_theme_constant_override("margin_right",  26)
	margin.add_theme_constant_override("margin_top",    22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 16)
	margin.add_child(root_vbox)

	# ── 상단: 새 부적 정보 ─────────────────────────
	var info_hbox := HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 22)
	root_vbox.add_child(info_hbox)

	# 큰 아이콘 영역 (100×100) — Control 사용으로 흰 박스 없음
	var icon_panel := Control.new()
	icon_panel.custom_minimum_size = Vector2(100, 100)
	info_hbox.add_child(icon_panel)

	if _new_data and _new_data.icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture       = _new_data.icon
		icon_rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.offset_left   = 10
		icon_rect.offset_top    = 10
		icon_rect.offset_right  = -10
		icon_rect.offset_bottom = -10
		icon_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		icon_panel.add_child(icon_rect)

	# 텍스트 정보 (이름 · 설명 · 스탯)
	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 7)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_hbox.add_child(text_vbox)

	# 이름
	var name_lbl := Label.new()
	name_lbl.text    = _new_data.talisman_name if _new_data else "부적"
	name_lbl.modulate = (_new_data.card_color.lightened(0.35) if _new_data else Color.WHITE)
	_set_font(name_lbl, 24)
	text_vbox.add_child(name_lbl)

	# 설명
	if _new_data and _new_data.description != "":
		var desc_lbl := Label.new()
		desc_lbl.text          = _new_data.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.modulate      = Color(0.78, 0.78, 0.78)
		_set_font(desc_lbl, 12)
		text_vbox.add_child(desc_lbl)

	# 스탯 요약
	if _new_data:
		var stat_str := _new_data.get_stat_summary()
		if stat_str.strip_edges() != "":
			var stat_lbl := Label.new()
			stat_lbl.text     = stat_str
			stat_lbl.modulate = Color(1.0, 0.85, 0.30)
			_set_font(stat_lbl, 13)
			text_vbox.add_child(stat_lbl)

	root_vbox.add_child(HSeparator.new())

	# ── 슬롯 선택 ─────────────────────────────────
	var slot_title := Label.new()
	slot_title.text                = "장착할 슬롯을 선택하세요"
	slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_title.modulate            = Color(1.0, 0.88, 0.45)
	_set_font(slot_title, 15)
	root_vbox.add_child(slot_title)

	var btns_hbox := HBoxContainer.new()
	btns_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btns_hbox.add_theme_constant_override("separation", 14)
	root_vbox.add_child(btns_hbox)

	# 슬롯 3개 버튼
	for i in TalismanManager.MAX_SLOTS:
		btns_hbox.add_child(_make_slot_button(i))

	# 버리기
	var discard_vbox := VBoxContainer.new()
	discard_vbox.add_theme_constant_override("separation", 4)
	btns_hbox.add_child(discard_vbox)

	var discard_spacer := Label.new()
	discard_spacer.text = ""
	_set_font(discard_spacer, 11)
	discard_vbox.add_child(discard_spacer)

	var discard_btn := Button.new()
	discard_btn.text                = "버리기"
	discard_btn.custom_minimum_size = Vector2(80, 110)
	discard_btn.focus_mode          = Control.FOCUS_NONE
	discard_btn.modulate            = Color(0.55, 0.55, 0.55)
	discard_btn.pressed.connect(func(): _on_choice(-1))
	_set_font(discard_btn, 13)
	discard_vbox.add_child(discard_btn)

	var discard_lbl := Label.new()
	discard_lbl.text                = "보내기"
	discard_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_lbl.modulate            = Color(0.45, 0.45, 0.45)
	_set_font(discard_lbl, 11)
	discard_vbox.add_child(discard_lbl)

# ─────────────────────────────────────────────
#  슬롯 버튼 (이미지 표시)
# ─────────────────────────────────────────────
func _make_slot_button(index: int) -> Control:
	var equipped   := TalismanManager.equipped
	var occupied   := index < equipped.size()
	var slot_data  := (equipped[index] as TalismanData) if occupied else null

	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)

	# 슬롯 번호 라벨
	var slot_lbl := Label.new()
	slot_lbl.text                = "슬롯 %d" % (index + 1)
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_lbl.modulate            = Color(0.65, 0.65, 0.65)
	_set_font(slot_lbl, 11)
	wrap.add_child(slot_lbl)

	# 버튼 본체
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(110, 110)
	btn.focus_mode          = Control.FOCUS_NONE
	btn.pressed.connect(func(): _on_choice(index))

	var btn_style := StyleBoxFlat.new()
	if occupied:
		btn_style.bg_color    = slot_data.card_color.darkened(0.52)
		btn_style.border_color = slot_data.card_color
		btn_style.set_border_width_all(2)
	else:
		btn_style.bg_color    = Color(0.13, 0.11, 0.09, 0.95)
		btn_style.border_color = Color(0.55, 0.45, 0.20, 0.55)
		btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(6)
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, btn_style)
	wrap.add_child(btn)

	# 버튼 내용 (이미지 또는 "빈 슬롯")
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 4)
	inner.alignment    = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(inner)

	if occupied:
		if slot_data.icon != null:
			var img := TextureRect.new()
			img.texture               = slot_data.icon
			img.custom_minimum_size   = Vector2(60, 60)
			img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			img.mouse_filter          = Control.MOUSE_FILTER_IGNORE
			inner.add_child(img)
		else:
			var ch := Label.new()
			ch.text                = slot_data.talisman_name.substr(0, 1)
			ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ch.modulate            = slot_data.card_color.lightened(0.3)
			ch.mouse_filter        = Control.MOUSE_FILTER_IGNORE
			_set_font(ch, 30)
			inner.add_child(ch)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text                = "빈\n슬롯"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate            = Color(0.38, 0.38, 0.38)
		empty_lbl.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		_set_font(empty_lbl, 14)
		inner.add_child(empty_lbl)

	# 이름 (슬롯 아래)
	var name_lbl := Label.new()
	name_lbl.text                = slot_data.talisman_name if occupied else "비어있음"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.modulate            = (slot_data.card_color.lightened(0.2) if occupied else Color(0.38, 0.38, 0.38))
	name_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	_set_font(name_lbl, 11)
	wrap.add_child(name_lbl)

	return wrap

# ─────────────────────────────────────────────
#  선택 처리
# ─────────────────────────────────────────────
func _on_choice(slot_index: int) -> void:
	if is_instance_valid(_source_card) and _source_card.has_method("on_swap_confirmed"):
		_source_card.call("on_swap_confirmed", slot_index)
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_choice(-1)

# ─────────────────────────────────────────────
#  폰트 헬퍼
# ─────────────────────────────────────────────
func _set_font(node: Control, size: int) -> void:
	node.add_theme_font_override("font",           FONT)
	node.add_theme_font_size_override("font_size", size)
