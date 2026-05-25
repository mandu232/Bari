extends CharacterBody2D

# ───────────────────────────────
#  STATS
# ───────────────────────────────
@export_group("Movement")
@export var move_speed: float    = 110.0
@export var dash_speed: float    = 210.0
@export var dash_duration: float = 0.57
@export var dash_cooldown: float = 1.0

@export_group("Combat")
@export var max_health: int      = 6
@export var attack_damage: int   = 2
@export var combo_window: float  = 0.45

# ───────────────────────────────
#  방향 suffix 를 붙일 애니메이션 목록
#  여기 없는 이름(death, hit 등)은 suffix 없이 그대로 재생
# ───────────────────────────────
const DIRECTIONAL_ANIMS: Array[String] = [
	"idle", "walk", "dash",
	"attack_1", "attack_2", "attack_3", "attack_4",
	"attack_sheathe",
]

# ───────────────────────────────
#  프레임 히트박스 설정
#  키 = 콤보 인덱스(0~3) — 방향 무관하게 동일 프레임 적용
# ───────────────────────────────
const HIT_FRAMES: Dictionary = {
	0: [0, 1, 2],       # attack_1
	1: [1, 2, 3],       # attack_2
	2: [0, 1, 2, 3],    # attack_3
	3: [1, 2, 3, 4],    # attack_4
}

# ───────────────────────────────
#  STATE
# ───────────────────────────────
enum State { IDLE, MOVE, DASH, ATTACK, HIT, DEAD }
var state: State        = State.IDLE
var facing: Vector2     = Vector2.DOWN
var is_invincible: bool = false
var health: int

var _dash_timer: float    = 0.0
var _dash_cd_timer: float = 0.0
var _dash_dir: Vector2    = Vector2.ZERO

var _combo_index: int    = 0
var _combo_timer: float  = 0.0
var _attack_active: bool = false
var _combo_queued: bool  = false
var _sheathing: bool     = false  # 검 집어넣기 재생 중

# ───────────────────────────────
#  SIGNALS
# ───────────────────────────────
signal health_changed(current: int, maximum: int)
signal player_died
signal essence_collected(amount: int)

# ───────────────────────────────
#  NODES
# ───────────────────────────────
@onready var sprite:         AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_box:       Area2D           = $HurtBox
@onready var attack_box:     Area2D           = $AttackBox
@onready var attack_shape:   CollisionShape2D = $AttackBox/CollisionShape2D
@onready var dash_particles: GPUParticles2D   = $DashParticles
@onready var inv_timer:      Timer            = $InvincibilityTimer

# ───────────────────────────────
#  READY
# ───────────────────────────────
func _ready() -> void:
	health = max_health
	add_to_group("player")
	_set_attack_box(false)

	hurt_box.area_entered.connect(_on_hurt_box_area_entered)
	attack_box.body_entered.connect(_on_attack_hit)
	inv_timer.timeout.connect(_on_inv_timer_timeout)
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_sprite_animation_finished)

# ───────────────────────────────
#  PROCESS
# ───────────────────────────────
func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	match state:
		State.IDLE, State.MOVE:
			_handle_move(delta)
			_handle_attack_input()
			_handle_dash_input()
		State.DASH:
			_process_dash(delta)
		State.ATTACK:
			_handle_attack_input()
			velocity = Vector2.ZERO
			move_and_slide()
		State.HIT:
			velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
			move_and_slide()
		State.DEAD:
			pass

# ───────────────────────────────
#  MOVE
# ───────────────────────────────
func _handle_move(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		facing     = input_dir.normalized()
		velocity   = facing * move_speed
		state      = State.MOVE
		_sheathing = false   # 이동하면 sheathe 취소
		_play_anim("walk")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 12 * delta)
		if velocity.length() < 1.0:
			velocity = Vector2.ZERO
			state    = State.IDLE
			if not _sheathing:   # sheathe 재생 중엔 idle 애니로 덮지 않음
				_play_anim("idle")

	move_and_slide()

# ───────────────────────────────
#  DASH
# ───────────────────────────────
func _handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash") and _dash_cd_timer <= 0.0:
		_start_dash()

func _start_dash() -> void:
	if _attack_active:
		_cancel_attack()

	_sheathing     = false   # 대시하면 sheathe 취소
	state          = State.DASH
	_dash_dir      = facing
	_dash_timer    = dash_duration
	_dash_cd_timer = dash_cooldown
	is_invincible  = true
	dash_particles.emitting = true
	_play_anim("dash")

func _process_dash(delta: float) -> void:
	_dash_timer -= delta

	if _dash_timer > 0.0:
		velocity = _dash_dir * dash_speed
	else:
		velocity                = Vector2.ZERO
		is_invincible           = false
		dash_particles.emitting = false

	move_and_slide()

# ───────────────────────────────
#  ATTACK
# ───────────────────────────────
func _handle_attack_input() -> void:
	if not GameManager.current_run_active:
		return
	if Input.is_action_just_pressed("attack"):
		if not _attack_active:
			_start_attack()
		else:
			_combo_queued = true

func _start_attack() -> void:
	_combo_queued = false
	_sheathing    = false

	# 공격 방향을 마우스 위치 기준으로 갱신
	facing = _get_mouse_facing()

	if _combo_timer <= 0.0:
		_combo_index = 0
	else:
		_combo_index = (_combo_index + 1) % 4

	state          = State.ATTACK
	_attack_active = true

	attack_box.position = facing * 36.0
	_set_attack_box(false)

	_play_anim("attack_%d" % (_combo_index + 1))

	await sprite.animation_finished

	if state != State.ATTACK:
		_attack_active = false
		_combo_queued  = false
		_set_attack_box(false)
		return

	_end_attack()

func _end_attack() -> void:
	_attack_active = false
	_set_attack_box(false)

	if _combo_queued:
		_combo_timer = combo_window
		_start_attack()
	else:
		_combo_timer = combo_window
		state        = State.IDLE
		# 콤보 없이 끝 → 검 집어넣기
		_sheathing = true
		_play_anim("attack_sheathe")

func _cancel_attack() -> void:
	_attack_active = false
	_combo_queued  = false
	_combo_timer   = 0.0
	_sheathing     = false
	_set_attack_box(false)
	state = State.IDLE

# ───────────────────────────────
#  프레임별 히트박스
# ───────────────────────────────
func _on_frame_changed() -> void:
	if state != State.ATTACK:
		return

	if HIT_FRAMES.has(_combo_index):
		var active: bool = sprite.frame in HIT_FRAMES[_combo_index]
		_set_attack_box(active)
	else:
		_set_attack_box(false)

func _on_sprite_animation_finished() -> void:
	# 대시 애니 끝 → IDLE
	if state == State.DASH and sprite.animation.begins_with("dash"):
		state = State.IDLE
	# sheathe 애니 끝 → idle 재생
	if _sheathing and sprite.animation.begins_with("attack_sheathe"):
		_sheathing = false
		_play_anim("idle")

func _set_attack_box(active: bool) -> void:
	attack_box.monitoring      = active
	attack_shape.set_deferred("disabled", not active)

func _on_attack_hit(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(attack_damage, global_position)

# ───────────────────────────────
#  DAMAGE / DEATH
# ───────────────────────────────
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO) -> void:
	if is_invincible or state == State.DEAD:
		return

	if _attack_active:
		_cancel_attack()

	health = max(0, health - amount)
	health_changed.emit(health, max_health)

	if source_pos != Vector2.ZERO:
		velocity = (global_position - source_pos).normalized() * 320.0

	is_invincible = true
	state         = State.HIT
	inv_timer.start(0.6)
	_flash()

	if health <= 0:
		_die()
	else:
		await get_tree().create_timer(0.2).timeout
		if state == State.HIT:
			state = State.IDLE

func _die() -> void:
	state = State.DEAD
	player_died.emit()
	sprite.play("death")

# ───────────────────────────────
#  HIT BOX
# ───────────────────────────────
func _on_hurt_box_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_projectile"):
		take_damage(area.damage, area.global_position)

# ───────────────────────────────
#  HELPERS
# ───────────────────────────────
func _tick_timers(delta: float) -> void:
	if _dash_cd_timer > 0.0:
		_dash_cd_timer -= delta
	if _combo_timer > 0.0:
		_combo_timer -= delta

func _on_inv_timer_timeout() -> void:
	is_invincible     = false
	sprite.modulate.a = 1.0

func _flash() -> void:
	var tw := create_tween()
	for _i in range(5):
		tw.tween_property(sprite, "modulate:a", 0.15, 0.06)
		tw.tween_property(sprite, "modulate:a", 1.00, 0.06)

# ───────────────────────────────
#  마우스 방향 계산
#  플레이어 → 마우스 커서의 월드 좌표 방향 반환
# ───────────────────────────────
func _get_mouse_facing() -> Vector2:
	var mouse_world := get_global_mouse_position()
	var dir := mouse_world - global_position
	# 마우스가 플레이어 위에 정확히 겹치면 기존 facing 유지
	if dir.length() < 1.0:
		return facing
	return dir.normalized()

# ───────────────────────────────
#  방향 suffix 계산
#  facing 벡터 → "front" / "back" / "side" / "front_side" / "back_side"
#
#  x 성분이 작다 (|x| < 0.4) → 순수 상하
#  y 성분이 작다 (|y| < 0.4) → 순수 좌우
#  둘 다 크다 → 대각선
# ───────────────────────────────
func _get_dir_suffix() -> String:
	var ax := absf(facing.x)
	var ay := absf(facing.y)

	if ax < 0.4:
		return "front" if facing.y >= 0.0 else "back"
	if ay < 0.4:
		return "side"
	return "front_side" if facing.y >= 0.0 else "back_side"

# ───────────────────────────────
#  애니메이션 재생
#  DIRECTIONAL_ANIMS 에 있는 베이스 이름이면 방향 suffix 추가
#  없으면 (death, hit 등) 그대로 재생
# ───────────────────────────────
func _play_anim(base: String) -> void:
	var anim: String = base + "_" + _get_dir_suffix() if base in DIRECTIONAL_ANIMS else base

	if sprite.animation != anim:
		sprite.play(anim)

	# side / front_side / back_side 는 오른쪽 기준 → 왼쪽이면 flip
	sprite.flip_h = facing.x < 0.0
