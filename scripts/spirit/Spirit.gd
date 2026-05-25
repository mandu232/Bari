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

func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	sprite.modulate.a = 1.0
	_pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(sprite, "modulate:a", 0.4, 1.8)
	_pulse_tween.tween_property(sprite, "modulate:a", 0.8,  1.8)

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
#  INTERACT
# ───────────────────────────────
func start_interact() -> void:
	state    = State.INTERACT
	velocity = Vector2.ZERO
	player_interacted.emit(self)

func end_interact() -> void:
	state       = State.IDLE
	_idle_timer = 1.0

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
		# 대화 중이 아닐 때만 튕겨나가기
		if state != State.INTERACT:
			_bump(body.global_position)

func _on_interact_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if state == State.INTERACT:
			end_interact()
