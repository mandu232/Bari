extends Node2D
class_name BuildManager
## 박물관 건설 모드

@export var grid_size:         int   = 16
@export var min_place_dist:    float = 48.0  # 전시대 간 최소 거리 (픽셀)

signal build_mode_changed(active: bool)
signal item_placed(item: BuildableItem, world_pos: Vector2)

var is_active:         bool          = false
var current_item:      BuildableItem = null
var slots_node:        Node2D        = null   # museum 이 주입
var _ghost:            Node2D        = null   # 실제 씬 인스턴스를 고스트로 사용
var _placement_blocked: bool         = false

var _hint_layer: CanvasLayer = null
var _font:       Font        = null

# ───────────────────────────────
#  READY
# ───────────────────────────────
func _ready() -> void:
	_font = load("res://AutoLoad/assets/Font/DungGeunMo.ttf")
	_build_hint_ui()

# ───────────────────────────────
#  PUBLIC API
# ───────────────────────────────
func activate(item: BuildableItem) -> void:
	if is_active:
		return
	current_item = item
	is_active    = true
	_create_ghost()
	_hint_layer.visible = true
	build_mode_changed.emit(true)
	queue_redraw()

func deactivate() -> void:
	if not is_active:
		return
	is_active    = false
	current_item = null
	_destroy_ghost()
	_hint_layer.visible = false
	build_mode_changed.emit(false)
	queue_redraw()

func try_place() -> void:
	if not is_active or current_item == null:
		return
	if _placement_blocked:
		return
	if not GameManager.spend_essence(current_item.cost):
		_flash_ghost_red()
		return
	item_placed.emit(current_item, _snapped_pos())
	deactivate()

# ───────────────────────────────
#  PROCESS / DRAW
# ───────────────────────────────
func _process(_delta: float) -> void:
	if not is_active:
		return
	var snap := _snapped_pos()
	_placement_blocked = _is_blocked(snap)
	if is_instance_valid(_ghost):
		_ghost.global_position = snap
		_ghost.modulate = Color(1.0, 0.25, 0.25, 0.55) if _placement_blocked \
						else Color(0.5, 1.0, 0.5, 0.55)
	queue_redraw()

func _draw() -> void:
	if not is_active or grid_size <= 0:
		return

	var vp        := get_viewport()
	var inv_cam   := vp.get_canvas_transform().affine_inverse()
	var vp_size   := vp.get_visible_rect().size
	var top_left  := inv_cam * Vector2.ZERO
	var bot_right := inv_cam * vp_size

	var col_minor := Color(1.0, 1.0, 1.0, 0.10)
	var col_major := Color(1.0, 1.0, 1.0, 0.28)
	var major     := grid_size * 4

	var x: float = floor(top_left.x / grid_size) * grid_size
	while x <= bot_right.x + grid_size:
		var c: Color = col_major if int(x) % major == 0 else col_minor
		draw_line(Vector2(x, top_left.y), Vector2(x, bot_right.y), c, 0.5)
		x += grid_size

	var y: float = floor(top_left.y / grid_size) * grid_size
	while y <= bot_right.y + grid_size:
		var c: Color = col_major if int(y) % major == 0 else col_minor
		draw_line(Vector2(top_left.x, y), Vector2(bot_right.x, y), c, 0.5)
		y += grid_size

	# 스냅 위치 강조 (배치 가능: 초록 / 불가: 빨강)
	var snap  := _snapped_pos()
	var half  := grid_size * 0.5
	var rect  := Rect2(snap - Vector2(half, half), Vector2(grid_size, grid_size))
	var col_fill: Color = Color(1.0, 0.2, 0.2, 0.30) if _placement_blocked else Color(0.5, 1.0, 0.5, 0.25)
	var col_line: Color = Color(1.0, 0.2, 0.2, 0.90) if _placement_blocked else Color(0.5, 1.0, 0.5, 0.90)
	draw_rect(rect, col_fill, true)
	draw_rect(rect, col_line, false, 1.0)

# ───────────────────────────────
#  GHOST
# ───────────────────────────────
func _create_ghost() -> void:
	if current_item == null or current_item.scene == null:
		return
	# 실제 씬을 인스턴스화 → 스프라이트 오프셋·크기가 완전히 일치
	var node := current_item.scene.instantiate() as Node2D
	# add_child() 전에 스크립트·충돌 제거 → _ready() 미실행, 물리 비활성화
	_strip_ghost_node(node)
	# 스크립트가 없으니 _ready()가 실행되지 않음
	# → AnimatedSprite2D 는 씬 기본 애니메이션("off")에 멈춰 있으므로 "on"으로 강제 재생
	_ghost_play_anim(node, "on")
	_ghost = node
	_ghost.modulate = Color(0.5, 1.0, 0.5, 0.55)
	add_child(_ghost)

## 노드 트리를 재귀 탐색하여 AnimatedSprite2D 를 모두 찾아 지정 애니메이션 재생
func _ghost_play_anim(node: Node, anim: String) -> void:
	if node is AnimatedSprite2D:
		var asp := node as AnimatedSprite2D
		if asp.sprite_frames and asp.sprite_frames.has_animation(anim):
			asp.play(anim)
	for child in node.get_children():
		_ghost_play_anim(child, anim)

## 재귀적으로 스크립트 제거 + 충돌 비활성화
func _strip_ghost_node(node: Node) -> void:
	if node.get_script():
		node.set_script(null)
	for child in node.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = true
		elif child is CollisionObject2D:
			var col := child as CollisionObject2D
			col.collision_layer = 0
			col.collision_mask  = 0
		_strip_ghost_node(child)

func _destroy_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

func _flash_ghost_red() -> void:
	if not is_instance_valid(_ghost):
		return
	var tw := create_tween()
	tw.tween_property(_ghost, "modulate", Color(1.0, 0.2, 0.2, 0.7),  0.10)
	tw.tween_property(_ghost, "modulate", Color(0.5, 1.0, 0.5, 0.55), 0.15)

# ───────────────────────────────
#  HELPERS
# ───────────────────────────────
func _is_blocked(pos: Vector2) -> bool:
	if not is_inside_tree():
		return false

	# ① 기존 건물 중첩 검사
	for node in get_tree().get_nodes_in_group("placed_structure"):
		var n := node as Node2D
		if n and n.global_position.distance_to(pos) < min_place_dist:
			return true

	# ② 벽·지형 충돌 검사 (물리 공간에 쿼리)
	var space  := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position            = pos
	params.collide_with_bodies = true
	params.collide_with_areas  = false
	params.collision_mask      = 0xFFFFFFFF   # 모든 레이어 검사
	for result in space.intersect_point(params):
		var body := result["collider"] as Node
		if body == null:
			continue
		# 플레이어와 이미 배치된 건물은 제외 (빌드 블록 대상 아님)
		if body.is_in_group("player") or body.is_in_group("placed_structure"):
			continue
		return true   # 그 외 = 벽·지형 → 배치 불가

	return false

func _snapped_pos() -> Vector2:
	var pos := get_global_mouse_position()
	if grid_size <= 0:
		return pos
	return Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)

# ───────────────────────────────
#  배치 모드 키 안내 UI
# ───────────────────────────────
func _build_hint_ui() -> void:
	_hint_layer         = CanvasLayer.new()
	_hint_layer.visible = false
	add_child(_hint_layer)

	# 패널 — 우측 중앙 고정
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left   = -224
	panel.offset_right  = -16
	panel.offset_top    = -82
	panel.offset_bottom =  82
	_hint_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# 타이틀
	var title := Label.new()
	title.text                = "배치 모드"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_font(title, 15)
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)

	# 키 설명 행
	_hint_row(vbox, "좌클릭",  "설치")
	_hint_row(vbox, "우클릭",  "건설 메뉴 복귀")
	_hint_row(vbox, "B / ESC", "건설 모드 종료")

func _hint_row(parent: VBoxContainer, key: String, desc: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var key_lbl                      := Label.new()
	key_lbl.text                      = key
	key_lbl.custom_minimum_size       = Vector2(80, 0)
	key_lbl.modulate                  = Color(1.0, 0.90, 0.35)
	_hint_font(key_lbl, 13)
	row.add_child(key_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	_hint_font(desc_lbl, 13)
	row.add_child(desc_lbl)

func _hint_font(node: Control, size: int) -> void:
	if _font:
		node.add_theme_font_override("font",      _font)
		node.add_theme_font_size_override("font_size", size)
