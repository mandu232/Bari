extends CanvasLayer
class_name ArtifactSelectUI
## 유물 선택 팝업

signal artifact_selected(data: ArtifactData)
signal cancelled
signal remove_requested

var _target_slot: ArtifactSlot       = null
var _artifacts_cache: Array[ArtifactData] = []

@onready var panel:       Control  = $Panel
@onready var item_list:   ItemList = $Panel/ScrollContainer/ItemList
@onready var desc_label:  Label    = $Panel/DescriptionLabel
@onready var confirm_btn: Button   = $Panel/HBoxContainer/ConfirmButton
@onready var cancel_btn:  Button   = $Panel/HBoxContainer/CancelButton
@onready var remove_btn:  Button   = $Panel/HBoxContainer/RemoveButton

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
	# pause 는 플레이어 이동 막을 때만 — UI 자체는 ALWAYS 로 동작

func close() -> void:
	hide()
	_target_slot       = null
	_artifacts_cache.clear()
	confirm_btn.disabled = true
	remove_btn.visible   = false
	desc_label.text      = ""
	item_list.clear()

func _populate_list() -> void:
	item_list.clear()
	_artifacts_cache.clear()
	confirm_btn.disabled = true

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

func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _artifacts_cache.size():
		return
	var data := _artifacts_cache[index]
	var spirit_info := data.spirit_name
	var passive     := data.passive_description if data.passive_description != "" else data.description
	desc_label.text  = "%s\n%s\n영력/초: %.1f" % [spirit_info, passive, data.essence_per_second]
	confirm_btn.disabled = false

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
