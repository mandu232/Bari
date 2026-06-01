extends Node2D
class_name ChargingStation
## 충전소 — 범위 내 전시대 에코의 출력을 지속적으로 회복시키는 시설
## 전력이 공급될 때만 효과가 활성화됩니다

# ───────────────────────────────
#  EXPORT
# ───────────────────────────────
@export var output_bonus: float = 3.5   ## 초당 출력 회복량 (0.7/s 감소를 상쇄하고 서서히 채워줌)
@export var effect_range: float = 100.0 ## 효과 반경 (픽셀)

# ───────────────────────────────
#  STATE
# ───────────────────────────────
var power_cost:     int   = 0     # museum.gd 가 배치 전에 주입
var is_powered:     bool  = false

var _player_nearby: bool  = false
var _show_range:    bool  = false
var _info_label:    Label = null

# ───────────────────────────────
#  SIGNAL
# ───────────────────────────────
signal wire_requested(source: Node2D)

# ───────────────────────────────
#  NODES
# ───────────────────────────────
@onready var _body_sprite:  AnimatedSprite2D = $Body
@onready var _stand_sprite: AnimatedSprite2D = $Stand

# ───────────────────────────────
#  READY
# ───────────────────────────────
func _ready() -> void:
	add_to_group("placed_structure")
	add_to_group("charging_station")
	is_powered = (power_cost == 0)
	_setup_interact_area()
	_setup_body_area()
	_setup_label()
	_update_visuals()

# ───────────────────────────────
#  범위 원 그리기 (_draw)
# ───────────────────────────────
func _draw() -> void:
	if not _show_range:
		return
	# 주황색 — 출력(에너지) 느낌
	draw_circle(Vector2.ZERO, effect_range, Color(1.0, 0.55, 0.1, 0.05))
	draw_arc(Vector2.ZERO, effect_range, 0.0, TAU, 72, Color(1.0, 0.55, 0.1, 0.6), 2.0)

# ───────────────────────────────
#  전력 관리 (Museum 중앙 할당)
# ───────────────────────────────
func set_powered(value: bool) -> void:
	if is_powered == value:
		return
	is_powered = value
	_update_visuals()

func _update_visuals() -> void:
	if _body_sprite and _body_sprite.sprite_frames:
		var anim: StringName = &"on" if is_powered else &"off"
		if _body_sprite.sprite_frames.has_animation(anim):
			_body_sprite.play(anim)
		if _stand_sprite.sprite_frames.has_animation(anim):
			_stand_sprite.play(anim)
	if _player_nearby:
		_update_nearby_ui()

# ───────────────────────────────
#  PROCESS — 범위 내 에코 출력 회복
# ───────────────────────────────
func _process(delta: float) -> void:
	if not is_powered:
		return
	for node in get_tree().get_nodes_in_group("placed_structure"):
		var slot := node as ArtifactSlot
		if slot == null or not slot.is_occupied:
			continue
		if not is_instance_valid(slot.echo) or slot.echo.needs == null:
			continue
		var dist := global_position.distance_to(slot.global_position)
		if dist <= effect_range:
			slot.echo.needs.fulfill(&"출력", output_bonus * delta)

# ───────────────────────────────
#  플레이어 감지 영역 생성
# ───────────────────────────────
func _setup_interact_area() -> void:
	var area   := Area2D.new()
	var shape  := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
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
	area.collision_mask = 16   # 플레이어 레이어(Layer 5 = 16) 감지
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
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.custom_minimum_size  = Vector2(110, 0)
	_info_label.position             = Vector2(-55, 17)

	var font := load("res://AutoLoad/assets/Font/DungGeunMo.ttf") as Font
	if font:
		_info_label.add_theme_font_override("font", font)
		_info_label.add_theme_font_size_override("font_size", 6)
	add_child(_info_label)

# ───────────────────────────────
#  플레이어 감지 콜백
# ───────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_show_range    = true
		_update_nearby_ui()
		queue_redraw()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby      = false
		_show_range         = false
		_info_label.visible = false
		queue_redraw()

# ───────────────────────────────
#  바디 투명화 콜백
# ───────────────────────────────
func _on_body_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_body_sprite.modulate.a = 0.3

func _on_body_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_body_sprite.modulate.a = 1.0

# ───────────────────────────────
#  UI 상태 업데이트
# ───────────────────────────────
func _update_nearby_ui() -> void:
	if not is_powered and power_cost > 0:
		_info_label.text = "⚡ 전력 없음"
		_info_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		_info_label.text = "⚡ 출력 +%.0f/s\n[F] 배선 연결" % output_bonus
		_info_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	_info_label.visible = true

# ───────────────────────────────
#  [F] 키 — 배선 요청
# ───────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or power_cost == 0:
		return
	if event.is_action_pressed("sub_interact"):
		wire_requested.emit(self)
		get_viewport().set_input_as_handled()
