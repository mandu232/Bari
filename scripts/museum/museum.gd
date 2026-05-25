extends Node2D
class_name Museum


@onready var slots:           Node2D           = $ArtifactSlots
@onready var dungeon_trigger: Area2D           = $DungeonEntrance/TriggerArea
@onready var player_spawn:    Marker2D         = $PlayerSpawn
@onready var artifact_select: ArtifactSelectUI = $HUD/ArtifactSelectUI

var _swap_artifact:   ArtifactData  = null
var _build_manager:   BuildManager  = null
var _build_ui:        BuildUI       = null
var _essence_ui:      EssenceUI     = null
var _in_reallocate:   bool          = false   # 전력 재할당 재진입 방지
var _power_lines:     Array[Line2D] = []      # 전력 연결선 노드 목록
var _lines_shown:     bool          = false   # 현재 선 표시 상태 (중복 갱신 방지)
# {node: Node2D, item_path: String} 형태로 동적 배치 항목 추적
var _dynamic_nodes:   Array         = []

func _ready() -> void:
	for slot in slots.get_children():
		if slot is ArtifactSlot:
			slot.essence_generated.connect(_on_essence_generated)
			slot.interact_requested.connect(_on_slot_interact_requested)

	dungeon_trigger.body_entered.connect(_on_dungeon_trigger_entered)
	artifact_select.artifact_selected.connect(_on_artifact_selected)
	artifact_select.cancelled.connect(_on_select_cancelled)
	artifact_select.remove_requested.connect(_on_artifact_remove_requested)

	_setup_build_manager()
	_place_player()
	_restore_pedestals()    # 동적 전시대 먼저 복원
	_reallocate_power()     # 유물 복원 전에 전력 할당 확정
	_restore_artifacts()
	_recalculate_essence_rate()

	_essence_ui = EssenceUI.new()
	add_child(_essence_ui)

	# 전력 토폴로지가 바뀌면 전력 재할당
	GameManager.power_changed.connect(_on_power_changed_museum)

# ───────────────────────────────
#  건설 모드 공통 업데이트
# ───────────────────────────────
func _process(_delta: float) -> void:
	var in_build := (_build_manager != null and _build_manager.is_active) \
				 or (_build_ui      != null and _build_ui.visible)

	# ── 전력선 가시성
	if in_build != _lines_shown:
		_lines_shown = in_build
		for ln in _power_lines:
			if is_instance_valid(ln):
				ln.visible = in_build
		# 건설 모드 종료 시 모든 건물 색상 복원
		if not in_build:
			for entry in _dynamic_nodes:
				var n := entry["node"] as Node2D
				if is_instance_valid(n):
					n.modulate = Color.WHITE

	# ── 철거 가능 건물 호버 하이라이트 (건설 메뉴 열린 상태에서만)
	if _build_ui != null and _build_ui.visible and not _build_manager.is_active:
		var mouse_world := get_global_mouse_position()
		for entry in _dynamic_nodes:
			var n := entry["node"] as Node2D
			if not is_instance_valid(n):
				continue
			var hovering := n.global_position.distance_to(mouse_world) < 24.0
			n.modulate = Color(1.1, 0.45, 0.45) if hovering else Color.WHITE

# ───────────────────────────────
#  건설 모드
# ───────────────────────────────
func _setup_build_manager() -> void:
	_build_manager            = BuildManager.new()
	_build_manager.slots_node = slots
	add_child(_build_manager)
	_build_manager.build_mode_changed.connect(_on_build_mode_changed)
	_build_manager.item_placed.connect(_on_item_placed)

	_build_ui = BuildUI.new()
	add_child(_build_ui)
	_build_ui.item_selected.connect(_on_build_item_selected)
	_build_ui.cancelled.connect(_on_build_cancelled)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_mode"):
		if _build_manager.is_active:
			_build_manager.deactivate()
		elif _build_ui.visible:
			_build_ui.close()
		else:
			_build_ui.show_menu(GameManager.unlocked_blueprints)
		get_viewport().set_input_as_handled()
		return

	if _build_manager.is_active:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_build_manager.try_place()
				get_viewport().set_input_as_handled()
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				# 우클릭 → 배치 취소 후 건설 메뉴로 복귀
				_build_manager.deactivate()
				_build_ui.show_menu(GameManager.unlocked_blueprints)
				get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			_build_manager.deactivate()
			get_viewport().set_input_as_handled()

	# 건설 메뉴 열린 상태 (배치 모드 아님) — 우클릭으로 건물 철거
	elif _build_ui != null and _build_ui.visible:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
				_try_demolish_at(get_global_mouse_position())
				get_viewport().set_input_as_handled()

func _on_build_mode_changed(_active: bool) -> void:
	pass

func _on_build_item_selected(item: BuildableItem) -> void:
	_build_manager.activate(item)

func _on_build_cancelled() -> void:
	pass

# ───────────────────────────────
#  건물 철거
# ───────────────────────────────
## 마우스 위치 근처의 동적 건물을 철거 (클릭 허용 반경 28px)
func _try_demolish_at(world_pos: Vector2) -> void:
	var best_entry: Dictionary = {}
	var best_dist:  float      = 28.0

	for entry in _dynamic_nodes:
		var n := entry["node"] as Node2D
		if not is_instance_valid(n):
			continue
		var d := n.global_position.distance_to(world_pos)
		if d < best_dist:
			best_dist  = d
			best_entry = entry

	if not best_entry.is_empty():
		_demolish_node(best_entry)

## 건물 노드를 제거하고 영력 50% 환급
func _demolish_node(entry: Dictionary) -> void:
	var node      := entry["node"]      as Node2D
	var item_path := entry["item_path"] as String

	if not is_instance_valid(node):
		return

	# 전시대에 유물이 있으면 인벤토리로 반환
	if node is ArtifactSlot:
		var slot := node as ArtifactSlot
		if slot.is_occupied:
			var art := slot.remove_artifact()
			if art:
				GameManager.artifacts.append(art)

	# 영력 50% 환급
	if item_path != "":
		var item := load(item_path) as BuildableItem
		if item != null and item.cost > 0:
			GameManager.add_essence(int(item.cost * 0.5))

	# 목록에서 먼저 제거 후 노드 해제 (PREDELETE 가 power 신호 발생시킴)
	_dynamic_nodes.erase(entry)
	node.modulate = Color.WHITE   # 혹시 남은 하이라이트 초기화
	node.queue_free()

	_save_pedestal_positions()
	_reallocate_power()

func _on_item_placed(item: BuildableItem, world_pos: Vector2) -> void:
	if item.scene == null:
		return
	var node := item.scene.instantiate() as Node2D
	node.global_position = world_pos

	if node is ArtifactSlot:
		var slot := node as ArtifactSlot
		slot.power_cost = item.power_consumption  # _ready() 전에 주입
		slots.add_child(node)
		slot.essence_generated.connect(_on_essence_generated)
		slot.interact_requested.connect(_on_slot_interact_requested)
	elif node is PowerPlant:
		(node as PowerPlant).power_output = item.power_output  # _ready() 전에 주입
		add_child(node)
	else:
		add_child(node)

	_play_place_anim(node)   # 뽀잉 설치 애니메이션
	_dynamic_nodes.append({"node": node, "item_path": item.resource_path})
	_save_pedestal_positions()
	_reallocate_power()      # 새 구조물 설치 후 전력 재할당

# ───────────────────────────────
#  설치 연출
# ───────────────────────────────
## 건물 배치 시 납작 → 위로 쭉 → 튀어오름 → 정착하는 뽀잉 효과
func _play_place_anim(node: Node2D) -> void:
	node.scale = Vector2(1.2, 0.0)          # 납작하게 시작
	var tw := node.create_tween()
	# ① 위로 쭉 늘어남
	tw.tween_property(node, "scale", Vector2(0.75, 1.25), 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# ② 옆으로 퍼지며 착지
	tw.tween_property(node, "scale", Vector2(1.18, 0.85), 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# ③ 다시 살짝 위로 튀어오름
	tw.tween_property(node, "scale", Vector2(0.93, 1.10), 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# ④ 최종 정착
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ───────────────────────────────
#  슬롯 상호작용
# ───────────────────────────────
func _on_slot_interact_requested(slot: ArtifactSlot) -> void:
	if _build_manager and _build_manager.is_active:
		return  # 건설 모드 중 슬롯 상호작용 무시
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(false)

	if slot.is_occupied:
		# 현재 유물을 임시로 인벤토리에 돌려놓고 선택 UI 열기
		_swap_artifact = slot.remove_artifact()
		if _swap_artifact:
			GameManager.artifacts.append(_swap_artifact)

	_set_hud_visible(false)
	artifact_select.show_for_slot(slot, _swap_artifact != null)

func _on_select_cancelled() -> void:
	# 교체 중 취소 → 원래 유물 슬롯에 복원
	if _swap_artifact != null:
		var slot := artifact_select._target_slot
		if slot != null and not slot.is_occupied:
			GameManager.artifacts.erase(_swap_artifact)
			slot.place_artifact(_swap_artifact)
		_swap_artifact = null
	_set_hud_visible(true)
	_resume_player()

func _on_artifact_selected(data: ArtifactData) -> void:
	_swap_artifact = null  # 교체 완료, 복원 불필요
	var slot := artifact_select._target_slot
	if slot == null:
		return
	place_artifact_on_slot(slot, data)
	_set_hud_visible(true)
	_resume_player()

func _on_artifact_remove_requested() -> void:
	# _swap_artifact 는 이미 GameManager.artifacts 에 들어간 상태 — 그냥 놔두면 해제 완료
	_swap_artifact = null
	_save_slot_state()
	_recalculate_essence_rate()
	_set_hud_visible(true)
	_resume_player()

func _set_hud_visible(visible: bool) -> void:
	if is_instance_valid(_essence_ui):
		_essence_ui.visible = visible

func _resume_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(true)

# ───────────────────────────────
#  유물 배치 / 제거
# ───────────────────────────────
func place_artifact_on_slot(slot: ArtifactSlot, data: ArtifactData) -> void:
	if slot.is_occupied:
		return
	GameManager.artifacts.erase(data)
	slot.place_artifact(data)
	_save_slot_state()
	_recalculate_essence_rate()

func remove_artifact_from_slot(slot: ArtifactSlot) -> void:
	var data := slot.remove_artifact()
	if data:
		GameManager.artifacts.append(data)
		_save_slot_state()
		_recalculate_essence_rate()

# ───────────────────────────────
#  전력 중앙 할당
# ───────────────────────────────
## 발전소별 남은 용량을 계산하고, 범위 내 슬롯에 그리디하게 전력 배분
func _reallocate_power() -> void:
	_in_reallocate = true

	# ① 발전소 → 남은 용량 테이블
	var remaining: Dictionary = {}
	for plant in get_tree().get_nodes_in_group("power_plant"):
		var pp := plant as PowerPlant
		if pp:
			remaining[pp] = pp.power_output

	# ② placed_structure 그룹의 슬롯에 배분 + 연결 정보 수집
	var connections: Array = []   # [ {plant: PowerPlant, slot: ArtifactSlot} ]
	for node in get_tree().get_nodes_in_group("placed_structure"):
		var slot := node as ArtifactSlot
		if slot == null:
			continue
		if slot.power_cost == 0:
			slot.set_powered(true)
			continue

		var powered := false
		for plant in remaining.keys():
			var pp := plant as PowerPlant
			var dist := slot.global_position.distance_to(pp.global_position)
			if dist <= pp.power_range and remaining[pp] >= slot.power_cost:
				remaining[pp] -= slot.power_cost
				powered = true
				connections.append({"plant": pp, "slot": slot})
				break
		slot.set_powered(powered)

	# ③ GameManager 동기화 + EssenceUI 갱신
	var used := 0
	for plant in remaining.keys():
		var pp := plant as PowerPlant
		used += pp.power_output - remaining[pp]
	GameManager.used_power = used
	GameManager.power_changed.emit(GameManager.used_power, GameManager.total_power)

	_in_reallocate = false
	_update_power_lines(connections)   # ④ 연결선 갱신
	_recalculate_essence_rate()

# ───────────────────────────────
#  전력 연결선 시각화
# ───────────────────────────────
func _update_power_lines(connections: Array) -> void:
	# 기존 선 제거
	for ln in _power_lines:
		if is_instance_valid(ln):
			ln.queue_free()
	_power_lines.clear()

	for conn in connections:
		var pp   := conn["plant"] as PowerPlant
		var slot := conn["slot"]  as ArtifactSlot
		if not is_instance_valid(pp) or not is_instance_valid(slot):
			continue

		var from := to_local(pp.global_position)
		var to   := to_local(slot.global_position)

		# 글로우 선 (넓고 반투명)
		var glow := _make_power_line(from, to, 7.0, Color(1.0, 0.88, 0.25, 0.18))
		add_child(glow)
		_power_lines.append(glow)
		# 글로우 펄스 애니메이션
		var gt := glow.create_tween().set_loops()
		gt.tween_property(glow, "default_color", Color(1.0, 0.88, 0.25, 0.36), 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		gt.tween_property(glow, "default_color", Color(1.0, 0.88, 0.25, 0.08), 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# 중심 선 (얇고 선명)
		var core := _make_power_line(from, to, 1.5, Color(1.0, 0.95, 0.6, 0.9))
		add_child(core)
		_power_lines.append(core)

## 두 점을 잇는 Line2D 생성 헬퍼
func _make_power_line(from: Vector2, to: Vector2, width: float, color: Color) -> Line2D:
	var ln := Line2D.new()
	ln.z_index           = -1          # 건물 뒤에 렌더링
	ln.visible           = false       # 기본 숨김 — _process 가 build mode 시 표시
	ln.width             = width
	ln.default_color     = color
	ln.begin_cap_mode    = Line2D.LINE_CAP_ROUND
	ln.end_cap_mode      = Line2D.LINE_CAP_ROUND
	ln.add_point(from)
	ln.add_point(to)
	return ln

# ───────────────────────────────
#  영력
# ───────────────────────────────
func _on_essence_generated(amount: int) -> void:
	GameManager.add_essence(amount)

func _recalculate_essence_rate() -> void:
	var total := 0.0
	for child in slots.get_children():
		var slot := child as ArtifactSlot
		# 전력이 공급된 슬롯만 영력 생산에 기여
		if slot and slot.is_occupied and slot.artifact and slot.is_powered:
			total += slot.artifact.essence_per_second
	GameManager.set_essence_rate(total)

## 발전소 추가/제거 → 전력 재할당 (deferred, 재진입 방지)
func _on_power_changed_museum(_used: int, _total: int) -> void:
	if not _in_reallocate:
		call_deferred("_reallocate_power")

# ───────────────────────────────
#  던전 입장
# ───────────────────────────────
func _on_dungeon_trigger_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.save_game()
		GameManager.start_dungeon_run()

# ───────────────────────────────
#  동적 전시대 저장 / 복원
# ───────────────────────────────
const PEDESTALS_SAVE := "user://museum_pedestals.cfg"

func _save_pedestal_positions() -> void:
	var cfg   := ConfigFile.new()
	var count := 0
	for entry in _dynamic_nodes:
		if is_instance_valid(entry["node"]) and entry["item_path"] != "":
			cfg.set_value("dynamic", str(count) + "_item", entry["item_path"])
			cfg.set_value("dynamic", str(count) + "_pos",  entry["node"].global_position)
			count += 1
	cfg.save(PEDESTALS_SAVE)

func _restore_pedestals() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PEDESTALS_SAVE) != OK:
		return
	var i := 0
	while cfg.has_section_key("dynamic", str(i) + "_item"):
		var item_path: String = cfg.get_value("dynamic", str(i) + "_item")
		var pos: Vector2      = cfg.get_value("dynamic", str(i) + "_pos")

		if item_path == "" or not ResourceLoader.exists(item_path):
			i += 1
			continue

		var item := load(item_path) as BuildableItem
		if item == null or item.scene == null:
			i += 1
			continue

		var node := item.scene.instantiate() as Node2D
		node.global_position = pos

		if node is ArtifactSlot:
			var slot := node as ArtifactSlot
			slot.power_cost = item.power_consumption  # _ready() 전에 주입
			slots.add_child(node)
			slot.essence_generated.connect(_on_essence_generated)
			slot.interact_requested.connect(_on_slot_interact_requested)
		elif node is PowerPlant:
			var pp := node as PowerPlant
			pp.power_output = item.power_output          # _ready() 전에 주입
			if item.power_range > 0.0:
				pp.power_range = item.power_range        # .tres 에서 범위 오버라이드
			add_child(node)
		else:
			add_child(node)

		_dynamic_nodes.append({"node": node, "item_path": item_path})
		i += 1

# ───────────────────────────────
#  저장 / 복원
# ───────────────────────────────
func _save_slot_state() -> void:
	var cfg       := ConfigFile.new()
	var slot_list := slots.get_children()
	for i in slot_list.size():
		var slot := slot_list[i] as ArtifactSlot
		if slot == null:
			continue
		var path := slot.artifact.resource_path if slot.is_occupied and slot.artifact else ""
		cfg.set_value("slots", str(i), path)
	cfg.save("user://museum_slots.cfg")

func _restore_artifacts() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://museum_slots.cfg") != OK:
		return
	var slot_list := slots.get_children()
	for i in slot_list.size():
		var path: String = cfg.get_value("slots", str(i), "")
		if path == "" or not ResourceLoader.exists(path):
			continue
		var data := ResourceLoader.load(path) as ArtifactData
		if data:
			(slot_list[i] as ArtifactSlot).place_artifact(data)

# ───────────────────────────────
#  플레이어 스폰
# ───────────────────────────────
func _place_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = player_spawn.global_position
