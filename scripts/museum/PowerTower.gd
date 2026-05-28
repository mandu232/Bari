extends Node2D
class_name PowerTower
## 송전탑 — 발전소(또는 다른 탑)의 전력을 중계하여 더 먼 건물에 전달

# ───────────────────────────────
#  EXPORT
# ───────────────────────────────
@export var relay_capacity: int   = 60    ## 최대 중계 전력량
@export var chain_range:    float = 200.0 ## 수동 배선 최대 거리 (탑↔탑, 발전소↔탑)
@export var output_range:   float = 120.0 ## 건물에 자동 전력 공급 반경 (탑→슬롯)

# ───────────────────────────────
#  SIGNAL
# ───────────────────────────────
## 플레이어가 근처에서 [F]를 눌렀을 때 — Museum 이 배선 시작 또는 완료를 처리
signal wire_requested(source: Node2D)

# ───────────────────────────────
#  RUNTIME STATE  (_reallocate_power 에서 매 프레임 초기화됨)
# ───────────────────────────────
var is_active:      bool    = false  # 이번 할당 사이클에서 전원과 연결됐는지
var remaining_relay: int    = 0      # 남은 중계 가능 전력량
var source:         Node2D  = null   # 연결된 상위 전원 노드 (PowerPlant 또는 PowerTower)

# ───────────────────────────────
#  INTERNAL
# ───────────────────────────────
@onready var _body_sprite:    AnimatedSprite2D = $Body
var           _info_label:    Label           = null
var           _show_range:    bool            = false
var           _player_in_body: bool           = false

# ───────────────────────────────
#  READY
# ───────────────────────────────
func _ready() -> void:
	add_to_group("placed_structure")
	add_to_group("power_tower")
	_setup_interact_area()
	_setup_body_area()
	_setup_label()

# ───────────────────────────────
#  범위 원 그리기
# ───────────────────────────────
func _draw() -> void:
	if not _show_range:
		return
	# 수동 배선 거리 (파란색 — 탑↔탑, 발전소↔탑 수동 연결 한계)
	draw_circle(Vector2.ZERO, chain_range,  Color(0.3, 0.7, 1.0, 0.05))
	draw_arc(Vector2.ZERO,    chain_range,  0.0, TAU, 72, Color(0.3, 0.7, 1.0, 0.6), 2.0)
	# 자동 공급 범위 (노란색 — 건물에 자동으로 전력 공급되는 반경)
	draw_circle(Vector2.ZERO, output_range, Color(1.0, 0.88, 0.25, 0.07))
	draw_arc(Vector2.ZERO,    output_range, 0.0, TAU, 72, Color(1.0, 0.88, 0.25, 0.75), 2.0)

# ───────────────────────────────
#  플레이어 감지 영역 생성
# ───────────────────────────────
func _setup_interact_area() -> void:
	var area   := Area2D.new()
	var shape  := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape   = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

# ───────────────────────────────
#  바디 투명화 감지 영역 생성
# ───────────────────────────────
func _setup_body_area() -> void:
	var area  := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size      = Vector2(14, 32)
	shape.shape    = rect
	shape.position = Vector2(0, -9)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_area_entered)
	area.body_exited.connect(_on_body_area_exited)

# ───────────────────────────────
#  정보 레이블 생성
# ───────────────────────────────
func _setup_label() -> void:
	_info_label                      = Label.new()
	_info_label.visible              = false
	_info_label.text                 = "⚡ 중계 %d" % relay_capacity
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.custom_minimum_size  = Vector2(80, 0)
	_info_label.position             = Vector2(-40, 14)

	var font := load("res://AutoLoad/assets/Font/DungGeunMo.ttf") as Font
	if font:
		_info_label.add_theme_font_override("font", font)
		_info_label.add_theme_font_size_override("font_size", 6)
	_info_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	add_child(_info_label)

# ───────────────────────────────
#  플레이어 감지 콜백
# ───────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_info_label.text    = "⚡ 중계 %d\n[F] 전선 연결" % relay_capacity
		_info_label.visible = true
		_show_range         = true
		queue_redraw()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_info_label.text    = "⚡ 중계 %d" % relay_capacity
		_info_label.visible = false
		_show_range         = false
		queue_redraw()

# ───────────────────────────────
#  바디 투명화 콜백
# ───────────────────────────────
func _on_body_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_body        = true
		_body_sprite.modulate.a = 0.3

func _on_body_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_body        = false
		_body_sprite.modulate.a = 1.0

# ───────────────────────────────
#  [F] 키 — 배선 요청
# ───────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not _show_range:   # 플레이어가 근처에 없으면 무시
		return
	if event.is_action_pressed("sub_interact"):
		wire_requested.emit(self)
		get_viewport().set_input_as_handled()

# ───────────────────────────────
#  비주얼 갱신 — _reallocate_power() 완료 후 Museum 에서 호출
# ───────────────────────────────
func refresh_visuals() -> void:
	if _body_sprite == null:
		return
	var alpha              := 0.3 if _player_in_body else 1.0
	_body_sprite.modulate   = Color(1, 1, 1, alpha)
	_body_sprite.play("on" if is_active else "off")

# ───────────────────────────────
#  CLEANUP
# ───────────────────────────────
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# 탑은 전력을 생산하지 않으므로 GameManager 호출 불필요
		remove_from_group("power_tower")
