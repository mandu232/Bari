extends CharacterBody2D

# ─────────────────────────────
#  STATS
# ─────────────────────────────
@export var max_health:      int   = 10
@export var attack_damage:   int   = 2
@export var move_speed:      float = 35.0
@export var attack_cooldown: float = 1.0
@export var patrol_radius:   float = 80.0
# 피격 어그로 시 유지되는 최대 추적 거리 (DetectionArea 반지름보다 크게 설정)
@export var alert_range:     float = 320.0

# attack 애니메이션(14프레임, 0~13)에서 데미지를 주는 프레임
const ATTACK_HIT_FRAMES: Array[int] = [4, 8]
# 히트 판정 거리 (픽셀)
const ATTACK_REACH: float = 40.0

# ─────────────────────────────
#  STATE
# ─────────────────────────────
enum State { PATROL, CHASE, ATTACK, HIT, DEAD }
var state: State = State.PATROL

signal died   # 사망 애니 시작 시 발생 — Dungeon에서 전멸 감지에 사용

var health: int
var spawn_position: Vector2
var target: Node2D = null

var _attack_cooldown_timer: float = 0.0
# 현재 HIT 감속도 — 강공격은 낮춰서 멀리 미끄러지는 물리감 부여
var _hit_decel: float = 600.0

var _pending_death: bool = false   # hit 애니+넉백 후 사망 대기 플래그

# ── 경직 저항 (포이즈)
const POISE_THRESHOLD: int   = 3     # 이 횟수 연속 피격 시 저항 발동
const POISE_DURATION:  float = 2.0   # 저항 지속 시간
const POISE_WINDOW:    float = 1.2   # 연속 피격 판정 시간 창

var _poise_count:  int   = 0   # 시간 창 내 피격 횟수
var _poise_window: float = 0.0 # 마지막 피격 후 경과 타이머
var _poise_timer:  float = 0.0 # > 0 이면 경직 저항 중

# 순찰
var _patrol_timer:      float   = 0.0
var _patrol_idle_timer: float   = 0.0
var _patrol_target:     Vector2
var _patrol_idling:     bool    = false

# 공격
var _is_attacking:    bool = false
var _attack_hit_done: bool = false  # 한 번의 스윙에서 한 번만 피해

# 감지 상태 추적
var _player_in_detection:    bool = false
var _player_in_attack_range: bool = false
# 피격 어그로 — true 이면 DetectionArea 밖에서도 alert_range까지 추적 유지
var _is_alerted:             bool = false

# ─────────────────────────────
#  NODES
# ─────────────────────────────
@onready var sprite:         AnimatedSprite2D = $AnimatedSprite2D
@onready var nav_agent:      NavigationAgent2D = $NavigationAgent2D
@onready var attack_area:    Area2D = $AttackArea
@onready var detection_area: Area2D = $DetectionArea

# ─────────────────────────────
#  READY
# ─────────────────────────────
func _ready() -> void:
	health         = max_health
	spawn_position = global_position
	add_to_group("enemies")

	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	attack_area.body_entered.connect(_on_attack_area_entered)
	attack_area.body_exited.connect(_on_attack_area_exited)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)

	_pick_patrol_target()

# ─────────────────────────────
#  PHYSICS PROCESS
# ─────────────────────────────
func _physics_process(delta: float) -> void:
	z_as_relative = false
	z_index       = int(global_position.y)

	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	if _poise_window > 0.0:
		_poise_window -= delta
		if _poise_window <= 0.0:
			_poise_count = 0
	if _poise_timer > 0.0:
		_poise_timer -= delta

	match state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase()
			if _player_in_attack_range and _attack_cooldown_timer <= 0.0:
				_try_attack()
		State.ATTACK:
			velocity = Vector2.ZERO
			move_and_slide()
		State.HIT:
			velocity = velocity.move_toward(Vector2.ZERO, _hit_decel * delta)
			move_and_slide()
		State.DEAD:
			pass

# ─────────────────────────────
#  PATROL — 스폰 위치 근처를 배회
# ─────────────────────────────
func _process_patrol(delta: float) -> void:
	# 목적지 도착 후 idle 대기 중
	if _patrol_idling:
		_patrol_idle_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 10.0 * delta)
		move_and_slide()
		if _patrol_idle_timer <= 0.0:
			_patrol_idling = false
			_pick_patrol_target()
		return

	_patrol_timer -= delta

	if global_position.distance_to(_patrol_target) < 12.0:
		_start_patrol_idle()
		return

	if _patrol_timer <= 0.0:
		_pick_patrol_target()
		return

	_move_toward(_patrol_target, move_speed * 0.6)

func _pick_patrol_target() -> void:
	var angle := randf() * TAU
	var dist  := randf_range(20.0, patrol_radius)
	_patrol_target = spawn_position + Vector2(cos(angle), sin(angle)) * dist
	_patrol_timer  = randf_range(4.0, 8.0)
	if sprite.animation != "walk":
		sprite.play("walk")

func _start_patrol_idle() -> void:
	_patrol_idling     = true
	_patrol_idle_timer = randf_range(1.0, 2.5)
	velocity           = Vector2.ZERO
	sprite.play("idle")

# ─────────────────────────────
#  CHASE — 플레이어 추적
# ─────────────────────────────
func _process_chase() -> void:
	if target == null or not is_instance_valid(target):
		_enter_patrol()
		return

	# 어그로 상태: alert_range를 넘으면 어그로 해제
	if _is_alerted and not _player_in_detection:
		if global_position.distance_to(target.global_position) > alert_range:
			_is_alerted = false
			_enter_patrol()
			return

	_move_toward(target.global_position, move_speed)

# ─────────────────────────────
#  MOVEMENT HELPER
# ─────────────────────────────
func _move_toward(pos: Vector2, speed: float) -> void:
	if global_position.distance_to(pos) < 5.0:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 10.0 * get_physics_process_delta_time())
		move_and_slide()
		return

	nav_agent.target_position = pos
	var next_pos := nav_agent.get_next_path_position()

	# NavMesh가 없으면 get_next_path_position()이 현재 위치를 반환 → 직접 이동으로 폴백
	var dir: Vector2
	if next_pos.distance_to(global_position) > 1.0:
		dir = (next_pos - global_position).normalized()
	else:
		dir = (pos - global_position).normalized()

	velocity = dir * speed
	_face_direction(dir)

	if sprite.animation != "walk":
		sprite.play("walk")

	move_and_slide()

# ─────────────────────────────
#  ATTACK — 공격 시도 및 히트 판정
# ─────────────────────────────
func _try_attack() -> void:
	if _is_attacking or _attack_cooldown_timer > 0.0:
		return
	if target == null or not is_instance_valid(target):
		return

	state            = State.ATTACK
	_is_attacking    = true
	_attack_hit_done = false
	velocity         = Vector2.ZERO

	var dir := (target.global_position - global_position).normalized()
	_face_direction(dir)
	sprite.play("attack")

func _on_frame_changed() -> void:
	if state != State.ATTACK or _attack_hit_done:
		return
	if sprite.frame in ATTACK_HIT_FRAMES:
		_deal_damage()

func _deal_damage() -> void:
	if target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) <= ATTACK_REACH:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage, global_position, self)  # 패링 판정을 위해 self 전달
		_attack_hit_done = true  # 한 번의 스윙에서 중복 피해 방지

# ─────────────────────────────
#  ANIMATION FINISHED
# ─────────────────────────────
func _on_animation_finished() -> void:
	match sprite.animation:
		"attack":
			_is_attacking          = false
			_attack_cooldown_timer = attack_cooldown
			if (_player_in_detection or _is_alerted) and target != null and is_instance_valid(target):
				_enter_chase()
			else:
				_enter_patrol()
		"hit":
			if _pending_death:
				_die()
				return
			if state == State.HIT:
				if (_player_in_detection or _is_alerted) and target != null and is_instance_valid(target):
					_enter_chase()
				else:
					_enter_patrol()

# ─────────────────────────────
#  AREA SIGNALS
# ─────────────────────────────
func _on_detection_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target               = body
		_player_in_detection = true
		if state != State.DEAD and not _is_attacking:
			_enter_chase()

func _on_detection_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_detection    = false
		_player_in_attack_range = false
		# 어그로 상태면 DetectionArea 밖으로 나가도 추적 유지
		if state == State.CHASE and not _is_alerted:
			target = null
			_enter_patrol()

func _on_attack_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_attack_range = true

func _on_attack_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_attack_range = false

# ─────────────────────────────
#  STATE TRANSITIONS
# ─────────────────────────────
func _enter_chase() -> void:
	state          = State.CHASE
	_patrol_idling = false
	if sprite.animation != "walk":
		sprite.play("walk")

func _enter_patrol() -> void:
	target                  = null
	_player_in_detection    = false
	_player_in_attack_range = false
	_is_alerted             = false
	state                   = State.PATROL
	_pick_patrol_target()

# ─────────────────────────────
#  FACING — X축 반전만 사용
# ─────────────────────────────
func _face_direction(dir: Vector2) -> void:
	if absf(dir.x) > 0.1:
		sprite.flip_h = dir.x < 0.0

# ─────────────────────────────
#  DAMAGE / DEATH
# ─────────────────────────────
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback_force: float = 200.0) -> void:
	if state == State.DEAD:
		return

	health = max(0, health - amount)

	# 카메라 타격감 (항상 적용)
	var cam := get_tree().get_first_node_in_group("camera")
	if is_instance_valid(cam):
		if cam.has_method("screen_shake"):
			cam.screen_shake(4.0, 0.18)
		if cam.has_method("zoom_punch"):
			cam.zoom_punch(-0.06, 0.15)

	if health <= 0:
		_pending_death = true
	else:
		# 피격 어그로 — 감지 범위 밖에서 맞아도 플레이어를 추적
		_is_alerted = true
		if target == null or not is_instance_valid(target):
			target = get_tree().get_first_node_in_group("player") as Node2D
		if state == State.PATROL or state == State.HIT:
			if target != null and is_instance_valid(target):
				_enter_chase()

	if _is_attacking:
		_is_attacking          = false
		_attack_cooldown_timer = attack_cooldown

	# 경직 저항 — 죽음 대기 중이면 무시하고 경직 처리
	if not _pending_death and _check_poise_resist():
		_hit_flash()
		return

	# 넉백 + 경직
	if source_pos != Vector2.ZERO:
		velocity   = (global_position - source_pos).normalized() * knockback_force
		_hit_decel = 280.0 if knockback_force >= 300.0 else 600.0

	state = State.HIT
	sprite.play("hit")
	_hit_flash()

## 플레이어 패링에 의한 피격 — 공격 중단 + 강한 넉백 (hit 애니 없음)
func take_parry_hit(parry_pos: Vector2) -> void:
	if state == State.DEAD:
		return
	# 진행 중인 공격 강제 중단
	_is_attacking          = false
	_attack_hit_done       = true
	_attack_cooldown_timer = attack_cooldown * 1.5
	# 강한 넉백 — idle 포즈로 밀려남
	velocity   = (global_position - parry_pos).normalized() * 130.0
	_hit_decel = 320.0   # 패링: 튕겨나가되 자연스럽게 감속
	state      = State.HIT
	sprite.play("idle")     # hit 애니 없이 idle 유지하며 밀려남
	_hit_flash()            # 모듈레이트 플래시만 (애니메이션 변경 없음)
	# 넉백이 가라앉으면 상태 복귀 (HIT → animation_finished 미사용이므로 타이머로 처리)
	await get_tree().create_timer(0.4).timeout
	if state == State.HIT:
		if _pending_death:
			_die()
			return
		if (_player_in_detection or _is_alerted) and target != null and is_instance_valid(target):
			_enter_chase()
		else:
			_enter_patrol()

func _die() -> void:
	state    = State.DEAD
	velocity = Vector2.ZERO
	sprite.play("dead")
	$CollisionShape2D.set_deferred("disabled", true)
	died.emit()   # 전멸 감지용 시그널
	TalismanManager.on_enemy_died(global_position)  # 부적 특수 효과 트리거
	await get_tree().create_timer(1.5).timeout
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

# 포이즈 카운터 갱신 — 저항 중이면 true 반환
func _check_poise_resist() -> bool:
	if _poise_timer > 0.0:
		return true
	_poise_count  += 1
	_poise_window  = POISE_WINDOW
	if _poise_count >= POISE_THRESHOLD:
		_poise_timer = POISE_DURATION
		_poise_count = 0
		return true
	return false

func _hit_flash() -> void:
	sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)
