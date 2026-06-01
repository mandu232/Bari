extends Node2D
class_name PowerPlant
## 발전소 — 범위 기반 전력 공급원

# ───────────────────────────────
#  EXPORT
# ───────────────────────────────
@export var power_output: int   = 20    ## 공급 전력량 (HUD 표시용)
@export var power_range:  float = 150.0 ## 전력 공급 반경 (픽셀)

# ───────────────────────────────
#  SIGNAL
# ───────────────────────────────
## 플레이어가 근처에서 [F]를 눌렀을 때 — Museum 이 배선을 처리
signal wire_requested(source: Node2D)

# ───────────────────────────────
#  STATE
# ───────────────────────────────
var _info_label:    Label = null
var _show_range:    bool  = false   # 범위 원 표시 여부 겸 플레이어 근접 여부

# ───────────────────────────────
#  INTERNAL
# ───────────────────────────────
@onready var _body_sprite:    AnimatedSprite2D = $Body
var           _player_in_body: bool           = false

# ───────────────────────────────
#  READY
# ───────────────────────────────
func _ready() -> void:
	add_to_group("placed_structure")
	add_to_group("power_plant")         # 슬롯이 범위 탐색에 사용
	GameManager.add_power_source(power_output)
	_body_sprite.play("on")
	_setup_interact_area()
	_setup_body_area()
	_setup_label()

# ───────────────────────────────
#  범위 원 그리기 (_draw)
# ───────────────────────────────
func _draw() -> void:
	if not _show_range:
		return
	# 반투명 채우기
	draw_circle(Vector2.ZERO, power_range, Color(0.3, 0.7, 1.0, 0.05))
	# 외곽 실선
	draw_arc(Vector2.ZERO, power_range, 0.0, TAU, 72, Color(0.3, 0.7, 1.0, 0.6), 2.0)

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

# ───────────────────────────────
#  정보 레이블 생성
# ───────────────────────────────
func _setup_label() -> void:
	_info_label                      = Label.new()
	_info_label.visible              = false
	_info_label.text                 = "⚡ 전력 +%d" % power_output
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.custom_minimum_size  = Vector2(90, 0)
	_info_label.position             = Vector2(-45, 17)

	var font := load("res://AutoLoad/assets/Font/DungGeunMo.ttf") as Font
	if font:
		_info_label.add_theme_font_override("font", font)
		_info_label.add_theme_font_size_override("font_size", 6)
	_info_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	add_child(_info_label)

# ───────────────────────────────
#  플레이어 감지 콜백
# ───────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_info_label.text    = "⚡ 전력 +%d\n[F] 전선 연결" % power_output
		_info_label.visible = true
		_show_range         = true
		queue_redraw()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_info_label.text    = "⚡ 전력 +%d" % power_output
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
#  CLEANUP — 노드 제거 시 전력 해제
# ───────────────────────────────
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# 슬롯 재확인 전에 그룹에서 제거해야 해제된 발전기가 범위에 잡히지 않음
		remove_from_group("power_plant")
		GameManager.remove_power_source(power_output)
