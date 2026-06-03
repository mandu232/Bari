extends CanvasLayer
class_name ArtifactInventoryUI
## 보유 유물 인벤토리 팝업
## 목록(왼쪽) + 상세(오른쪽) 레이아웃 — 코드로 빌드

var _font: Font = null

# ── 노드 참조 (build 후 보관)
var _count_label: Label         = null
var _item_list:   ItemList      = null
var _detail_vbox: VBoxContainer = null

# ── 현재 표시 중인 유물 목록 (open 시 스냅샷)
var _artifacts: Array = []

# ───────────────────────────────
#  READY
# ───────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 11
	_font = load("res://AutoLoad/assets/Font/DungGeunMo.ttf")
	_build_layout()
	hide()

func open() -> void:
	_refresh()
	show()

func close() -> void:
	hide()

# ───────────────────────────────
#  레이아웃 빌드
# ───────────────────────────────
func _build_layout() -> void:
	# 반투명 오버레이
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color        = Color(0, 0, 0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# 메인 패널 (940 × 580)
	var panel := Panel.new()
	panel.offset_left   = 170.0
	panel.offset_top    = 70.0
	panel.offset_right  = 1110.0
	panel.offset_bottom = 650.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(outer_vbox)

	# ── 타이틀 행
	var title_hbox := HBoxContainer.new()
	outer_vbox.add_child(title_hbox)

	var title_lbl := Label.new()
	title_lbl.text                = "인벤토리"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_font(title_lbl, 20)
	title_hbox.add_child(title_lbl)

	_count_label = Label.new()
	_count_label.text                  = ""
	_count_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.modulate              = Color(0.75, 0.75, 0.75)
	_set_font(_count_label, 15)
	title_hbox.add_child(_count_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(close)
	_set_font(close_btn, 16)
	title_hbox.add_child(close_btn)

	outer_vbox.add_child(HSeparator.new())

	# ── 콘텐츠 행 (목록 | 상세)
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 8)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_hbox)

	# ── 왼쪽: 유물 목록 (280px)
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(280, 0)
	left_vbox.add_theme_constant_override("separation", 4)
	content_hbox.add_child(left_vbox)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical     = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode  = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(list_scroll)

	_item_list = ItemList.new()
	_item_list.custom_minimum_size   = Vector2(272, 0)
	_item_list.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_item_list.icon_mode             = ItemList.ICON_MODE_LEFT
	_item_list.fixed_icon_size       = Vector2i(36, 36)
	_item_list.icon_scale            = 1.0
	_item_list.item_selected.connect(_on_item_selected)
	_set_font(_item_list, 15)
	list_scroll.add_child(_item_list)

	# 구분선
	content_hbox.add_child(VSeparator.new())

	# ── 오른쪽: 상세 패널 (스크롤 가능)
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_hbox.add_child(right_scroll)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_theme_constant_override("separation", 6)
	right_scroll.add_child(_detail_vbox)

# ───────────────────────────────
#  목록 갱신 (open 시 호출)
# ───────────────────────────────
func _refresh() -> void:
	_artifacts = GameManager.artifacts.duplicate()
	_item_list.clear()
	_clear_detail()

	_count_label.text = "보유 유물: %d개" % _artifacts.size()

	if _artifacts.is_empty():
		_item_list.add_item("보유한 유물이 없습니다")
		return

	for data: ArtifactData in _artifacts:
		if data == null:
			continue
		if data.texture:
			_item_list.add_item(data.artifact_name, data.texture)
		else:
			_item_list.add_item(data.artifact_name)

# ───────────────────────────────
#  항목 선택 → 상세 패널 빌드
# ───────────────────────────────
func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _artifacts.size():
		return
	_build_detail(_artifacts[index] as ArtifactData)

func _build_detail(data: ArtifactData) -> void:
	_clear_detail()
	if data == null:
		return

	# ── 이미지 행 (유물 + 에코 나란히)
	var img_hbox := HBoxContainer.new()
	img_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	img_hbox.add_theme_constant_override("separation", 24)
	_detail_vbox.add_child(img_hbox)

	# 유물 이미지 + 캡션
	var art_vbox := VBoxContainer.new()
	art_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	img_hbox.add_child(art_vbox)

	if data.texture:
		var art_img := TextureRect.new()
		art_img.texture               = data.texture
		art_img.custom_minimum_size   = Vector2(96, 96)
		art_img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		art_vbox.add_child(art_img)

	var art_cap := Label.new()
	art_cap.text                = "유물"
	art_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_cap.modulate             = Color(0.65, 0.65, 0.65)
	_set_font(art_cap, 12)
	art_vbox.add_child(art_cap)

	# 에코 이미지 + 캡션
	var echo_vbox := VBoxContainer.new()
	echo_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	img_hbox.add_child(echo_vbox)

	if data.echo_frames != null \
			and data.echo_frames.has_animation(&"float") \
			and data.echo_frames.get_frame_count(&"float") > 0:
		var echo_img := TextureRect.new()
		echo_img.texture               = data.echo_frames.get_frame_texture(&"float", 0)
		echo_img.custom_minimum_size   = Vector2(96, 96)
		echo_img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		echo_img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		echo_vbox.add_child(echo_img)

	var echo_cap := Label.new()
	echo_cap.text                = "에코"
	echo_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	echo_cap.modulate             = Color(0.65, 0.65, 0.65)
	_set_font(echo_cap, 12)
	echo_vbox.add_child(echo_cap)

	_detail_vbox.add_child(HSeparator.new())

	# ── 이름 / 에코 이름
	_add_label(data.artifact_name, 20, Color.WHITE)
	_add_label("에코:  %s" % data.echo_name, 15, Color(0.75, 0.9, 1.0))
	_add_label("영력/초:  %.2f" % data.essence_per_second, 14, Color(0.9, 1.0, 0.55))

	_detail_vbox.add_child(HSeparator.new())

	# ── 획득 시 확정된 플레이어 스탯 보너스
	_add_label("── 플레이어 스탯 보너스 ──", 14, Color(1.0, 0.85, 0.5))

	var has_stat := false
	if data.bonus_max_health > 0:
		_add_label("체력       +%d" % data.bonus_max_health, 14, Color(1.0, 0.72, 0.45))
		has_stat = true
	if data.bonus_attack > 0:
		_add_label("공격력     +%d" % data.bonus_attack, 14, Color(1.0, 0.72, 0.45))
		has_stat = true
	if data.bonus_attack_speed > 0:
		_add_label("공격속도  +%d%%" % data.bonus_attack_speed, 14, Color(1.0, 0.72, 0.45))
		has_stat = true
	if data.bonus_defense > 0:
		_add_label("방어력     +%d" % data.bonus_defense, 14, Color(1.0, 0.72, 0.45))
		has_stat = true
	if data.bonus_move_speed > 0.0:
		_add_label("이동속도  +%.1f" % data.bonus_move_speed, 14, Color(1.0, 0.72, 0.45))
		has_stat = true
	if not has_stat:
		_add_label("없음", 14, Color(0.6, 0.6, 0.6))

	_detail_vbox.add_child(HSeparator.new())

	# ── 설명
	var desc := data.passive_description if data.passive_description != "" else data.description
	if desc != "":
		_add_label(desc, 13, Color(0.82, 0.82, 0.82))

# ───────────────────────────────
#  헬퍼
# ───────────────────────────────
func _clear_detail() -> void:
	for child in _detail_vbox.get_children():
		child.queue_free()

func _add_label(text: String, font_size: int, color: Color = Color.WHITE) -> void:
	var lbl := Label.new()
	lbl.text          = text
	lbl.modulate      = color
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_font(lbl, font_size)
	_detail_vbox.add_child(lbl)

func _set_font(node: Control, size: int) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
		node.add_theme_font_size_override("font_size", size)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			close()
