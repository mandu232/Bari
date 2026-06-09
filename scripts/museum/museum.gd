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

# ── 수동 배선 상태
var _construction_sites:  Array   = []      # ConstructionSite 목록
var _manual_connections:  Array   = []      # [{from: Node2D, to: Node2D}] 수동 전선 목록
var _is_wiring:           bool    = false   # 현재 전선을 드래그 중인지
var _wire_source:         Node2D  = null    # 전선의 시작 노드
var _wire_preview_glow:   Line2D  = null    # 드래그 전선 글로우 (넓고 반투명)
var _wire_preview_core:   Line2D  = null    # 드래그 전선 코어 (얇고 선명)
var _range_circle:        Line2D  = null    # 소스 노드의 최대 연결 범위 원
var _wire_in_range:       bool    = true    # 플레이어가 소스 연결 범위 안에 있는지

var _menu_ui:         MenuUI               = null   # 책 버튼 → 메인 메뉴 팝업
var _player_stats_ui: PlayerStatsUI        = null   # 플레이어 스탯 패널
var _doggam_ui:       DoggamUI             = null   # 도감 패널
var _inventory_ui:    ArtifactInventoryUI  = null   # 보유 유물 인벤토리
var _book_btn:        TextureButton        = null   # 우측 하단 책 버튼
var _player_hud:      PlayerHUD            = null   # HP·MP 바 HUD

var _player_near_dungeon: bool  = false
var _dungeon_label:       Label = null

func _ready() -> void:
	for slot in slots.get_children():
		if slot is ArtifactSlot:
			slot.essence_generated.connect(_on_essence_generated)
			slot.interact_requested.connect(_on_slot_interact_requested)
			slot.wire_requested.connect(_on_wire_requested)

	dungeon_trigger.body_entered.connect(_on_dungeon_trigger_entered)
	dungeon_trigger.body_exited.connect(_on_dungeon_trigger_exited)
	artifact_select.artifact_selected.connect(_on_artifact_selected)
	artifact_select.cancelled.connect(_on_select_cancelled)
	artifact_select.remove_requested.connect(_on_artifact_remove_requested)

	_setup_dungeon_label()
	_setup_build_manager()
	_place_player()
	_restore_pedestals()          # 동적 전시대 먼저 복원
	_restore_manual_connections() # 수동 배선 복원 (노드가 모두 생성된 뒤)
	_reallocate_power()           # 유물 복원 전에 전력 할당 확정
	_restore_artifacts()
	_recalculate_essence_rate()

	_essence_ui = EssenceUI.new()
	add_child(_essence_ui)

	_player_hud = PlayerHUD.new()
	add_child(_player_hud)

	_setup_book_button()

	# 전력 토폴로지가 바뀌면 전력 재할당
	GameManager.power_changed.connect(_on_power_changed_museum)
	# 영력 배율이 바뀌면 영력 레이트 재계산
	GameManager.essence_multiplier_changed.connect(func(_m: float): _recalculate_essence_rate())

	# 타일맵을 즉시 뒤로 고정 (Y < 0 이동 시 플레이어가 바닦 뒤로 들어가는 버그 방지)
	_fix_tilemap_sort()
	# 씬 트리가 완전히 구성된 뒤 z_index 초기화 + 초기 시너지 계산
	call_deferred("_refresh_z_sort")
	call_deferred("_recalculate_synergies")

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

	# ── 전선 미리보기: 플레이어 위치를 따라가며 범위 초과 시 빨간색으로 전환
	if _is_wiring and is_instance_valid(_wire_source):
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			var src_pos  := to_local(_wire_source.global_position)
			var ply_pos  := to_local(player.global_position)
			var dist     := _wire_source.global_position.distance_to(player.global_position)
			_wire_in_range = dist <= _get_source_range()

			# 시간 기반 알파 펄스 (트윈 없이 직접 계산 — 색상이 확실히 반영됨)
			var pulse := (sin(Time.get_ticks_msec() * 0.0044) + 1.0) * 0.5  # 0~1, 약 1.4s 주기

			var col_glow:   Color
			var col_core:   Color
			var col_circle: Color
			if _wire_in_range:
				col_glow   = Color(0.30, 0.75, 1.0, lerpf(0.10, 0.40, pulse))
				col_core   = Color(0.65, 0.93, 1.0, 0.90)
				col_circle = Color(0.30, 0.85, 1.0, lerpf(0.40, 0.65, pulse))
			else:
				col_glow   = Color(1.0,  0.22, 0.22, lerpf(0.10, 0.38, pulse))
				col_core   = Color(1.0,  0.50, 0.50, 0.90)
				col_circle = Color(1.0,  0.20, 0.20, lerpf(0.45, 0.70, pulse))

			if is_instance_valid(_wire_preview_glow):
				_wire_preview_glow.set_point_position(0, src_pos)
				_wire_preview_glow.set_point_position(1, ply_pos)
				_wire_preview_glow.default_color = col_glow
			if is_instance_valid(_wire_preview_core):
				_wire_preview_core.set_point_position(0, src_pos)
				_wire_preview_core.set_point_position(1, ply_pos)
				_wire_preview_core.default_color = col_core
			if is_instance_valid(_range_circle):
				_range_circle.default_color = col_circle

	# ── 건설 메뉴 열린 상태: 철거 가능 건물 빨간 호버 하이라이트
	if _build_ui != null and _build_ui.visible and not _build_manager.is_active \
			and not _is_wiring:
		var mouse_world := get_global_mouse_position()
		for entry in _dynamic_nodes:
			var n := entry["node"] as Node2D
			if not is_instance_valid(n):
				continue
			var hovering := n.global_position.distance_to(mouse_world) < 24.0
			n.modulate = Color(1.1, 0.45, 0.45) if hovering else Color.WHITE

# ───────────────────────────────
#  책 버튼 (우측 하단 — 도감·메뉴 진입점)
# ───────────────────────────────
func _setup_book_button() -> void:
	var hud := $HUD as CanvasLayer

	var btn                      := TextureButton.new()
	btn.name                      = "BookButton"
	btn.ignore_texture_size        = true
	btn.custom_minimum_size        = Vector2(120, 120)
	btn.stretch_mode               = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn.offset_left   = -140.0
	btn.offset_top    = -140.0
	btn.offset_right  = -40.0
	btn.offset_bottom = -40.0

	btn.texture_normal = load("res://AutoLoad/assets/UI/Book.png")
	btn.texture_hover  = load("res://AutoLoad/assets/UI/Book_hover.png")  # 호버 시 흰 테두리 이미지
	btn.focus_mode     = Control.FOCUS_NONE   # Space(ui_accept)로 클릭되지 않도록
	btn.pressed.connect(_on_book_button_pressed)
	hud.add_child(btn)
	_book_btn = btn

	# 메뉴 UI 인스턴스화 (책 버튼 클릭 시 표시)
	_menu_ui = (load("res://AutoLoad/scenes/MenuUI.tscn") as PackedScene).instantiate() as MenuUI
	_menu_ui.stats_requested.connect(_on_stats_requested)
	_menu_ui.doggam_requested.connect(_on_doggam_requested)
	_menu_ui.inventory_requested.connect(_on_inventory_requested)
	_menu_ui.opened.connect(func(): _set_hud_visible(false))
	_menu_ui.closed.connect(func(): _set_hud_visible(true))
	hud.add_child(_menu_ui)

	# 플레이어 스탯 UI 인스턴스화
	_player_stats_ui = (load("res://AutoLoad/scenes/PlayerStatsUI.tscn") as PackedScene).instantiate() as PlayerStatsUI
	hud.add_child(_player_stats_ui)

	# 도감 UI 인스턴스화
	_doggam_ui = (load("res://AutoLoad/scenes/DoggamUI.tscn") as PackedScene).instantiate() as DoggamUI
	hud.add_child(_doggam_ui)

	# 인벤토리 UI 인스턴스화
	_inventory_ui = ArtifactInventoryUI.new()
	hud.add_child(_inventory_ui)

func _on_book_button_pressed() -> void:
	if _menu_ui:
		_menu_ui.open()

func _on_stats_requested() -> void:
	if _player_stats_ui:
		_player_stats_ui.open()

func _on_doggam_requested() -> void:
	if _doggam_ui:
		_doggam_ui.open()

func _on_inventory_requested() -> void:
	if _inventory_ui:
		_inventory_ui.open()

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
	# 던전 입구 근처에서 F 키 → 던전 입장 (화이트아웃+줌인 연출 후 씬 전환)
	if event.is_action_pressed("sub_interact") and _player_near_dungeon:
		_player_near_dungeon = false
		if is_instance_valid(_dungeon_label):
			_dungeon_label.visible = false
		get_viewport().set_input_as_handled()
		GameManager.save_game()
		SceneTransition.enter_dungeon(func(): GameManager.start_dungeon_run())
		return

	# 배선 중 ESC → 취소 (건설 모드 상태와 무관하게 최우선 처리)
	if _is_wiring and event.is_action_pressed("ui_cancel"):
		_cancel_wire()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("build_mode"):
		# 전시대 선택 UI 또는 메뉴 UI가 열려있으면 건설 모드 차단
		if artifact_select.visible or (_menu_ui != null and _menu_ui.visible):
			get_viewport().set_input_as_handled()
			return
		if _build_manager.is_active:
			_build_manager.deactivate()
		elif _build_ui.visible:
			_build_ui.close()
			_update_book_visibility()
		else:
			_build_ui.show_menu(GameManager.unlocked_blueprints)
			_update_book_visibility()
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
				_update_book_visibility()
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
	if not _active:
		_cancel_wire()   # 배치 모드 종료 시 진행 중이던 배선 취소
	# 신호가 발생한 시점에 관련 상태가 아직 갱신 중일 수 있으므로 지연 실행
	call_deferred("_update_book_visibility")

func _on_build_item_selected(item: BuildableItem) -> void:
	_build_manager.activate(item)

func _on_build_cancelled() -> void:
	_cancel_wire()
	# BuildUI._on_cancel()은 cancelled.emit() 후 close()를 호출하므로
	# 이 시점엔 _build_ui.visible이 아직 true — 한 프레임 지연해서 확인
	call_deferred("_update_book_visibility")

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

	# 철거된 노드와 연결된 수동 배선도 제거
	# (queue_free 직후엔 is_instance_valid가 여전히 true이므로 노드도 명시 제외)
	_manual_connections = _manual_connections.filter(
		func(c: Dictionary) -> bool:
			return c["from"] != node and c["to"] != node \
				and is_instance_valid(c["from"]) and is_instance_valid(c["to"])
	)
	_save_pedestal_positions()
	_save_manual_connections()
	_reallocate_power()
	_recalculate_synergies()

# ───────────────────────────────
#  수동 배선 — F키 + 플레이어 이동 방식
# ───────────────────────────────
## 발전소 또는 송전탑에서 [F] 신호 수신
##  • 배선 중 아닐 때  : 해당 노드를 출발점으로 배선 시작
##  • 배선 중, 출발점  : 취소
##  • 배선 중, 다른 탑 : 연결 완료 (토글)
##  • 배선 중, 발전소  : 취소 (발전소는 연결 대상 불가)
func _on_wire_requested(node: Node2D) -> void:
	if not _is_wiring:
		# 전원 노드(발전소/송전탑)만 배선 출발점으로 허용
		if node is PowerPlant or node is PowerTower:
			_start_wire_from(node)
	elif node == _wire_source:
		_cancel_wire()
	elif node is PowerTower:
		# 발전소/탑 → 탑 수동 연결 (파란 전선)
		_toggle_connection(_wire_source, node)
		_cancel_wire()
	elif node is ArtifactSlot \
			and _wire_source is PowerPlant \
			and (node as ArtifactSlot).power_cost > 0:
		# 발전소 → 전시대 수동 직접 연결 (노란 전선)
		# 탑 → 전시대는 output_range 내에서 자동 공급이므로 수동 연결 불필요
		_toggle_connection(_wire_source, node)
		_cancel_wire()
	elif node is HologramFountain \
			and _wire_source is PowerPlant \
			and (node as HologramFountain).power_cost > 0:
		# 발전소 → 홀로그램 분수 수동 직접 연결 (청록 전선)
		_toggle_connection(_wire_source, node)
		_cancel_wire()
	elif node is ChargingStation \
			and _wire_source is PowerPlant \
			and (node as ChargingStation).power_cost > 0:
		# 발전소 → 충전소 수동 직접 연결 (주황 전선)
		_toggle_connection(_wire_source, node)
		_cancel_wire()
	elif node is RecordPlayer \
			and _wire_source is PowerPlant \
			and (node as RecordPlayer).power_cost > 0:
		# 발전소 → 기록재생기 수동 직접 연결 (보라 전선)
		_toggle_connection(_wire_source, node)
		_cancel_wire()
	else:
		_cancel_wire()

## 지정한 노드를 출발점으로 배선 모드 시작 + 미리보기 선·범위 원 생성
func _start_wire_from(node: Node2D) -> void:
	_wire_source   = node
	_is_wiring     = true
	_wire_in_range = true

	var src_pos := to_local(node.global_position)

	# ── 범위 원 (소스 노드 중심)
	_range_circle = _make_wire_circle(src_pos, _get_source_range(),
									  Color(0.3, 0.85, 1.0, 0.55))
	_range_circle.z_index = 9
	add_child(_range_circle)

	# ── 글로우 선 (넓고 반투명)
	_wire_preview_glow = Line2D.new()
	_wire_preview_glow.z_index       = 10
	_wire_preview_glow.width         = 7.0
	_wire_preview_glow.default_color = Color(0.3, 0.75, 1.0, 0.22)
	_wire_preview_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_wire_preview_glow.end_cap_mode   = Line2D.LINE_CAP_ROUND
	_wire_preview_glow.add_point(src_pos)
	_wire_preview_glow.add_point(src_pos)
	add_child(_wire_preview_glow)

	# ── 코어 선 (얇고 선명) + 펄스 애니메이션
	_wire_preview_core = Line2D.new()
	_wire_preview_core.z_index       = 11
	_wire_preview_core.width         = 1.5
	_wire_preview_core.default_color = Color(0.65, 0.93, 1.0, 0.9)
	_wire_preview_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_wire_preview_core.end_cap_mode   = Line2D.LINE_CAP_ROUND
	_wire_preview_core.add_point(src_pos)
	_wire_preview_core.add_point(src_pos)
	add_child(_wire_preview_core)
	# 펄스 애니메이션은 _process() 에서 Time 기반으로 직접 계산
	# (트윈과 _process() 직접 대입이 충돌하면 색상이 반영되지 않으므로)

## 두 노드 사이의 수동 연결을 토글 (없으면 추가, 있으면 제거)
## 범위 밖(_wire_in_range == false)이면 새 연결은 추가하지 않는다
func _toggle_connection(from: Node2D, to: Node2D) -> void:
	for i in _manual_connections.size():
		var conn := _manual_connections[i] as Dictionary
		if conn["from"] == from and conn["to"] == to:
			# 이미 연결된 경우 → 제거(토글)는 범위와 무관하게 허용
			_manual_connections.remove_at(i)
			_save_manual_connections()
			_reallocate_power()
			return
	# 새 연결 추가 — 범위 안일 때만
	if not _wire_in_range:
		return
	_manual_connections.append({"from": from, "to": to})
	_save_manual_connections()
	_reallocate_power()

## 진행 중인 배선 취소
func _cancel_wire() -> void:
	_is_wiring     = false
	_wire_source   = null
	_wire_in_range = true
	if is_instance_valid(_wire_preview_glow):
		_wire_preview_glow.queue_free()
	_wire_preview_glow = null
	if is_instance_valid(_wire_preview_core):
		_wire_preview_core.queue_free()
	_wire_preview_core = null
	if is_instance_valid(_range_circle):
		_range_circle.queue_free()
	_range_circle = null

func _on_item_placed(item: BuildableItem, world_pos: Vector2) -> void:
	_start_construction(item, world_pos)

# ───────────────────────────────
#  건설 시작 — 터를 잡고 주변 에코 모집
# ───────────────────────────────
func _start_construction(item: BuildableItem, world_pos: Vector2) -> void:
	if item.scene == null:
		return
	var site := ConstructionSite.new()
	add_child(site)
	site.setup(item, world_pos)
	site.construction_complete.connect(_on_construction_complete)
	_construction_sites.append(site)

	# 가장 가까운 에코부터 최대 MAX_WORKERS 마리 모집
	var echoes := get_tree().get_nodes_in_group("echo")
	echoes.sort_custom(func(a: Node, b: Node) -> bool:
		return (a as Node2D).global_position.distance_to(world_pos) \
			 < (b as Node2D).global_position.distance_to(world_pos))
	for echo_node in echoes:
		var echo := echo_node as Echo
		if echo == null:
			continue
		if site.try_add_worker(echo):
			echo.start_work(site)
		if site._workers.size() >= ConstructionSite.MAX_WORKERS:
			break

func _on_construction_complete(site: ConstructionSite) -> void:
	var item      := site.item
	var world_pos := site.global_position
	site.release_all_workers()
	_construction_sites.erase(site)
	site.queue_free()
	_spawn_building(item, world_pos)

func _spawn_building(item: BuildableItem, world_pos: Vector2) -> void:
	if item.scene == null:
		return
	var node := item.scene.instantiate() as Node2D
	node.global_position = world_pos

	# 동적 전시대 배치 한도 체크
	if node is ArtifactSlot:
		var current_slot_count := _dynamic_nodes.filter(
			func(e: Dictionary) -> bool: return is_instance_valid(e["node"]) and e["node"] is ArtifactSlot
		).size()
		if current_slot_count >= GameManager.max_dynamic_artifact_slots:
			node.queue_free()
			return

	if node is ArtifactSlot:
		var slot := node as ArtifactSlot
		slot.power_cost = item.power_consumption  # _ready() 전에 주입
		slots.add_child(node)
		slot.essence_generated.connect(_on_essence_generated)
		slot.interact_requested.connect(_on_slot_interact_requested)
		slot.wire_requested.connect(_on_wire_requested)
	elif node is PowerPlant:
		var pp := node as PowerPlant
		pp.power_output = item.power_output  # _ready() 전에 주입
		add_child(node)
		pp.wire_requested.connect(_on_wire_requested)
	elif node is PowerTower:
		var pt := node as PowerTower
		if item.relay_capacity > 0:
			pt.relay_capacity = item.relay_capacity
		if item.chain_range > 0.0:
			pt.chain_range = item.chain_range
		if item.power_range > 0.0:
			pt.output_range = item.power_range
		add_child(node)
		pt.wire_requested.connect(_on_wire_requested)
	elif node is HologramFountain:
		var hf := node as HologramFountain
		hf.power_cost = item.power_consumption   # _ready() 전에 주입
		if item.stability_bonus > 0.0:
			hf.stability_bonus = item.stability_bonus
		if item.stability_range > 0.0:
			hf.effect_range = item.stability_range
		add_child(node)
		hf.wire_requested.connect(_on_wire_requested)
	elif node is ChargingStation:
		var cs := node as ChargingStation
		cs.power_cost = item.power_consumption   # _ready() 전에 주입
		if item.output_bonus > 0.0:
			cs.output_bonus = item.output_bonus
		if item.output_range > 0.0:
			cs.effect_range = item.output_range
		add_child(node)
		cs.wire_requested.connect(_on_wire_requested)
	elif node is RecordPlayer:
		var rp := node as RecordPlayer
		rp.power_cost = item.power_consumption   # _ready() 전에 주입
		if item.activity_bonus > 0.0:
			rp.activity_bonus = item.activity_bonus
		if item.activity_range > 0.0:
			rp.effect_range = item.activity_range
		add_child(node)
		rp.wire_requested.connect(_on_wire_requested)
	else:
		add_child(node)

	_play_place_anim(node)   # 설치 애니메이션
	_dynamic_nodes.append({"node": node, "item_path": item.resource_path})
	_apply_y_sort(node)      # 배치 위치 기준 z_index 설정
	_save_pedestal_positions()
	_reallocate_power()      # 새 구조물 설치 후 전력 재할당

# ───────────────────────────────
#  설치 연출
# ───────────────────────────────

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
	_recalculate_synergies()
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
	_recalculate_synergies()
	_set_hud_visible(true)
	_resume_player()

func _set_hud_visible(visible: bool) -> void:
	if is_instance_valid(_player_hud):
		_player_hud.visible = visible
	if is_instance_valid(_essence_ui):
		_essence_ui.visible = visible
	if not visible:
		# 숨길 때 — 조건 계산 없이 즉시 숨김 (artifact_select가 아직 show 전일 수 있음)
		if is_instance_valid(_book_btn):
			_book_btn.visible = false
	else:
		# 보일 때 — close()가 완전히 끝난 뒤 체크해야 하므로 한 프레임 지연
		call_deferred("_update_book_visibility")

## 책 버튼 표시 여부: 건설 모드·BuildUI·전시대 UI가 열리면 숨김
func _update_book_visibility() -> void:
	if not is_instance_valid(_book_btn):
		return
	var hide_book := _build_manager != null and _build_manager.is_active
	hide_book = hide_book or (_build_ui != null and _build_ui.visible)
	hide_book = hide_book or artifact_select.visible
	_book_btn.visible = not hide_book

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
	_recalculate_synergies()

func remove_artifact_from_slot(slot: ArtifactSlot) -> void:
	var data := slot.remove_artifact()
	if data:
		GameManager.artifacts.append(data)
		_save_slot_state()
		_recalculate_essence_rate()
		_recalculate_synergies()

# ───────────────────────────────
#  전력 중앙 할당
# ───────────────────────────────
## 건물 순서대로 그리드 전력 분배
func _reallocate_power() -> void:
	_in_reallocate = true

	# ① 발전소 남은 용량 초기화
	var plant_remaining: Dictionary = {}
	for plant in get_tree().get_nodes_in_group("power_plant"):
		var pp := plant as PowerPlant
		if pp:
			plant_remaining[pp] = pp.power_output

	# ② 송전탑 초기화 + 유효하지 않은 수동 연결 정리
	for tower in get_tree().get_nodes_in_group("power_tower"):
		var pt := tower as PowerTower
		if pt:
			pt.is_active       = false
			pt.remaining_relay = 0
			pt.source          = null
	_manual_connections = _manual_connections.filter(
		func(c: Dictionary) -> bool:
			return is_instance_valid(c["from"]) and is_instance_valid(c["to"])
	)

	# BFS: 수동 연결을 따라 탑 활성화
	# 발전소 → 탑 → 탑 순서로 반복(탑이 이미 활성화된 탑을 source로 쓸 수 있게)
	var activated_any := true
	while activated_any:
		activated_any = false
		for tower in get_tree().get_nodes_in_group("power_tower"):
			var pt := tower as PowerTower
			if pt == null or pt.is_active:
				continue
			# 이 탑을 target으로 하는 수동 연결이 있는지 확인
			for conn in _manual_connections:
				if conn["to"] != pt:
					continue
				var src := conn["from"] as Node2D
				var src_ok := false
				if src is PowerPlant:
					src_ok = true          # 발전소는 항상 유효한 전원
				elif src is PowerTower:
					src_ok = (src as PowerTower).is_active   # 이미 활성화된 탑만
				if src_ok:
					pt.is_active       = true
					pt.remaining_relay = pt.relay_capacity
					pt.source          = src
					activated_any      = true
					break

	# ③ placed_structure 그룹의 소비 건물에 배분 + 연결 정보 수집
	# connections 형식: {from: Node2D, to: Node2D}
	#   - 발전소/탑 → ArtifactSlot     : 노란 전선
	#   - 발전소/탑 → HologramFountain : 청록 전선
	#   - 발전소/탑 → PowerTower       : 파란 전선 (탑 연결)
	var connections: Array = []

	# ③-a. 활성화된 수동 연결선 수집 (발전소/탑 → 탑, 파란 전선)
	for conn in _manual_connections:
		var to_tower := conn["to"] as PowerTower
		if to_tower != null and to_tower.is_active:
			connections.append({"from": conn["from"] as Node2D, "to": to_tower})

	# ③-b. 전력 소비 건물(ArtifactSlot / HologramFountain) 전력 배분
	#  우선순위: ① 발전소→건물 수동 연결  ② 범위 내 활성 송전탑 자동 공급
	for node in get_tree().get_nodes_in_group("placed_structure"):
		# 전력 소비 노드 확인
		var node_power_cost: int
		if node is ArtifactSlot:
			node_power_cost = (node as ArtifactSlot).power_cost
		elif node is HologramFountain:
			node_power_cost = (node as HologramFountain).power_cost
		elif node is ChargingStation:
			node_power_cost = (node as ChargingStation).power_cost
		elif node is RecordPlayer:
			node_power_cost = (node as RecordPlayer).power_cost
		else:
			continue

		if node_power_cost == 0:
			node.call("set_powered", true)
			continue

		var powered := false
		var node2d := node as Node2D   # placed_structure 는 반드시 Node2D 파생

		# ① 발전소 → 건물 수동 직접 연결
		for conn in _manual_connections:
			if conn["to"] != node2d:
				continue
			var src := conn["from"] as Node2D
			if src is PowerPlant:
				var pp := src as PowerPlant
				if plant_remaining.get(pp, 0) >= node_power_cost:
					plant_remaining[pp] -= node_power_cost
					powered = true
					connections.append({"from": pp, "to": node2d})
					break

		# ② 수동 연결 없으면 → output_range 내 활성 송전탑에서 자동 공급
		if not powered and node2d != null:
			for tower in get_tree().get_nodes_in_group("power_tower"):
				var pt := tower as PowerTower
				if pt == null or not pt.is_active:
					continue
				var dist := node2d.global_position.distance_to(pt.global_position)
				if dist <= pt.output_range \
						and _can_supply_via_chain(pt, node_power_cost, plant_remaining):
					_deduct_via_chain(pt, node_power_cost, plant_remaining)
					powered = true
					connections.append({"from": pt, "to": node2d})
					break

		node.call("set_powered", powered)

	# ③-c. 송전탑 스프라이트 애니메이션 갱신 (is_active 확정 후)
	for tower in get_tree().get_nodes_in_group("power_tower"):
		var pt := tower as PowerTower
		if pt:
			pt.refresh_visuals()

	# ④ GameManager 동기화
	var used := 0
	for plant in plant_remaining.keys():
		var pp := plant as PowerPlant
		used += pp.power_output - plant_remaining[pp]
	GameManager.used_power = used
	GameManager.power_changed.emit(GameManager.used_power, GameManager.total_power)

	_in_reallocate = false
	_update_power_lines(connections)
	_recalculate_essence_rate()

## 탑 → (탑 →)* 발전소 체인 전체에 amount 만큼 용량이 남아있는지 확인
func _can_supply_via_chain(tower: PowerTower, amount: int,
		plant_remaining: Dictionary) -> bool:
	var current: Node2D = tower
	while current != null:
		if current is PowerTower:
			var pt := current as PowerTower
			if pt.remaining_relay < amount:
				return false
			current = pt.source
		elif current is PowerPlant:
			return plant_remaining.get(current, 0) >= amount
		else:
			return false
	return false

## 체인 전체(탑들 + 최상위 발전소)에서 amount 를 차감
func _deduct_via_chain(tower: PowerTower, amount: int,
		plant_remaining: Dictionary) -> void:
	var current: Node2D = tower
	while current != null:
		if current is PowerTower:
			var pt := current as PowerTower
			pt.remaining_relay -= amount
			current = pt.source
		elif current is PowerPlant:
			plant_remaining[current] -= amount
			break
		else:
			break

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
		var from_node := conn["from"] as Node2D
		var to_node   := conn["to"]   as Node2D
		if not is_instance_valid(from_node) or not is_instance_valid(to_node):
			continue

		var from := to_local(from_node.global_position)
		var to   := to_local(to_node.global_position)

		# 탑(파란) / 분수(청록) / 충전소(주황) / 전시대(노란) 연결선 색상 구분
		var col_glow: Color
		var col_core: Color
		var col_peak: Color
		#탑
		if to_node is PowerTower:
			col_glow = Color(0.3,  0.75, 1.0,  0.18)
			col_peak = Color(0.3,  0.75, 1.0,  0.36)
			col_core = Color(0.6,  0.92, 1.0,  0.9)
		#분수
		elif to_node is HologramFountain:
			col_glow = Color(0.15, 0.9,  0.7,  0.18)
			col_peak = Color(0.15, 0.9,  0.7,  0.36)
			col_core = Color(0.3,  1.0,  0.85, 0.9)
		#충전소
		elif to_node is ChargingStation:
			col_glow = Color(1.0,  0.55, 0.1,  0.18)
			col_peak = Color(1.0,  0.55, 0.1,  0.36)
			col_core = Color(1.0,  0.78, 0.4,  0.9)
		#패널
		elif to_node is RecordPlayer:
			col_glow = Color(0.75, 0.2,  1.0,  0.18)
			col_peak = Color(0.75, 0.2,  1.0,  0.36)
			col_core = Color(0.88, 0.55, 1.0,  0.9)
		#전시대
		else:
			col_glow = Color(1.0,  0.88, 0.25, 0.18)
			col_peak = Color(1.0,  0.88, 0.25, 0.36)
			col_core = Color(1.0,  0.95, 0.6,  0.9)

		# 글로우 선 (넓고 반투명) + 펄스 애니메이션
		var glow := _make_power_line(from, to, 7.0, col_glow)
		add_child(glow)
		_power_lines.append(glow)
		var gt := glow.create_tween().set_loops()
		gt.tween_property(glow, "default_color", col_peak,                         0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		gt.tween_property(glow, "default_color", col_glow.darkened(0.3), 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# 중심 선 (얇고 선명)
		var core := _make_power_line(from, to, 1.5, col_core)
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

## 배선 드래그 중 소스 노드의 연결 가능 최대 거리를 반환
## 탑은 chain_range(수동 배선 거리), 발전소는 power_range 사용
func _get_source_range() -> float:
	if _wire_source is PowerPlant:
		return (_wire_source as PowerPlant).power_range
	elif _wire_source is PowerTower:
		return (_wire_source as PowerTower).chain_range
	return 0.0

## 배선 드래그 중 범위 표시에 쓸 원형 Line2D 생성 (64 세그먼트)
func _make_wire_circle(center: Vector2, radius: float, color: Color) -> Line2D:
	var ln := Line2D.new()
	ln.width         = 1.5
	ln.default_color = color
	ln.begin_cap_mode = Line2D.LINE_CAP_NONE
	ln.end_cap_mode   = Line2D.LINE_CAP_NONE
	var seg := 64
	for i in seg + 1:
		var angle := TAU * float(i) / seg
		ln.add_point(center + Vector2(cos(angle), sin(angle)) * radius)
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
			total += slot.artifact.essence_per_second * GameManager.essence_multiplier
	GameManager.set_essence_rate(total)

## 현재 전시 중인 유물 배열 반환 (slots 자식 중 is_occupied 인 것)
func _get_exhibited_artifacts() -> Array:
	var result: Array = []
	for child in slots.get_children():
		var slot := child as ArtifactSlot
		if slot != null and slot.is_occupied and slot.artifact != null:
			result.append(slot.artifact)
	return result

## 시너지 재계산 — 전시 변경 시마다 호출
func _recalculate_synergies() -> void:
	GameManager.update_synergies(_get_exhibited_artifacts())

## 발전소 추가/제거 → 전력 재할당 (deferred, 재진입 방지)
func _on_power_changed_museum(_used: int, _total: int) -> void:
	if not _in_reallocate:
		call_deferred("_reallocate_power")

# ───────────────────────────────
#  던전 입장 라벨
# ───────────────────────────────
func _setup_dungeon_label() -> void:
	var hud := $HUD as CanvasLayer
	_dungeon_label = Label.new()
	_dungeon_label.text = "[F] 그림으로 들어가기"
	var dungeon_font := load("res://AutoLoad/assets/Font/DungGeunMo.ttf") as FontFile
	if dungeon_font:
		_dungeon_label.add_theme_font_override("font", dungeon_font)
	_dungeon_label.add_theme_font_size_override("font_size", 20)
	_dungeon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dungeon_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_dungeon_label.modulate             = Color(0.6,  0.92, 1.0)
	# 화면 하단 중앙 고정
	_dungeon_label.anchor_left   = 0.5
	_dungeon_label.anchor_right  = 0.5
	_dungeon_label.anchor_top    = 1.0
	_dungeon_label.anchor_bottom = 1.0
	_dungeon_label.offset_left   = -100
	_dungeon_label.offset_right  = 100
	_dungeon_label.offset_top    = -100
	_dungeon_label.offset_bottom = -70
	_dungeon_label.visible       = false
	hud.add_child(_dungeon_label)

# ───────────────────────────────
#  던전 입장
# ───────────────────────────────
func _on_dungeon_trigger_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near_dungeon = true
		if is_instance_valid(_dungeon_label):
			_dungeon_label.visible = true

func _on_dungeon_trigger_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near_dungeon = false
		if is_instance_valid(_dungeon_label):
			_dungeon_label.visible = false

# ───────────────────────────────
#  Y-소팅 — 탑다운 뷰 앞뒤 정렬
# ───────────────────────────────
## 노드 하나의 z_index 를 y 좌표 기반으로 설정
## z_as_relative = false 로 부모 z_index 영향을 받지 않게 고정
func _apply_y_sort(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	if node is Echo:
		return  # 에코는 z_index = 3000 고정 — 덮어쓰지 않음
	node.z_as_relative = false
	node.z_index       = int(node.global_position.y)

## 씬 전체 건물(정적 슬롯 + 동적 노드)의 z_index 일괄 갱신
func _refresh_z_sort() -> void:
	for child in slots.get_children():
		_apply_y_sort(child as Node2D)
	for entry in _dynamic_nodes:
		_apply_y_sort(entry["node"] as Node2D)

## 씬 내 모든 타일맵을 절대 최솟값 Z 로 고정 (-4096 은 Godot 4 z_index 하한)
func _fix_tilemap_sort() -> void:
	# 경로 직접 지정 — @onready 타입 어노테이션 없이 안전하게 접근
	for path in ["TileMap/Floor", "TileMap/Wall"]:
		var node := get_node_or_null(path)
		if node is CanvasItem:
			(node as CanvasItem).z_as_relative = false
			(node as CanvasItem).z_index       = -4096
	# 혹시 있을 다른 TileMapLayer 탐색
	for node in find_children("*", "TileMapLayer", true, false):
		var ci := node as CanvasItem
		if ci:
			ci.z_as_relative = false
			ci.z_index       = -4096
	# 구버전 TileMap 클래스 대응
	for node in find_children("*", "TileMap", true, false):
		var ci := node as CanvasItem
		if ci:
			ci.z_as_relative = false
			ci.z_index       = -4096

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
			slot.wire_requested.connect(_on_wire_requested)
		elif node is PowerPlant:
			var pp := node as PowerPlant
			pp.power_output = item.power_output          # _ready() 전에 주입
			if item.power_range > 0.0:
				pp.power_range = item.power_range        # .tres 에서 범위 오버라이드
			add_child(node)
			pp.wire_requested.connect(_on_wire_requested)
		elif node is PowerTower:
			var pt := node as PowerTower
			if item.relay_capacity > 0:
				pt.relay_capacity = item.relay_capacity
			if item.chain_range > 0.0:
				pt.chain_range = item.chain_range
			if item.power_range > 0.0:
				pt.output_range = item.power_range
			add_child(node)
			pt.wire_requested.connect(_on_wire_requested)
		elif node is HologramFountain:
			var hf := node as HologramFountain
			hf.power_cost = item.power_consumption
			if item.stability_bonus > 0.0:
				hf.stability_bonus = item.stability_bonus
			if item.stability_range > 0.0:
				hf.effect_range = item.stability_range
			add_child(node)
			hf.wire_requested.connect(_on_wire_requested)
		elif node is ChargingStation:
			var cs := node as ChargingStation
			cs.power_cost = item.power_consumption
			if item.output_bonus > 0.0:
				cs.output_bonus = item.output_bonus
			if item.output_range > 0.0:
				cs.effect_range = item.output_range
			add_child(node)
			cs.wire_requested.connect(_on_wire_requested)
		elif node is RecordPlayer:
			var rp := node as RecordPlayer
			rp.power_cost = item.power_consumption
			if item.activity_bonus > 0.0:
				rp.activity_bonus = item.activity_bonus
			if item.activity_range > 0.0:
				rp.effect_range = item.activity_range
			add_child(node)
			rp.wire_requested.connect(_on_wire_requested)
		else:
			add_child(node)

		_apply_y_sort(node)
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
#  수동 배선 저장 / 복원
# ───────────────────────────────
const WIRE_SAVE := "user://power_wires.cfg"

## 수동 연결을 (from 위치, to 위치) 쌍으로 저장
func _save_manual_connections() -> void:
	var cfg   := ConfigFile.new()
	var count := 0
	for conn in _manual_connections:
		var f := conn["from"] as Node2D
		var t := conn["to"]   as Node2D
		if is_instance_valid(f) and is_instance_valid(t):
			cfg.set_value("wires", str(count) + "_from", f.global_position)
			cfg.set_value("wires", str(count) + "_to",   t.global_position)
			count += 1
	cfg.save(WIRE_SAVE)

## 저장된 연결을 위치 기준으로 노드를 찾아 복원
func _restore_manual_connections() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(WIRE_SAVE) != OK:
		return

	# 복원 가능한 노드 목록 수집 (전원 노드 + 전력 비용이 있는 소비 건물)
	var candidates: Array[Node2D] = []
	for n in get_tree().get_nodes_in_group("power_plant"):
		candidates.append(n as Node2D)
	for n in get_tree().get_nodes_in_group("power_tower"):
		candidates.append(n as Node2D)
	for n in get_tree().get_nodes_in_group("placed_structure"):
		var s := n as ArtifactSlot
		if s != null and s.power_cost > 0:
			candidates.append(s)
	for n in get_tree().get_nodes_in_group("hologram_fountain"):
		var hf := n as HologramFountain
		if hf != null and hf.power_cost > 0:
			candidates.append(hf)
	for n in get_tree().get_nodes_in_group("charging_station"):
		var cs := n as ChargingStation
		if cs != null and cs.power_cost > 0:
			candidates.append(cs)
	for n in get_tree().get_nodes_in_group("record_player"):
		var rp := n as RecordPlayer
		if rp != null and rp.power_cost > 0:
			candidates.append(rp)
	var i := 0
	while cfg.has_section_key("wires", str(i) + "_from"):
		var from_pos: Vector2 = cfg.get_value("wires", str(i) + "_from")
		var to_pos:   Vector2 = cfg.get_value("wires", str(i) + "_to")
		var from_node := _find_node_near(candidates, from_pos)
		var to_node   := _find_node_near(candidates, to_pos)
		if from_node != null and to_node != null:
			_manual_connections.append({"from": from_node, "to": to_node})
		i += 1

## 노드 배열에서 pos 에 가장 가까운 노드를 반환 (허용 오차 8px)
func _find_node_near(nodes: Array[Node2D], pos: Vector2, tol: float = 8.0) -> Node2D:
	for n in nodes:
		if n.global_position.distance_to(pos) <= tol:
			return n
	return null

# ───────────────────────────────
#  플레이어 스폰
# ───────────────────────────────
func _place_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = player_spawn.global_position
