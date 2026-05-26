extends CharacterBody2D
class_name Spirit
## 유물에 묶인 혼(魂)
## ArtifactSlot 이 생성하며, home_position 주변을 배회

# ───────────────────────────────
#  설정 (ArtifactSlot 이 주입)
# ───────────────────────────────
var artifact_data: ArtifactData = null
var home_position: Vector2      = Vector2.ZERO  # 전시대 위치
var wander_radius: float        = 64.0

var _pulse_tween:   Tween = null
var _squeeze_tween: Tween = null

# ───────────────────────────────
#  이동 설정
# ───────────────────────────────
const MOVE_SPEED:       float = 28.0
const IDLE_TIME_MIN:    float = 1.5
const IDLE_TIME_MAX:    float = 4.0
const WANDER_TIME_MAX:  float = 3.0
const HOME_THRESHOLD:   float = 4.0

# 튕겨나가기
const BUMP_FORCE:       float = 120.0  # 밀려나는 속도
const BUMP_FRICTION:    float = 280.0  # 감속 세기

# ───────────────────────────────
#  STATE
# ───────────────────────────────
enum State { IDLE, WANDER, BUMPED, INTERACT }
var state: State         = State.IDLE
var _idle_timer: float  = 0.0
var _wander_timer: float = 0.0
var _target: Vector2    = Vector2.ZERO

# ───────────────────────────────
#  NEEDS
# ───────────────────────────────
## 욕구 시스템 — 만족도·충만도·활력 관리
var needs: SpiritNeedsManager = null

# ───────────────────────────────
#  STATUS UI
# ───────────────────────────────
var _player_nearby: bool              = false   # 근접 감지 영역 안에 있는지
var _canvas_layer:  CanvasLayer       = null    # 상태 패널용 스크린 레이어
var _status_panel:  SpiritStatusPanel = null    # 현재 열린 상태 패널
var _hint_label:    Label             = null    # "[F] 상태 확인" 근접 힌트

# ───────────────────────────────
#  SIGNALS
# ───────────────────────────────
signal player_interacted(spirit: Spirit)

# ───────────────────────────────
#  NODES
# ───────────────────────────────
@onready var sprite:          AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area:   Area2D           = $InteractArea
@onready var name_label:      Label            = $NameLabel

# ───────────────────────────────
#  READY
# ───────────────────────────────
func _ready() -> void:
	_idle_timer = randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
	interact_area.body_entered.connect(_on_interact_area_entered)
	interact_area.body_exited.connect(_on_interact_area_exited)

	# 욕구 시스템 초기화
	needs = SpiritNeedsManager.new()
	add_child(needs)
	needs.mood_changed.connect(_on_mood_changed)
	needs.need_critical.connect(_on_need_critical)

	# 상태 확인 근접 감지 + 힌트 레이블
	_setup_status_area()
	_setup_hint_label()

	# 데이터 주입 후 초기화
	if artifact_data:
		_apply_data()

## ArtifactSlot 이 호출 — 생성 직후 데이터 주입
func setup(data: ArtifactData, home: Vector2) -> void:
	artifact_data = data
	home_position = home
	wander_radius = data.wander_radius
	global_position = home
	if is_inside_tree():
		_apply_data()

func _apply_data() -> void:
	if sprite:
		# spirit_frames 가 지정된 경우 교체, 없으면 씬 기본값 유지
		if artifact_data.spirit_frames:
			sprite.sprite_frames = artifact_data.spirit_frames
		sprite.play("float")
	if name_label:
		name_label.text = artifact_data.spirit_name
	_start_pulse()
	_start_squeeze()

# ───────────────────────────────
#  펄스 (알파 호흡) 애니메이션
#  기분에 따라 속도·밝기 범위가 달라짐
# ───────────────────────────────
func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	sprite.modulate.a = 1.0

	# 기분별 파라미터
	var speed:    float
	var alpha_lo: float
	var alpha_hi: float
	var cur_mood := needs.mood if needs else &"보통"
	match cur_mood:
		&"행복":
			speed    = 0.9    # 빠른 활기찬 펄스
			alpha_lo = 0.6
			alpha_hi = 1.0
		&"불만":
			speed    = 2.8    # 느린 축 처진 펄스
			alpha_lo = 0.3
			alpha_hi = 0.65
		&"고통":
			speed    = 4.0    # 매우 느리고 희미한 펄스
			alpha_lo = 0.15
			alpha_hi = 0.45
		_:                    # 보통
			speed    = 1.8
			alpha_lo = 0.4
			alpha_hi = 0.8

	_pulse_tween = create_tween().set_loops() \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(sprite, "modulate:a", alpha_lo, speed)
	_pulse_tween.tween_property(sprite, "modulate:a", alpha_hi, speed)

func _start_squeeze() -> void:
	if _squeeze_tween and _squeeze_tween.is_valid():
		_squeeze_tween.kill()
	sprite.scale = Vector2.ONE
	_squeeze_tween = create_tween().set_loops()
	# 위로 늘어남 (y 크게, x 좁게)
	_squeeze_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.85) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 아래로 눌림 (y 작게, x 넓게)
	_squeeze_tween.tween_property(sprite, "scale", Vector2(1.05, 0.92), 0.85) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ───────────────────────────────
#  PROCESS
# ───────────────────────────────
func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:     _process_idle(delta)
		State.WANDER:   _process_wander(delta)
		State.BUMPED:   _process_bumped(delta)
		State.INTERACT: pass

# ───────────────────────────────
#  IDLE — 제자리에서 대기
# ───────────────────────────────
func _process_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	_idle_timer -= delta

	if _idle_timer <= 0.0:
		_start_wander()

# ───────────────────────────────
#  WANDER — home 주변 랜덤 지점으로 이동
# ───────────────────────────────
func _start_wander() -> void:
	_target       = _pick_wander_target()
	state         = State.WANDER
	_wander_timer = WANDER_TIME_MAX
	_face_target()

func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	var dist := global_position.distance_to(_target)

	if dist < HOME_THRESHOLD or _wander_timer <= 0.0:
		velocity    = Vector2.ZERO
		state       = State.IDLE
		_idle_timer = randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
		move_and_slide()
		return

	var dir := (_target - global_position).normalized()
	velocity = dir * MOVE_SPEED
	_face_target()
	move_and_slide()

# ───────────────────────────────
#  BUMPED — 플레이어에 밀려난 뒤 감속
# ───────────────────────────────
func _bump(source_pos: Vector2) -> void:
	var dir := (global_position - source_pos).normalized()
	velocity = dir * BUMP_FORCE
	state    = State.BUMPED

func _process_bumped(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, BUMP_FRICTION * delta)
	move_and_slide()
	# 거의 멈추면 IDLE 복귀
	if velocity.length() < 2.0:
		velocity    = Vector2.ZERO
		state       = State.IDLE
		_idle_timer = randf_range(0.5, 1.5)

# ───────────────────────────────
#  INTERACT — 플레이어 상호작용
# ───────────────────────────────
func start_interact() -> void:
	state    = State.INTERACT
	velocity = Vector2.ZERO
	# 상호작용 시 만족도·활력 회복
	if needs:
		needs.fulfill(&"만족도", 22.0)
		needs.fulfill(&"활력",   12.0)
	player_interacted.emit(self)

func end_interact() -> void:
	state       = State.IDLE
	_idle_timer = 1.0

# ───────────────────────────────
#  NEEDS 콜백 — 기분 변화 시 비주얼 갱신
# ───────────────────────────────
func _on_mood_changed(new_mood: StringName) -> void:
	# 스프라이트 색조
	var base_color: Color
	match new_mood:
		&"행복": base_color = Color(1.05, 0.98, 0.75)   # 따뜻한 황금빛
		&"불만": base_color = Color(0.80, 0.85, 0.95)   # 차가운 회청
		&"고통": base_color = Color(1.00, 0.52, 0.52)   # 붉은 고통
		_:       base_color = Color.WHITE
	# alpha 는 펄스 트윈이 관리하므로 RGB 만 교체
	sprite.modulate = Color(base_color.r, base_color.g, base_color.b,
							sprite.modulate.a)

	# 기분에 따라 배회 반경 조정 — 행복할수록 멀리, 고통스러우면 구석에만
	if artifact_data:
		match new_mood:
			&"행복": wander_radius = artifact_data.wander_radius * 1.4
			&"불만": wander_radius = artifact_data.wander_radius * 0.5
			&"고통": wander_radius = artifact_data.wander_radius * 0.15
			_:       wander_radius = artifact_data.wander_radius

	# 펄스 속도·밝기 재시작
	_start_pulse()

## 수치가 위험 구간("고통"/"고갈")에 진입했을 때 반응
func _on_need_critical(need: SpiritNeed) -> void:
	# TODO: 말풍선 또는 느낌표 이펙트 추가
	push_warning("혼 [%s] 의 %s 이 위험합니다 (%.0f%%)" \
		% [name, need.label, need.get_ratio() * 100.0])

# ───────────────────────────────
#  HELPERS
# ───────────────────────────────

## home_position 중심, wander_radius 안의 랜덤 점
func _pick_wander_target() -> Vector2:
	var angle  := randf_range(0.0, TAU)
	var radius := randf_range(wander_radius * 0.2, wander_radius)
	return home_position + Vector2(cos(angle), sin(angle)) * radius

func _face_target() -> void:
	var dx := _target.x - global_position.x
	if absf(dx) > 1.0:
		sprite.flip_h = dx < 0.0

func _on_interact_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# 상태 패널이 열려 있거나 대화 중이면 튕기지 않음
		if state != State.INTERACT and not is_instance_valid(_status_panel):
			_bump(body.global_position)

func _on_interact_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if state == State.INTERACT:
			end_interact()

# ───────────────────────────────
#  상태 확인 UI
# ───────────────────────────────
## 기존 interact_area(20px)보다 넓은 감지 영역(50px) — 정령에 닿지 않아도 F 누를 수 있음
func _setup_status_area() -> void:
	var area   := Area2D.new()
	var shape  := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 50.0
	shape.shape   = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_status_area_entered)
	area.body_exited.connect(_on_status_area_exited)

## "[F] 상태 확인" 힌트 레이블 — 스프라이트 위에 표시
func _setup_hint_label() -> void:
	_hint_label                      = Label.new()
	_hint_label.visible              = false
	_hint_label.text                 = "[F] 상태 확인"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.custom_minimum_size  = Vector2(80, 0)
	_hint_label.position             = Vector2(-40, -20)
	var font := load("res://AutoLoad/assets/Font/DungGeunMo.ttf") as Font
	if font:
		_hint_label.add_theme_font_override("font", font)
		_hint_label.add_theme_font_size_override("font_size", 6)
	_hint_label.add_theme_color_override("font_color", Color(0.70, 0.90, 1.0))
	add_child(_hint_label)

func _on_status_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		# 패널이 닫혀 있을 때만 힌트 표시
		if not is_instance_valid(_status_panel) and _hint_label:
			_hint_label.visible = true

func _on_status_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		if _hint_label:
			_hint_label.visible = false
		_close_status_panel()

## [F] 키 — 상태 패널 열기/닫기 토글
func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby:
		return
	if event.is_action_pressed("sub_interact"):
		_toggle_status_panel()
		get_viewport().set_input_as_handled()

func _toggle_status_panel() -> void:
	if is_instance_valid(_status_panel):
		_close_status_panel()
	else:
		_open_status_panel()

func _open_status_panel() -> void:
	# CanvasLayer (layer=10) 를 씬 루트에 붙여 화면 좌표로 렌더링
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 10
	get_tree().get_root().add_child(_canvas_layer)

	_status_panel = SpiritStatusPanel.new()
	_canvas_layer.add_child(_status_panel)
	_status_panel.setup(self)

	# 패널 안에 "[F] 닫기" 가 표시되므로 힌트 레이블 숨김
	if _hint_label:
		_hint_label.visible = false

func _close_status_panel() -> void:
	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	_canvas_layer = null
	_status_panel = null
	# 여전히 근처에 있으면 힌트 복원
	if _hint_label and _player_nearby:
		_hint_label.visible = true
