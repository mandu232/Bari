extends Node2D
class_name MuseumHQ
## 박물관 본관 — 박물관 강화·플레이어 강화를 독립적으로 업그레이드
## 박물관 중앙에 고정 배치. 가까이 가면 [E] 키로 관리 UI 오픈.

const HQUI_SCENE := preload("res://AutoLoad/scenes/MuseumHQUI.tscn")

# ─── 최대 레벨 ────────────────────────────────────────────────────────
const MAX_MUSEUM_LEVEL := 10
const MAX_PLAYER_LEVEL := 10

# ─── 박물관 강화 (영력 배율·전시대 슬롯) ─────────────────────────────
# 인덱스 0 = 기본값(미사용), 1~10 = 레벨
const MUSEUM_LEVEL_MULT:  Array[float] = [1.0, 1.1, 1.2, 1.3, 1.4, 1.6, 1.8, 2.0, 2.3, 2.6, 3.0]
const MUSEUM_LEVEL_SLOTS: Array[int]   = [0,   1,   1,   1,   2,   1,   1,   2,   1,   2,   3  ]
const MUSEUM_UPGRADE_COST: Array[int]  = [0,   0,   150, 300, 500, 800, 1200, 1800, 2500, 3500, 5000]

# ─── 플레이어 강화 (체력·공격·속도) ──────────────────────────────────
# 인덱스 0 = 기본값(미사용), 각 레벨에서 누적되는 per-level 보너스
const PLAYER_LEVEL_HEALTH: Array[int]   = [0, 1, 1, 1, 2, 1, 1, 2, 1, 2, 2]
const PLAYER_LEVEL_DAMAGE: Array[int]   = [0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 2]
const PLAYER_LEVEL_SPEED:  Array[float] = [0.0, 0.0, 0.0, 0.5, 0.0, 0.5, 0.0, 0.5, 0.5, 1.0, 1.0]
const PLAYER_UPGRADE_COST: Array[int]   = [0,   0,   150, 300, 500, 800, 1200, 1800, 2500, 3500, 5000]

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
	if GameManager.hq_museum_level == 0:
		GameManager.hq_museum_level = 1
	if GameManager.hq_player_level == 0:
		GameManager.hq_player_level = 1
	_body_sprite.play("on")
	_stand_sprite.play("on")
	_setup_hint_label()
	_setup_interact_area()
	_setup_body_area()
	_apply_bonuses()
	call_deferred("_setup_ui")

# ─── UI 생성 (씬 트리 진입 후) ───────────────────────────────────────
func _setup_ui() -> void:
	_hq_ui = HQUI_SCENE.instantiate() as MuseumHQUI
	get_parent().add_child(_hq_ui)
	_hq_ui.setup(self)
	_hq_ui.closed.connect(_on_ui_closed)

# ─── 보너스 적용 ─────────────────────────────────────────────────────
func _apply_bonuses() -> void:
	# 박물관 보너스
	var m_lv     := GameManager.hq_museum_level
	var total_slots := 0
	for i in range(1, m_lv + 1):
		total_slots += MUSEUM_LEVEL_SLOTS[i]
	GameManager.set_hq_museum_bonuses(m_lv, MUSEUM_LEVEL_MULT[m_lv], total_slots)

	# 플레이어 보너스
	var p_lv     := GameManager.hq_player_level
	var total_health := 0
	var total_damage := 0
	var total_speed  := 0.0
	for i in range(1, p_lv + 1):
		total_health += PLAYER_LEVEL_HEALTH[i]
		total_damage += PLAYER_LEVEL_DAMAGE[i]
		total_speed  += PLAYER_LEVEL_SPEED[i]
	GameManager.set_hq_player_bonuses(p_lv, total_health, total_damage, total_speed)

# ─── 업그레이드 — 박물관 (UI 버튼에서 호출) ──────────────────────────
func try_upgrade_museum() -> void:
	var lv := GameManager.hq_museum_level
	if lv >= MAX_MUSEUM_LEVEL:
		return
	if not GameManager.spend_essence(MUSEUM_UPGRADE_COST[lv + 1]):
		return
	GameManager.hq_museum_level = lv + 1
	_apply_bonuses()
	_play_upgrade_flash()
	GameManager.save_game()

# ─── 업그레이드 — 플레이어 (UI 버튼에서 호출) ────────────────────────
func try_upgrade_player() -> void:
	var lv := GameManager.hq_player_level
	if lv >= MAX_PLAYER_LEVEL:
		return
	if not GameManager.spend_essence(PLAYER_UPGRADE_COST[lv + 1]):
		return
	GameManager.hq_player_level = lv + 1
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
	_hint_label.position             = Vector2(-55, 30)
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
	area.collision_mask = 1    # 플레이어 레이어(Layer 1 = 1, 기본값) 감지
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
		_player_nearby      = true
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
	for hud in get_tree().get_nodes_in_group("player_hud"):
		hud.hide()
	_hq_ui.open()

func _on_ui_closed() -> void:
	if _player_nearby:
		_hint_label.visible = true
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(true)
	for hud in get_tree().get_nodes_in_group("player_hud"):
		hud.show()

# ─── 입력 ────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or _hq_ui == null or _hq_ui.visible:
		return
	if event.is_action_pressed("interact"):
		_open_ui()
		get_viewport().set_input_as_handled()
