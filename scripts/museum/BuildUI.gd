extends CanvasLayer
class_name BuildUI
## 건설 메뉴 UI — 씬 파일 없이 코드로 생성

signal item_selected(item: BuildableItem)
signal cancelled

var _font: Font                    = null
var _item_container: HBoxContainer = null

# ── 툴팁 노드
var _tooltip:              PanelContainer = null
var _tt_name:              Label          = null
var _tt_desc:              Label          = null
var _tt_cost_row:          Label          = null
var _tt_power_consume_row: Label          = null
var _tt_power_output_row:  Label          = null
var _tt_slot_row:          Label          = null

# ───────────────────────────────
#  READY
# ───────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font        = load("res://AutoLoad/assets/Font/DungGeunMo.ttf")
	_build_layout()
	_build_tooltip()
	hide()

# ───────────────────────────────
#  PUBLIC API
# ───────────────────────────────
func show_menu(items: Array[BuildableItem]) -> void:
	_populate(items)
	_hide_tooltip()
	show()

func close() -> void:
	_hide_tooltip()
	hide()

# ───────────────────────────────
#  LAYOUT 생성
# ───────────────────────────────
func _build_layout() -> void:
	# 하단 전체 패널
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -160.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# ── 헤더
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "건설 메뉴"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(title, 18)
	header.add_child(title)

	var hint := Label.new()
	hint.text = "클릭: 배치  |  B · ESC: 닫기"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate              = Color(0.75, 0.75, 0.75)
	_apply_font(hint, 13)
	header.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "✕"
	_apply_font(close_btn, 16)
	close_btn.pressed.connect(_on_cancel)
	header.add_child(close_btn)

	# ── 아이템 스크롤
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical       = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode    = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode      = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_item_container = HBoxContainer.new()
	_item_container.add_theme_constant_override("separation", 10)
	scroll.add_child(_item_container)

# ───────────────────────────────
#  툴팁 생성
# ───────────────────────────────
func _build_tooltip() -> void:
	_tooltip              = PanelContainer.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index      = 100
	add_child(_tooltip)

	var mg := MarginContainer.new()
	mg.add_theme_constant_override("margin_left",   10)
	mg.add_theme_constant_override("margin_right",  10)
	mg.add_theme_constant_override("margin_top",     8)
	mg.add_theme_constant_override("margin_bottom",  8)
	_tooltip.add_child(mg)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	mg.add_child(vb)

	# 이름
	_tt_name                    = Label.new()
	_tt_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(_tt_name, 15)
	vb.add_child(_tt_name)

	vb.add_child(HSeparator.new())

	# 설명
	_tt_desc                      = Label.new()
	_tt_desc.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	_tt_desc.custom_minimum_size   = Vector2(160, 0)
	_apply_font(_tt_desc, 12)
	vb.add_child(_tt_desc)

	vb.add_child(HSeparator.new())

	# 건설 비용
	_tt_cost_row          = Label.new()
	_tt_cost_row.modulate = Color(1.0, 0.85, 0.3)
	_apply_font(_tt_cost_row, 12)
	vb.add_child(_tt_cost_row)

	# 소모 전력
	_tt_power_consume_row          = Label.new()
	_tt_power_consume_row.modulate = Color(0.55, 0.85, 1.0)
	_apply_font(_tt_power_consume_row, 12)
	vb.add_child(_tt_power_consume_row)

	# 생산 전력
	_tt_power_output_row          = Label.new()
	_tt_power_output_row.modulate = Color(1.0, 0.95, 0.4)
	_apply_font(_tt_power_output_row, 12)
	vb.add_child(_tt_power_output_row)

	# 전시대 슬롯 수
	_tt_slot_row          = Label.new()
	_tt_slot_row.modulate = Color(0.55, 0.97, 0.80)
	_apply_font(_tt_slot_row, 12)
	vb.add_child(_tt_slot_row)

	_tooltip.hide()

func _show_tooltip(item: BuildableItem) -> void:
	_tt_name.text = item.item_name
	_tt_desc.text = item.description if item.description != "" else "—"
	_tt_cost_row.text = "건설 비용: %d 영력" % item.cost

	if item.power_consumption > 0:
		_tt_power_consume_row.text    = "소모 전력: %d" % item.power_consumption
		_tt_power_consume_row.visible = true
	else:
		_tt_power_consume_row.visible = false

	if item.power_output > 0:
		_tt_power_output_row.text    = "생산 전력: +%d" % item.power_output
		_tt_power_output_row.visible = true
	else:
		_tt_power_output_row.visible = false

	if item.is_artifact_stand:
		var placed := get_tree().get_nodes_in_group("placed_structure") \
			.filter(func(n: Node) -> bool: return n is ArtifactSlot).size()
		var max_slots := GameManager.max_dynamic_artifact_slots
		_tt_slot_row.text    = "전시대: %d / %d" % [placed, max_slots]
		_tt_slot_row.visible = true
	else:
		_tt_slot_row.visible = false

	_tooltip.show()

func _hide_tooltip() -> void:
	if _tooltip:
		_tooltip.hide()

# ───────────────────────────────
#  PROCESS — 툴팁 마우스 추적
# ───────────────────────────────
func _process(_delta: float) -> void:
	if _tooltip == null or not _tooltip.visible:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var vp_size   := get_viewport().get_visible_rect().size
	var tt_size   := _tooltip.size
	# 기본 위치: 마우스 우측 상단
	var pos       := mouse_pos + Vector2(14.0, -tt_size.y - 8.0)
	# 오른쪽 경계 벗어나면 왼쪽으로
	if pos.x + tt_size.x > vp_size.x:
		pos.x = mouse_pos.x - tt_size.x - 14.0
	# 위쪽 경계 벗어나면 아래로
	if pos.y < 0.0:
		pos.y = mouse_pos.y + 14.0
	_tooltip.position = pos

# ───────────────────────────────
#  아이템 카드 생성
# ───────────────────────────────
func _populate(items: Array[BuildableItem]) -> void:
	for c in _item_container.get_children():
		c.queue_free()
	for item in items:
		if item != null:
			_item_container.add_child(_make_card(item))

func _make_card(item: BuildableItem) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(110, 110)
	btn.pressed.connect(func(): _on_item_pressed(item))
	btn.mouse_entered.connect(func(): _show_tooltip(item))
	btn.mouse_exited.connect(_hide_tooltip)

	# 버튼 위에 VBoxContainer 올리기
	var vbox := VBoxContainer.new()
	vbox.alignment     = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(vbox)

	# 아이콘 영역 — 아이콘 크기에 무관하게 항상 64×64 로 고정
	var icon_area := Control.new()
	icon_area.custom_minimum_size   = Vector2(64, 64)
	icon_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_area.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	icon_area.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_area)

	if item.icon:
		var tex         := TextureRect.new()
		tex.texture      = item.icon
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_area.add_child(tex)

	var name_lbl                 := Label.new()
	name_lbl.text                 = item.item_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_apply_font(name_lbl, 13)
	vbox.add_child(name_lbl)

	var cost_lbl                 := Label.new()
	cost_lbl.text                 = "%d 영력" % item.cost
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.modulate             = Color(1.0, 0.85, 0.3)
	cost_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_apply_font(cost_lbl, 12)
	vbox.add_child(cost_lbl)

	return btn

func _apply_font(node: Control, size: int) -> void:
	if _font == null:
		return
	node.add_theme_font_override("font", _font)
	node.add_theme_font_size_override("font_size", size)

# ───────────────────────────────
#  CALLBACKS
# ───────────────────────────────
func _on_item_pressed(item: BuildableItem) -> void:
	item_selected.emit(item)
	close()

func _on_cancel() -> void:
	cancelled.emit()
	close()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("build_mode"):
		_on_cancel()
		get_viewport().set_input_as_handled()
