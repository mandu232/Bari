extends CanvasLayer
class_name EssenceUI
## 보유 영력 / 영력 생산량 표시 UI

var _essence_label: Label = null
var _rate_label:    Label = null
var _power_label:   Label = null
var _font: Font           = null

# ───────────────────────────────
#  READY
# ───────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font        = load("res://AutoLoad/assets/Font/DungGeunMo.ttf")
	_build_layout()
	GameManager.essence_changed.connect(_on_essence_changed)
	GameManager.essence_rate_changed.connect(_on_rate_changed)
	GameManager.power_changed.connect(_on_power_changed)
	_on_essence_changed(GameManager.spirit_essence)
	_on_rate_changed(GameManager.essence_rate)
	_on_power_changed(GameManager.used_power, GameManager.total_power)

# ───────────────────────────────
#  LAYOUT
# ───────────────────────────────
func _build_layout() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left   = 12
	panel.offset_top    = 12
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# ── 보유 영력 행
	var row1 := HBoxContainer.new()
	vbox.add_child(row1)

	var lbl1 := Label.new()
	lbl1.text = "보유 영력"
	_apply_font(lbl1, 16)
	row1.add_child(lbl1)

	_essence_label = Label.new()
	_essence_label.custom_minimum_size       = Vector2(90, 0)
	_essence_label.horizontal_alignment      = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_font(_essence_label, 16)
	row1.add_child(_essence_label)

	# ── 영력 생산량 행
	var row2 := HBoxContainer.new()
	vbox.add_child(row2)

	var lbl2 := Label.new()
	lbl2.text     = "영력 / 초"
	lbl2.modulate = Color(0.75, 0.9, 1.0)
	_apply_font(lbl2, 13)
	row2.add_child(lbl2)

	_rate_label = Label.new()
	_rate_label.custom_minimum_size      = Vector2(90, 0)
	_rate_label.horizontal_alignment     = HORIZONTAL_ALIGNMENT_RIGHT
	_rate_label.modulate                 = Color(0.75, 0.9, 1.0)
	_apply_font(_rate_label, 13)
	row2.add_child(_rate_label)

	# ── 전력 행
	var row3 := HBoxContainer.new()
	vbox.add_child(row3)

	var lbl3 := Label.new()
	lbl3.text     = "전력"
	lbl3.modulate = Color(1.0, 0.9, 0.4)
	_apply_font(lbl3, 13)
	row3.add_child(lbl3)

	_power_label = Label.new()
	_power_label.custom_minimum_size  = Vector2(90, 0)
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_power_label.modulate             = Color(1.0, 0.9, 0.4)
	_apply_font(_power_label, 13)
	row3.add_child(_power_label)

func _apply_font(node: Control, size: int) -> void:
	if _font == null:
		return
	node.add_theme_font_override("font", _font)
	node.add_theme_font_size_override("font_size", size)

# ───────────────────────────────
#  CALLBACKS
# ───────────────────────────────
func _on_essence_changed(value: int) -> void:
	if _essence_label:
		_essence_label.text = "%d" % value

func _on_rate_changed(rate: float) -> void:
	if _rate_label:
		_rate_label.text = "%.1f" % rate

func _on_power_changed(used: int, total: int) -> void:
	if _power_label:
		_power_label.text = "%d / %d" % [used, total]
		if used > total:
			_power_label.modulate = Color(1.0, 0.3, 0.3)
		else:
			_power_label.modulate = Color(1.0, 0.9, 0.4)
