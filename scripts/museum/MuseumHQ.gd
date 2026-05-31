extends Node2D
class_name MuseumHQ
## 박물관 본관 — 전역 영력 배율·플레이어 능력치 강화 및 박물관 확장
## 박물관 중앙에 고정 배치. 가까이 가면 [E] 키로 관리 UI 오픈.

# ─── 레벨별 보너스 정의 (인덱스 0은 미사용) ─────────────────────────
const LEVEL_HEALTH:  Array[int]   = [0, 1, 1, 1]
const LEVEL_DAMAGE:  Array[int]   = [0, 0, 1, 1]
const LEVEL_SPEED:   Array[float] = [0.0, 0.0, 0.0, 0.5]
const LEVEL_MULT:    Array[float] = [1.0, 1.2, 1.4, 1.6]
const LEVEL_SLOTS:   Array[int]   = [0, 2, 2, 2]
const UPGRADE_COST:  Array[int]   = [0, 0, 200, 400]
const MAX_LEVEL := 3

# ─── 노드 참조 ───────────────────────────────────────────────────────
@onready var _body_sprite:  AnimatedSprite2D = $Body
@onready var _stand_sprite: AnimatedSprite2D = $Stand

# ─── 상태 ────────────────────────────────────────────────────────────
var _player_nearby: bool       = false
var _hint_label:    Label      = null
var _hq_ui:         MuseumHQUI = null

# ─── 준비 ────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("museum_hq")
	if GameManager.museum_hq_level == 0:
		GameManager.museum_hq_level = 1
	_body_sprite.play("on")
	_stand_sprite.play("on")
	_setup_hint_label()
	_setup_interact_area()
	_setup_body_area()
	_apply_bonuses()
	call_deferred("_setup_ui")

# ─── UI 생성 (씬 트리 진입 후) ───────────────────────────────────────
func _setup_ui() -> void:
	_hq_ui = MuseumHQUI.new()
	get_parent().add_child(_hq_ui)
	_hq_ui.setup(self)
	_hq_ui.closed.connect(_on_ui_closed)

# ─── 보너스 적용 ─────────────────────────────────────────────────────
func _apply_bonuses() -> void:
	var lv := GameManager.museum_hq_level
	var total_health := 0
	var total_damage := 0
	var total_speed  := 0.0
	var total_slots  := 0
	for i in range(1, lv + 1):
		total_health += LEVEL_HEALTH[i]
		total_damage += LEVEL_DAMAGE[i]
		total_speed  += LEVEL_SPEED[i]
		total_slots  += LEVEL_SLOTS[i]
	GameManager.set_hq_bonuses(lv, LEVEL_MULT[lv], total_health, total_damage, total_speed, total_slots)

# ─── 업그레이드 (UI 버튼에서 호출) ──────────────────────────────────
func try_upgrade() -> void:
	var lv := GameManager.museum_hq_level
	if lv >= MAX_LEVEL:
		return
	var cost := UPGRADE_COST[lv + 1]
	if not GameManager.spend_essence(cost):
		return
	GameManager.museum_hq_level = lv + 1
	_apply_bonuses()
	_play_upgrade_flash()
	GameManager.save_game()

func _play_upgrade_flash() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.5, 1.4, 0.6, 1.0), 0.1)
	tw.tween_property(self, "modulate", Color.WHITE, 0.35)

# ─── 힌트 레이블 ─────────────────────────────────────────────────────
func _setup_hint_label() -> void:
	var font := load("res://AutoLoad/assets/Font/DungGeunMo.ttf") as Font
	_hint_label                      = Label.new()
	_hint_label.visible              = false
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.custom_minimum_size  = Vector2(110, 0)
	_hint_label.position             = Vector2(-55, 28)
	_hint_label.text                 = "[E] 관리하기"
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	if font:
		_hint_label.add_theme_font_override("font", font)
		_hint_label.add_theme_font_size_override("font_size", 6)
	add_child(_hint_label)

# ─── 플레이어 감지 영역 ──────────────────────────────────────────────
func _setup_interact_area() -> void:
	var area   := Area2D.new()
	var shape  := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 28.0
	shape.shape   = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

# ─── Body 투명화 감지 영역 ───────────────────────────────────────────
func _setup_body_area() -> void:
	var area  := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size      = Vector2(24, 32)
	shape.shape    = rect
	shape.position = Vector2(0, -18)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_area_entered)
	area.body_exited.connect(_on_body_area_exited)

# ─── 플레이어 감지 콜백 ──────────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby     = true
		_hint_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby      = false
		_hint_label.visible = false

# ─── Body 투명화 콜백 ────────────────────────────────────────────────
func _on_body_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_body_sprite.modulate.a = 0.3

func _on_body_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_body_sprite.modulate.a = 1.0

# ─── UI 열기 / 닫기 ──────────────────────────────────────────────────
func _open_ui() -> void:
	_hint_label.visible = false
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
	_hq_ui.open()

func _on_ui_closed() -> void:
	if _player_nearby:
		_hint_label.visible = true
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(true)

# ─── 입력 ────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or _hq_ui == null or _hq_ui.visible:
		return
	if event.is_action_pressed("interact"):
		_open_ui()
		get_viewport().set_input_as_handled()
