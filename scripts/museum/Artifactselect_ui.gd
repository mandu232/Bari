extends CanvasLayer
class_name ArtifactSelectUI
## 유물 선택 팝업

signal artifact_selected(data: ArtifactData)
signal cancelled
signal remove_requested

# 스탯 아이콘 경로 (AutoLoad/assets/Stats/ 폴더에 파일 추가 시 자동 적용)
const STAT_ICON_PATHS := {
	"atk":     "res://AutoLoad/assets/Stats/icon_atk.png",
	"atk_spd": "res://AutoLoad/assets/Stats/icon_atk_spd.png",
	"def":     "res://AutoLoad/assets/Stats/icon_def.png",
	"spd":     "res://AutoLoad/assets/Stats/icon_move_spd.png",
	"hp":      "res://AutoLoad/assets/Stats/icon_hp.png",
}

var _target_slot:     ArtifactSlot        = null
var _artifacts_cache: Array[ArtifactData] = []
var _font:            Font                = null

@onready var panel:            Control       = $Panel
@onready var item_list:        ItemList      = $Panel/ScrollContainer/ItemList
@onready var artifact_texture: TextureRect   = $Panel/ArtifactImageBox/ArtifactTextureRect
@onready var echo_texture:     TextureRect   = $Panel/EchoImageBox/EchoTextureRect
@onready var info_label:       Label         = $Panel/RightScroll/VBox/InfoLabel
@onready var decay_label:      Label         = $Panel/RightScroll/VBox/DecayLabel
@onready var _bonus_container: VBoxContainer = $Panel/RightScroll/VBox/BonusContainer
@onready var confirm_btn:      Button        = $Panel/HBoxContainer/ConfirmButton
@onready var cancel_btn:       Button        = $Panel/HBoxContainer/CancelButton
@onready var remove_btn:       Button        = $Panel/HBoxContainer/RemoveButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://AutoLoad/assets/Font/DungGeunMo.ttf")
	hide()
	item_list.item_selected.connect(_on_item_selected)
	confirm_btn.pressed.connect(_on_confirm)
	cancel_btn.pressed.connect(_on_cancel)
	remove_btn.pressed.connect(_on_remove)
	confirm_btn.disabled = true
	remove_btn.visible   = false

func show_for_slot(slot: ArtifactSlot, show_remove: bool = false) -> void:
	_target_slot       = slot
	remove_btn.visible = show_remove
	_populate_list()
	show()

func close() -> void:
	hide()
	_target_slot             = null
	confirm_btn.disabled     = true
	remove_btn.visible       = false
	info_label.text          = ""
	decay_label.text         = ""
	artifact_texture.texture = null
	echo_texture.texture     = null
	_clear_bonus_rows()
	_artifacts_cache.clear()
	item_list.clear()

# ───────────────────────────────
#  목록 채우기
# ───────────────────────────────
func _populate_list() -> void:
	item_list.clear()
	_artifacts_cache.clear()
	confirm_btn.disabled = true
	info_label.text      = ""
	decay_label.text     = ""
	_clear_bonus_rows()
	artifact_texture.texture = null
	echo_texture.texture     = null

	if GameManager.artifacts.is_empty():
		item_list.add_item("보유한 유물이 없습니다")
		return

	for data: ArtifactData in GameManager.artifacts:
		if data == null:
			continue
		if data.texture:
			item_list.add_item(data.artifact_name, data.texture)
		else:
			item_list.add_item(data.artifact_name)
		_artifacts_cache.append(data)

# ───────────────────────────────
#  항목 선택 시 오른쪽 패널 갱신
# ───────────────────────────────
func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _artifacts_cache.size():
		return
	var data := _artifacts_cache[index]

	artifact_texture.texture = data.texture

	echo_texture.texture = null
	if data.echo_frames != null \
			and data.echo_frames.has_animation(&"float") \
			and data.echo_frames.get_frame_count(&"float") > 0:
		echo_texture.texture = data.echo_frames.get_frame_texture(&"float", 0)

	var passive := data.passive_description if data.passive_description != "" \
											else data.description
	info_label.text = "유물: %s\n에코: %s\n시대: %s\n영력/초: %.2f\n\n%s" % [
		data.artifact_name,
		data.echo_name,
		ArtifactData.era_label(data.era),
		data.essence_per_second,
		passive,
	]

	decay_label.text = (
		"── 욕구 감소율 ──\n"
		+ "안정도  %.2f/초\n" % data.stability_decay
		+ "출력    %.2f/초\n" % data.output_decay
		+ "활성도  %.2f/초"   % data.activity_decay
	)

	_rebuild_bonus_rows(data)
	confirm_btn.disabled = false

# ───────────────────────────────
#  보너스 행 (아이콘 + 텍스트)
# ───────────────────────────────
func _clear_bonus_rows() -> void:
	for child in _bonus_container.get_children():
		child.queue_free()

func _rebuild_bonus_rows(data: ArtifactData) -> void:
	_clear_bonus_rows()

	# 헤더
	var header := Label.new()
	header.text = "── 플레이어 보너스 ──"
	_set_font(header, 14)
	_bonus_container.add_child(header)

	var has_any := false

	if data.bonus_attack > 0:
		_bonus_container.add_child(_make_stat_row(
			"atk", "공격력", "+%d" % data.bonus_attack, "(상한 +%d)" % data.bonus_atk_max))
		has_any = true
	if data.bonus_attack_speed > 0:
		_bonus_container.add_child(_make_stat_row(
			"atk_spd", "공격속도", "+%d%%" % data.bonus_attack_speed, "(상한 +%d%%)" % data.bonus_atk_spd_max))
		has_any = true
	if data.bonus_defense > 0:
		_bonus_container.add_child(_make_stat_row(
			"def", "방어력", "+%d" % data.bonus_defense, "(상한 +%d)" % data.bonus_def_max))
		has_any = true
	if data.bonus_move_speed > 0.01:
		_bonus_container.add_child(_make_stat_row(
			"spd", "이동속도", "+%.1f" % data.bonus_move_speed, "(상한 +%.1f)" % data.bonus_move_spd_max))
		has_any = true
	if data.bonus_max_health > 0:
		_bonus_container.add_child(_make_stat_row(
			"hp", "체력", "+%d" % data.bonus_max_health, "(상한 +%d)" % data.bonus_hp_max))
		has_any = true

	if not has_any:
		var none_lbl := Label.new()
		none_lbl.text = "보너스 없음"
		none_lbl.modulate = Color(0.6, 0.6, 0.6)
		_set_font(none_lbl, 14)
		_bonus_container.add_child(none_lbl)

func _make_stat_row(icon_key: String, stat_name: String,
					value_str: String, cap_str: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	# 아이콘 (16×16, 없으면 빈 공간)
	var icon_path: String = STAT_ICON_PATHS.get(icon_key, "")
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(16, 16)
	tex_rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if icon_path != "" and ResourceLoader.exists(icon_path):
		tex_rect.texture = load(icon_path)
	row.add_child(tex_rect)

	# 스탯 이름
	var name_lbl := Label.new()
	name_lbl.text                = stat_name
	name_lbl.custom_minimum_size = Vector2(52, 0)
	_set_font(name_lbl, 14)
	row.add_child(name_lbl)

	# 수치 (초록)
	var val_lbl := Label.new()
	val_lbl.text                = value_str
	val_lbl.modulate            = Color(0.4, 1.0, 0.6)
	val_lbl.custom_minimum_size = Vector2(38, 0)
	_set_font(val_lbl, 14)
	row.add_child(val_lbl)

	# 상한 (회색)
	var cap_lbl := Label.new()
	cap_lbl.text     = cap_str
	cap_lbl.modulate = Color(0.55, 0.55, 0.55)
	_set_font(cap_lbl, 12)
	row.add_child(cap_lbl)

	return row

func _set_font(node: Control, size: int) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
		node.add_theme_font_size_override("font_size", size)

# ───────────────────────────────
#  버튼 콜백
# ───────────────────────────────
func _on_confirm() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	artifact_selected.emit(_artifacts_cache[selected[0]])
	close()

func _on_cancel() -> void:
	cancelled.emit()
	close()

func _on_remove() -> void:
	remove_requested.emit()
	close()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_on_cancel()
