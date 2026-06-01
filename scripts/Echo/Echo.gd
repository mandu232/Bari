extends CharacterBody2D
class_name Echo
## 유물에 묶인 에코
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

# 표정 애니메이션
const TALK_RANGE:        float = 80.0  # 대화 가능 거리 (픽셀)
const TALK_INTERVAL_MIN: float = 8.0   # 대화 쿨다운 최솟값 (초)
const TALK_INTERVAL_MAX: float = 20.0  # 대화 쿨다운 최댓값 (초)
const AGGRO_THRESHOLD:   float = 50.0  # 이 수치 미만이면 aggro 발동

# ───────────────────────────────
#  STATE
# ───────────────────────────────
enum State { IDLE, WANDER, BUMPED, INTERACT, WORK, RETURN_HOME }
var state: State         = State.IDLE
var _idle_timer: float  = 0.0
var _wander_timer: float = 0.0
var _target: Vector2    = Vector2.ZERO

# 건설 작업
var _construction_site: Node2D            = null
var _nav_agent:         NavigationAgent2D = null
const WORK_ARRIVE_DIST: float             = 20.0
const DEFAULT_COLLISION_MASK: int         = 1    # 기본 충돌 마스크 (Layer 1)

# 막힘 감지
var _stuck_timer:   float   = 0.0
var _stuck_last_pos: Vector2 = Vector2.ZERO

# 표정 상태
var _talk_cooldown: float = 0.0   # 다음 대화까지 남은 시간
var _is_talking:    bool  = false  # talk 애니메이션 재생 중

# ───────────────────────────────
#  NEEDS
# ───────────────────────────────
## 욕구 시스템 — 만족도·충만도·활력 관리
var needs: EchoNeedsManager = null

# ───────────────────────────────
#  STATUS UI
# ───────────────────────────────
var _player_nearby: bool           = false   # 근접 감지 영역 안에 있는지
var _canvas_layer:  CanvasLayer    = null    # 상태 패널용 스크린 레이어
var _status_panel:  EchoStatusPanel = null   # 현재 열린 상태 패널
var _hint_label:    Label          = null    # "[F] 상태 확인" 근접 힌트

# ───────────────────────────────
#  SIGNALS
# ───────────────────────────────
signal player_interacted(echo: Echo)

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
	# 에코는 유령 — 항상 건물(z_index ≈ y좌표) 위에 렌더링
	z_as_relative = false
	z_index       = 3000
	_idle_timer    = randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
	_talk_cooldown = randf_range(TALK_INTERVAL_MIN, TALK_INTERVAL_MAX)
	interact_area.body_entered.connect(_on_interact_area_entered)
	interact_area.body_exited.connect(_on_interact_area_exited)

	# NavigationAgent2D — TileMapLayer 내비게이션 사용
	_nav_agent                          = NavigationAgent2D.new()
	_nav_agent.path_desired_distance    = 4.0
	_nav_agent.target_desired_distance  = WORK_ARRIVE_DIST
	_nav_agent.path_max_distance        = 24.0   # 이 거리 이상 이탈 시 경로 재계산
	add_child(_nav_agent)

	# 욕구 시스템 초기화
	needs = EchoNeedsManager.new()
	add_child(needs)
	needs.mood_changed.connect(_on_mood_changed)
	needs.need_critical.connect(_on_need_critical)

	# 표정 애니메이션 종료 감지
	sprite.animation_finished.connect(_on_animation_finished)

	# 에코 그룹 등록 — 대화 상대 탐색에 사용
	add_to_group("echo")

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
		# echo_frames 가 지정된 경우 교체, 없으면 씬 기본값 유지
		if artifact_data.echo_frames:
			sprite.sprite_frames = artifact_data.echo_frames
		sprite.play("float")
	if name_label:
		name_label.text = artifact_data.echo_name

	# 유물별 욕구 감소율 적용 (needs 가 초기화된 뒤에만 실행)
	if needs:
		needs.set_decay(&"안정도", artifact_data.stability_decay)
		needs.set_decay(&"출력",   artifact_data.output_decay)
		needs.set_decay(&"활성도", artifact_data.activity_decay)

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
	var cur_mood := needs.mood if needs else &"유지"
	match cur_mood:
		&"안정":
			speed    = 0.9    # 빠른 활기찬 펄스
			alpha_lo = 0.6
			alpha_hi = 1.0
		&"불안정":
			speed    = 2.8    # 느린 불안정 펄스
			alpha_lo = 0.3
			alpha_hi = 0.65
		&"붕괴":
			speed    = 4.0    # 매우 느리고 희미한 펄스
			alpha_lo = 0.15
			alpha_hi = 0.45
		_:                    # 유지
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
func _process(delta: float) -> void:
	_update_expression(delta)

func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:        _process_idle(delta)
		State.WANDER:      _process_wander(delta)
		State.BUMPED:      _process_bumped(delta)
		State.INTERACT:    pass
		State.WORK:        _process_work(delta)
		State.RETURN_HOME: _process_return_home(delta)

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
	# 상호작용 시 안정도·활성도 회복
	if needs:
		needs.fulfill(&"안정도", 22.0)
		needs.fulfill(&"활성도", 12.0)
	player_interacted.emit(self)

func end_interact() -> void:
	state       = State.IDLE
	_idle_timer = 1.0

# ───────────────────────────────
#  WORK — 건설 현장으로 이동 후 작업
# ───────────────────────────────
func start_work(site: Node2D) -> void:
	_construction_site = site
	state              = State.WORK
	velocity           = Vector2.ZERO
	_stuck_timer       = 0.0
	_stuck_last_pos    = global_position
	# 에코끼리 물리 충돌 제거 (유령이므로 서로 통과), 벽은 nav agent가 우회
	collision_mask     = 0

func stop_work() -> void:
	_construction_site = null
	# 충돌은 집 도착 후 복원 — 귀환 중에도 에코끼리 통과
	state              = State.RETURN_HOME
	_stuck_timer       = 0.0
	_stuck_last_pos    = global_position
	_nav_agent.target_position = home_position

func _process_work(delta: float) -> void:
	if not is_instance_valid(_construction_site):
		stop_work()
		return

	var target := _construction_site.global_position

	if global_position.distance_to(target) <= WORK_ARRIVE_DIST:
		velocity     = Vector2.ZERO
		_stuck_timer = 0.0
		move_and_slide()
		return

	_nav_agent.target_position = target

	# 막힘 감지 — 0.8초 동안 5px 미만 이동 시 경로 강제 재계산
	_stuck_timer += delta
	if _stuck_timer >= 0.8:
		if global_position.distance_to(_stuck_last_pos) < 5.0:
			_nav_agent.target_position = target  # 경로 재요청
		_stuck_last_pos = global_position
		_stuck_timer    = 0.0

	var next_pos := _nav_agent.get_next_path_position()
	var dir      := (next_pos - global_position).normalized()
	if dir.length_squared() < 0.01:
		dir = (target - global_position).normalized()  # 폴백
	velocity = dir * MOVE_SPEED
	_target  = global_position + dir
	_face_target()
	move_and_slide()

# ───────────────────────────────
#  RETURN_HOME — 건설 완료 후 집 귀환
# ───────────────────────────────
func _process_return_home(delta: float) -> void:
	var dist := global_position.distance_to(home_position)
	if dist <= HOME_THRESHOLD * 4.0:
		velocity       = Vector2.ZERO
		collision_mask = DEFAULT_COLLISION_MASK  # 집 도착 시 충돌 복원
		state          = State.IDLE
		_idle_timer    = randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
		move_and_slide()
		return

	# 막힘 감지
	_stuck_timer += delta
	if _stuck_timer >= 0.8:
		if global_position.distance_to(_stuck_last_pos) < 5.0:
			_nav_agent.target_position = home_position
		_stuck_last_pos = global_position
		_stuck_timer    = 0.0

	var next_pos := _nav_agent.get_next_path_position()
	var dir      := (next_pos - global_position).normalized()
	if dir.length_squared() < 0.01:
		dir = (home_position - global_position).normalized()
	velocity = dir * MOVE_SPEED
	_target  = global_position + dir
	_face_target()
	move_and_slide()

# ───────────────────────────────
#  표정 애니메이션 시스템
#  우선순위: tired > aggro > talk > float
# ───────────────────────────────
## 매 프레임 욕구 상태를 평가해 적절한 표정 애니메이션 적용
func _update_expression(delta: float) -> void:
	if needs == null:
		return

	# 우선순위 1 — 0%인 욕구 존재 → tired
	for need: EchoNeed in needs.get_all_needs():
		if need.value <= 0.0:
			_is_talking = false
			_play_expression(&"tired")
			return

	# 우선순위 2 — 50% 미만 욕구 존재 → aggro
	for need: EchoNeed in needs.get_all_needs():
		if need.value < AGGRO_THRESHOLD:
			_is_talking = false
			_play_expression(&"aggro")
			return

	# talk 애니메이션 재생 중이면 완료 대기
	if _is_talking:
		return

	# 우선순위 3 — 건설 현장에 도착한 경우만 work 애니메이션 (이동 중엔 float)
	if state == State.WORK and _is_at_work_site():
		_play_expression(&"work")
		return

	# 기본 float 유지
	_play_expression(&"float")

	# 대화 쿨다운 감소 후 주변 에코 탐색
	_talk_cooldown -= delta
	if _talk_cooldown <= 0.0:
		_try_start_talk()

## 애니메이션 이름이 있고, 아직 재생 중이 아닐 때만 재생
func _play_expression(anim: StringName) -> void:
	if not is_instance_valid(sprite) or not sprite.sprite_frames:
		return
	if not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation == anim and sprite.is_playing():
		return   # 이미 재생 중이면 중단하지 않음
	sprite.play(anim)

## 반경 내 다른 에코를 탐색해 대화 시도
func _try_start_talk() -> void:
	for node in get_tree().get_nodes_in_group("echo"):
		if node == self:
			continue
		var other := node as Echo
		if other == null or other._is_talking:
			continue
		if global_position.distance_to(other.global_position) <= TALK_RANGE:
			_start_talk()
			return
	# 대화 상대 없으면 쿨다운만 리셋
	_talk_cooldown = randf_range(TALK_INTERVAL_MIN, TALK_INTERVAL_MAX)

func _start_talk() -> void:
	_is_talking    = true
	_talk_cooldown = randf_range(TALK_INTERVAL_MIN, TALK_INTERVAL_MAX)
	_play_expression(&"talk")

## 비루프 애니메이션(talk 등) 종료 시 상태 재평가
func _on_animation_finished() -> void:
	if sprite.animation == &"talk":
		_is_talking = false
	# 즉시 재평가 — tired·aggro 조건이면 바로 전환, 아니면 float 복귀
	_update_expression(0.0)

# ───────────────────────────────
#  NEEDS 콜백 — 기분 변화 시 비주얼 갱신
# ───────────────────────────────
func _on_mood_changed(new_mood: StringName) -> void:
	# 색조 변경 없음 — 알파(펄스)만 유지

	# 상태에 따라 배회 반경 조정 — 안정적일수록 멀리, 붕괴 시 구석에만
	if artifact_data:
		match new_mood:
			&"안정":   wander_radius = artifact_data.wander_radius * 1.4
			&"불안정": wander_radius = artifact_data.wander_radius * 0.5
			&"붕괴":   wander_radius = artifact_data.wander_radius * 0.15
			_:         wander_radius = artifact_data.wander_radius

	# 펄스 속도·밝기 재시작
	_start_pulse()

## 수치가 위험 구간("고통"/"고갈")에 진입했을 때 반응
func _on_need_critical(need: EchoNeed) -> void:
	# TODO: 말풍선 또는 느낌표 이펙트 추가
	push_warning("Echo [%s] 의 %s 이 위험합니다 (%.0f%%)" \
		% [name, need.label, need.get_ratio() * 100.0])

# ───────────────────────────────
#  HELPERS
# ───────────────────────────────

func _is_at_work_site() -> bool:
	if not is_instance_valid(_construction_site):
		return false
	return global_position.distance_to(_construction_site.global_position) <= WORK_ARRIVE_DIST

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
		# 건설 중·상호작용 중·패널 열림 상태에선 튕기지 않음
		if state != State.INTERACT and state != State.WORK \
				and not is_instance_valid(_status_panel):
			_bump(body.global_position)

func _on_interact_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if state == State.INTERACT:
			end_interact()

# ───────────────────────────────
#  상태 확인 UI
# ───────────────────────────────
## 기존 interact_area(20px)보다 넓은 감지 영역(50px) — Echo에 닿지 않아도 F 누를 수 있음
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

	_status_panel = EchoStatusPanel.new()
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
