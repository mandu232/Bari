extends Node2D
class_name ConstructionSite
## 건설 현장 — 에코(최대 3마리)와 플레이어가 협력해 완공

signal construction_complete(site: ConstructionSite)

const MAX_WORKERS        := 3
const BUILD_TIME         := 15.0  # 1마리 기준 완공 시간(초)
const ECHO_WORK_DIST     := 20.0  # 이 거리 이내면 에코가 작업에 기여
const PLAYER_RANGE       := 55.0  # 플레이어 감지 반경(픽셀)
const PLAYER_WORK_AMOUNT := BUILD_TIME * 0.05  # F 1회당 게이지 기여량(5%)
const BAR_WIDTH          := 36.0

var item:     BuildableItem = null
var _workers: Array         = []   # Array[Echo]
var _timer:   float         = BUILD_TIME

# 고스트 비주얼
var _ghost:  Node2D = null

# 진행 바
var _bar_bg: ColorRect = null
var _bar_fg: ColorRect = null

# 플레이어 상호작용
var _player_nearby:  bool  = false
var _hint_label:     Label = null

# ───────────────────────────────
#  초기화
# ───────────────────────────────
func setup(buildable_item: BuildableItem, pos: Vector2) -> void:
	item            = buildable_item
	global_position = pos
	_timer          = BUILD_TIME
	_create_ghost()
	_create_ui()
	_setup_player_area()

# ───────────────────────────────
#  고스트 비주얼
# ───────────────────────────────
func _create_ghost() -> void:
	if item == null or item.scene == null:
		return
	var node := item.scene.instantiate() as Node2D
	_strip_node(node)
	_ghost_play_anim(node, "on")
	node.modulate = Color(0.60, 0.80, 1.0, 0.38)
	_ghost = node
	add_child(_ghost)

func _strip_node(node: Node) -> void:
	if node.get_script():
		node.set_script(null)
	for child in node.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = true
		elif child is CollisionObject2D:
			var col := child as CollisionObject2D
			col.collision_layer = 0
			col.collision_mask  = 0
		_strip_node(child)

func _ghost_play_anim(node: Node, anim: String) -> void:
	if node is AnimatedSprite2D:
		var asp := node as AnimatedSprite2D
		if asp.sprite_frames and asp.sprite_frames.has_animation(anim):
			asp.play(anim)
	for child in node.get_children():
		_ghost_play_anim(child, anim)

# ───────────────────────────────
#  진행 바 + 힌트 레이블 UI
# ───────────────────────────────
func _create_ui() -> void:
	var bar_h  :=  5.0
	var bar_y  := -24.0
	var offset := Vector2(-BAR_WIDTH * 0.5, bar_y)

	_bar_bg          = ColorRect.new()
	_bar_bg.size     = Vector2(BAR_WIDTH, bar_h)
	_bar_bg.position = offset
	_bar_bg.color    = Color(0.08, 0.08, 0.08, 0.75)
	add_child(_bar_bg)

	_bar_fg          = ColorRect.new()
	_bar_fg.size     = Vector2(0.0, bar_h)
	_bar_fg.position = offset
	_bar_fg.color    = Color(0.35, 0.88, 0.55, 0.95)
	add_child(_bar_fg)

	_hint_label                       = Label.new()
	_hint_label.visible               = false
	_hint_label.text                  = "[F] 건설 돕기"
	_hint_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.custom_minimum_size   = Vector2(90, 0)
	_hint_label.position              = Vector2(-45, bar_y - 14)
	var font := load("res://AutoLoad/assets/Font/DungGeunMo.ttf") as Font
	if font:
		_hint_label.add_theme_font_override("font", font)
		_hint_label.add_theme_font_size_override("font_size", 7)
	_hint_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.75))
	add_child(_hint_label)

# ───────────────────────────────
#  플레이어 감지 Area2D
# ───────────────────────────────
func _setup_player_area() -> void:
	var area   := Area2D.new()
	var shape  := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PLAYER_RANGE
	shape.shape   = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_player_entered)
	area.body_exited.connect(_on_player_exited)

func _on_player_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		if _hint_label:
			_hint_label.visible = true

func _on_player_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		if _hint_label:
			_hint_label.visible = false

# ───────────────────────────────
#  입력 — F 키 1회 = 게이지 일정량 충전
# ───────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby:
		return
	if event.is_action_pressed("sub_interact"):
		_timer = maxf(_timer - PLAYER_WORK_AMOUNT, 0.0)
		_flash_bar()
		get_viewport().set_input_as_handled()

func _flash_bar() -> void:
	if not _bar_fg:
		return
	var tw := create_tween()
	tw.tween_property(_bar_fg, "color", Color(0.75, 1.0, 0.85, 1.0), 0.06)
	tw.tween_property(_bar_fg, "color", Color(0.35, 0.88, 0.55, 0.95), 0.14)

# ───────────────────────────────
#  처리
# ───────────────────────────────
func _process(delta: float) -> void:
	_workers = _workers.filter(func(w): return is_instance_valid(w))
	# 현장에 실제로 도착한 에코만 기여
	var count := 0
	for w in _workers:
		var echo := w as Echo
		if echo and echo.global_position.distance_to(global_position) <= ECHO_WORK_DIST:
			count += 1

	if count > 0:
		_timer -= delta * count

	# 진행 바는 에코 유무와 무관하게 항상 갱신 (플레이어 F키 반영)
	if _bar_fg:
		_bar_fg.size.x = BAR_WIDTH * clampf(1.0 - _timer / BUILD_TIME, 0.0, 1.0)

	if _timer <= 0.0:
		construction_complete.emit(self)

# ───────────────────────────────
#  작업자 관리
# ───────────────────────────────
func try_add_worker(echo: Echo) -> bool:
	if _workers.size() >= MAX_WORKERS:
		return false
	_workers.append(echo)
	return true

func release_all_workers() -> void:
	for w in _workers:
		if is_instance_valid(w):
			(w as Echo).stop_work()
	_workers.clear()
