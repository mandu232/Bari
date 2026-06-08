extends Node2D

const FONT        := preload("res://AutoLoad/assets/Font/DungGeunMo.ttf")
const CHEST_SCENE := preload("res://AutoLoad/scenes/DungeonChest.tscn")

# ────────────────────────────────────────
#  적 전멸 감지 & 보물 상자 스폰
# ────────────────────────────────────────
signal dungeon_cleared

var _total_enemies: int  = 0
var _dead_enemies:  int  = 0
var _chest_spawned: bool = false

func _ready() -> void:
	var hud := PlayerHUD.new()
	add_child(hud)

	var fx := load("res://scripts/ScreenEffects.gd").new() as Node
	add_child(fx)

	# TileMap을 최하위 레이어로 고정 — 플레이어/적이 음수 y에서도 타일 앞에 렌더링되도록
	$TileMap.z_index = -4096

	# 한 프레임 대기 후 초기화 (씬 트리 초기화 완료 대기)
	await get_tree().process_frame
	_play_entry_animation()
	_register_enemies()

	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		player.player_died.connect(_on_player_died)
		# HP 변화를 ScreenEffects 에 전달
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		# 초기 HP 비율 전달
		var ratio := float(player.get("health")) / float(player.get("max_health"))
		_update_vignette_hp(ratio)

func _on_player_health_changed(current: int, maximum: int) -> void:
	var ratio := float(current) / float(maximum) if maximum > 0 else 0.0
	_update_vignette_hp(ratio)

func _update_vignette_hp(ratio: float) -> void:
	var sfx := get_tree().get_first_node_in_group("screen_effects")
	if is_instance_valid(sfx) and sfx.has_method("update_hp_ratio"):
		sfx.update_hp_ratio(ratio)

# ────────────────────────────────────────
#  던전 입장 연출 — 확대 상태에서 플레이어가 입구에서 올라오며 줌아웃
# ────────────────────────────────────────
func _play_entry_animation() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	var is_first_room: bool = DungeonRunner.get_progress()["current"] == 1

	var duration := 2.2 if is_first_room else 1.8
	var distance := 120.0

	if is_first_room:
		# 줌아웃 시간을 이동 완료 시점에 맞춤
		var camera := get_tree().get_first_node_in_group("camera")
		if is_instance_valid(camera):
			camera.zoom_from_to_normal(Vector2(5.5, 5.5), duration)

	player.start_entry_walk()

	var tw := create_tween()
	tw.tween_property(player, "global_position:y",
		player.global_position.y - distance, duration) \
		.set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(player.end_entry_walk)

# ────────────────────────────────────────
#  적 사망 시그널 연결
# ────────────────────────────────────────
func _register_enemies() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	_total_enemies = enemies.size()

	if _total_enemies == 0:
		dungeon_cleared.emit()
		_spawn_chest()
		_spawn_door()
		return

	for enemy in enemies:
		if enemy.has_signal("died"):
			enemy.died.connect(_on_enemy_died)

func _on_enemy_died() -> void:
	_dead_enemies += 1
	if _dead_enemies >= _total_enemies and not _chest_spawned:
		dungeon_cleared.emit()
		_spawn_chest()
		_spawn_door()

# ────────────────────────────────────────
#  출구 문 열기 (씬에 배치된 DungeonDoor 사용)
# ────────────────────────────────────────
func _spawn_door() -> void:
	await get_tree().create_timer(1.5).timeout

	var door := $DungeonDoor as DungeonDoor
	if not is_instance_valid(door):
		return

	# 등장 연출
	door.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(door, "scale", Vector2(1.2, 0.8), 0.14) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(door, "scale", Vector2(0.9, 1.1), 0.10) \
		.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(door, "scale", Vector2.ONE,        0.10) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_callback(door.open)

# ────────────────────────────────────────
#  보물 상자 스폰
# ────────────────────────────────────────
func _spawn_chest() -> void:
	_chest_spawned = true

	# 잠깐 딜레이 후 등장 (마지막 처치 타격감 유지)
	await get_tree().create_timer(0.9).timeout

	# 상자 생성
	var chest := CHEST_SCENE.instantiate()
	add_child(chest)
	chest.global_position = _get_dungeon_center()

	# 등장 연출: 0에서 스케일 업 (탄성)
	chest.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(chest, "scale", Vector2(1.2, 0.8), 0.14) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(chest, "scale", Vector2(0.9, 1.1), 0.10) \
		.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(chest, "scale", Vector2.ONE,        0.10) \
		.set_ease(Tween.EASE_OUT)


# ────────────────────────────────────────
#  상자 스폰 위치 계산
#  우선순위: BoxSpwPoint 노드 → Vector2.ZERO
# ────────────────────────────────────────
func _get_dungeon_center() -> Vector2:
	# 에디터에서 배치한 스폰 마커 사용
	var marker := find_child("BoxSpwPoint", true, false) as Node2D
	if is_instance_valid(marker):
		return marker.global_position
	# 마커가 없으면 원점 폴백
	return Vector2.ZERO

# ────────────────────────────────────────
#  화면 알림 (둥실 올라가 페이드)
# ────────────────────────────────────────
func _show_announce(text: String, world_pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font",           FONT)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color",         Color(1.0, 0.9, 0.4))
	lbl.add_theme_color_override("font_shadow_color",  Color(0.0, 0.0, 0.0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.z_as_relative = false
	lbl.z_index       = 4090   # 거의 최상위
	add_child(lbl)
	lbl.global_position = world_pos + Vector2(-80, -60)

	var tw := create_tween()
	tw.tween_property(lbl, "global_position:y", world_pos.y - 110, 1.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.6) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(lbl.queue_free)

# ────────────────────────────────────────
#  플레이어 사망 처리
# ────────────────────────────────────────
func _on_player_died() -> void:
	# faint 애니 재생 후 박물관으로 복귀 (런 중 획득 유물 소실)
	await get_tree().create_timer(1.8).timeout
	GameManager.fail_run()
