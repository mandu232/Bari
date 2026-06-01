extends CanvasLayer
class_name ArtifactSelectUI
## 유물 선택 팝업
## 유물 이미지, 에코 이미지, 욕구 감소율을 함께 표시

signal artifact_selected(data: ArtifactData)
signal cancelled
signal remove_requested

var _target_slot:      ArtifactSlot           = null
var _artifacts_cache:  Array[ArtifactData]    = []

@onready var panel:            Control      = $Panel
@onready var item_list:        ItemList     = $Panel/ScrollContainer/ItemList
@onready var artifact_texture: TextureRect  = $Panel/ArtifactImageBox/ArtifactTextureRect
@onready var echo_texture:     TextureRect  = $Panel/EchoImageBox/EchoTextureRect
@onready var info_label:       Label        = $Panel/InfoLabel
@onready var decay_label:      Label        = $Panel/DecayLabel
@onready var confirm_btn:      Button       = $Panel/HBoxContainer/ConfirmButton
@onready var cancel_btn:       Button       = $Panel/HBoxContainer/CancelButton
@onready var remove_btn:       Button       = $Panel/HBoxContainer/RemoveButton

func _ready() -> void:
	# 핵심 — 트리가 paused 여도 이 노드는 계속 동작
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	_target_slot              = null
	confirm_btn.disabled      = true
	remove_btn.visible        = false
	info_label.text           = ""
	decay_label.text          = ""
	artifact_texture.texture  = null
	echo_texture.texture      = null
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

	# ── 유물 이미지
	artifact_texture.texture = data.texture

	# ── 에코 이미지 (SpriteFrames 의 "float" 첫 프레임)
	echo_texture.texture = null
	if data.echo_frames != null \
			and data.echo_frames.has_animation(&"float") \
			and data.echo_frames.get_frame_count(&"float") > 0:
		echo_texture.texture = data.echo_frames.get_frame_texture(&"float", 0)

	# ── 기본 정보
	var passive := data.passive_description if data.passive_description != "" \
											else data.description
	info_label.text = "유물: %s\n에코: %s\n영력/초: %.2f\n\n%s" % [
		data.artifact_name,
		data.echo_name,
		data.essence_per_second,
		passive,
	]

	# ── 플레이어 스탯 보너스 (획득 시 확정된 값)
	var stat_parts: Array[String] = []
	if data.rolled_health > 0:
		stat_parts.append("체력 +%d" % data.rolled_health)
	if data.rolled_damage > 0:
		stat_parts.append("공격력 +%d" % data.rolled_damage)
	if data.rolled_speed > 0.0:
		stat_parts.append("속도 +%.1f" % data.rolled_speed)
	var stat_line := "  |  ".join(stat_parts) if stat_parts.size() > 0 else "없음"

	# ── 욕구 감소율
	decay_label.text = (
		"── 플레이어 스탯 ──\n"
		+ stat_line + "\n"
		+ "\n"
		+ "── 에코 욕구 감소율 ──\n"
		+ "안정도:   %.2f / 초\n" % data.stability_decay
		+ "출력:     %.2f / 초\n" % data.output_decay
		+ "활성도:   %.2f / 초"   % data.activity_decay
	)

	confirm_btn.disabled = false

# ───────────────────────────────
#  버튼 콜백
# ───────────────────────────────
func _on_confirm() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	var data := _artifacts_cache[selected[0]]
	artifact_selected.emit(data)
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
