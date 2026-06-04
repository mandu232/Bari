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
var defense:      int   = 0   # 방어력 — 피해 감소
var attack_speed: int   = 0   # 공격속도 보너스 (%)

@export_group("Mana")
@export var max_mana:   int   = 100   # 최대 마나
@export var mana_regen: float = 5.0   # 초당 마나 회복량
var mana: float = 100.0               # 현재 마나 (float으로 누적)

# ───────────────────────────────
#  방향 suffix 를 붙일 애니메이션 목록
#  여기 없는 이름(death, hit 등)은 suffix 없이 그대로 재생
# ───────────────────────────────
const DIRECTIONAL_ANIMS: Array[String] = [
	"idle", "walk", "dash",
	"attack_1", "attack_2", "attack_3", "attack_4",
	"attack_sheathe",
	"faint",
	"block_unsheathe", "block_idle", "block_sheathe",
	"charge_start_white", "charge_release_white",
	"sword_spin_white", "charge_end_white",
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
enum State { IDLE, MOVE, DASH, ATTACK, HIT, DEAD, BLOCK, SPIN }
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

# ── 막기 (우클릭 — 프로젝트 입력 설정에서 "block" 액션을 MOUSE_BUTTON_RIGHT 에 매핑)
var _block_release_pending: bool = false  # unsheathe 도중 우클릭을 떼면 true

## SkillSwordSpin 등 스킬이 스핀 루프 종료 여부를 감지하는 플래그
var is_spinning: bool = false
## sword_spin_white 루프 중일 때만 true — 이 구간에서만 이동 허용
var spin_can_move: bool = false

# ── 장착 스킬
var equipped_skill: Skill = null

# ── 시너지 보너스 (set_synergy_bonus 로 일괄 교체됨)
var _synergy_atk:     int   = 0
var _synergy_atk_spd: int   = 0
var _synergy_def:     int   = 0
var _synergy_spd:     float = 0.0
var _synergy_hp:      int   = 0

# ── 유물 장착 보너스 (apply_equip_bonus / remove_equip_bonus 로 관리)
var _equip_atk:     int   = 0
var _equip_atk_spd: int   = 0
var _equip_def:     int   = 0
var _equip_spd:     float = 0.0
var _equip_hp:      int   = 0

# ───────────────────────────────
#  SIGNALS
# ───────────────────────────────
signal health_changed(current: int, maximum: int)
signal mana_changed(current: float, maximum: int)
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

	# 저장된 스킬 + 장착 보너스 복원
	if GameManager.equipped_skill_path != "":
		var script := load(GameManager.equipped_skill_path) as GDScript
		if script:
			equip_skill(script.new() as Skill)
		for a in GameManager.artifacts:
			var art := a as ArtifactData
			if art != null and art.skill_script != null \
					and art.skill_script.resource_path == GameManager.equipped_skill_path:
				GameManager.equipped_artifact = art
				apply_equip_bonus(art)
				break

# ───────────────────────────────
#  PROCESS
# ───────────────────────────────
func _physics_process(delta: float) -> void:
	# 탑다운 뷰 Y-소팅 — y가 클수록 앞에 렌더링
	z_as_relative = false
	z_index       = int(global_position.y)
	_tick_timers(delta)

	match state:
		State.IDLE, State.MOVE:
			_handle_block_input()
			# 막기 시작으로 state 가 BLOCK 으로 바뀌었으면 이동·공격 입력 무시
			# (같은 프레임에 _handle_move() 가 실행되면 state=IDLE + play("idle") 로 덮어쓰기 때문)
			if state == State.BLOCK:
				velocity = Vector2.ZERO
				move_and_slide()
			else:
				_handle_move(delta)
				_handle_attack_input()
				_handle_dash_input()
				_handle_skill_input()
		State.DASH:
			_process_dash(delta)
		State.ATTACK:
			_handle_attack_input()
			_handle_skill_input()
			velocity = Vector2.ZERO
			move_and_slide()
		State.HIT:
			velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
			move_and_slide()
		State.DEAD:
			pass
		State.BLOCK:
			velocity = Vector2.ZERO
			move_and_slide()
			_handle_block_hold()
		State.SPIN:
			if spin_can_move:
				var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
				if input_dir != Vector2.ZERO:
					velocity = input_dir.normalized() * move_speed
				else:
					velocity = velocity.move_toward(Vector2.ZERO, move_speed * 12 * delta)
			else:
				velocity = Vector2.ZERO
			move_and_slide()

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
#  BLOCK — 막기 (우클릭)
#  흐름: block_unsheathe → block_idle (루프) → block_sheathe → IDLE
# ───────────────────────────────
func _handle_block_input() -> void:
	if Input.is_action_just_pressed("block"):
		_start_block()

## 막기 유지 중 매 프레임 — 우클릭을 떼는 타이밍 감지
func _handle_block_hold() -> void:
	if not Input.is_action_pressed("block"):
		var anim := sprite.animation
		if anim.begins_with("block_idle"):
			# block_idle 중 떼면 즉시 sheathe 전환
			_play_anim("block_sheathe")
		elif not anim.begins_with("block_sheathe"):
			# block_unsheathe 재생 중 — 끝난 뒤 sheathe 로 넘어가도록 예약
			# (이미 block_sheathe 중이면 중복 예약 방지)
			_block_release_pending = true

func _start_block() -> void:
	if _attack_active:
		_cancel_attack()
	# 공격과 동일하게 마우스 방향 기준으로 facing 갱신 후 애니메이션 재생
	facing                 = _get_mouse_facing()
	state                  = State.BLOCK
	_block_release_pending = false
	_sheathing             = false
	_play_anim("block_unsheathe")

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
	# 막기 block_unsheathe 끝 → idle 유지 or 즉시 sheathe (도중에 떼면)
	if state == State.BLOCK and sprite.animation.begins_with("block_unsheathe"):
		if _block_release_pending:
			_block_release_pending = false
			_play_anim("block_sheathe")
		else:
			_play_anim("block_idle")
	# 막기 idle 끝 — 비루프 애니 대응: 아직 holding 중이면 다시 재생
	if state == State.BLOCK and sprite.animation.begins_with("block_idle"):
		if Input.is_action_pressed("block"):
			_play_anim("block_idle")  # 루프 애니면 이미 자동 반복되므로 무해
		else:
			_play_anim("block_sheathe")
	# 막기 sheathe 끝 → IDLE 복귀
	if state == State.BLOCK and sprite.animation.begins_with("block_sheathe"):
		state = State.IDLE
		_play_anim("idle")

func _set_attack_box(active: bool) -> void:
	attack_box.monitoring      = active
	attack_shape.set_deferred("disabled", not active)

func _on_attack_hit(body: Node2D) -> void:
	if is_spinning:
		return   # 스핀 데미지는 SkillSwordSpin 의 폴링으로 처리
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
	is_spinning = false   # SkillSwordSpin 의 스핀 루프가 이 플래그로 종료를 감지

	health = max(0, health - max(1, amount - defense))
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
	_play_anim("faint")

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
	if mana < float(max_mana):
		var prev := mana
		mana = minf(mana + mana_regen * delta, float(max_mana))
		if int(mana) != int(prev):
			mana_changed.emit(mana, max_mana)

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
func apply_artifact_bonus(data: ArtifactData) -> void:
	attack_damage += data.total_attack()
	attack_speed  += data.total_attack_speed()
	defense       += data.total_defense()
	move_speed    += data.total_move_speed()
	max_health    += data.total_max_health()
	health         = min(health + data.total_max_health(), max_health)
	if data.total_max_health() != 0:
		health_changed.emit(health, max_health)

func remove_artifact_bonus(data: ArtifactData) -> void:
	attack_damage  = maxi(attack_damage - data.total_attack(),       1)
	attack_speed   = maxi(attack_speed  - data.total_attack_speed(), 0)
	defense        = maxi(defense       - data.total_defense(),      0)
	move_speed     = maxf(move_speed    - data.total_move_speed(),   40.0)
	max_health     = maxi(max_health    - data.total_max_health(),   1)
	health         = mini(health, max_health)
	if data.total_max_health() != 0:
		health_changed.emit(health, max_health)

## 마나 소모 — 성공하면 true, 부족하면 false
func spend_mana(amount: int) -> bool:
	if mana < float(amount):
		return false
	mana -= float(amount)
	mana_changed.emit(mana, max_mana)
	return true

## 지속 마나 소모 — 소모 후 마나가 남아 있으면 true, 0이 되면 false
func drain_mana(amount: float) -> bool:
	mana = maxf(mana - amount, 0.0)
	mana_changed.emit(mana, max_mana)
	return mana > 0.0

## 유물 장착 보너스 적용 — 기존 장착 보너스를 교체한 뒤 새 값 적용
func apply_equip_bonus(data: ArtifactData) -> void:
	# 이전 장착 보너스 제거
	attack_damage  = maxi(attack_damage - _equip_atk,     1)
	attack_speed   = maxi(attack_speed  - _equip_atk_spd, 0)
	defense        = maxi(defense       - _equip_def,      0)
	move_speed     = maxf(move_speed    - _equip_spd,      40.0)
	max_health     = maxi(max_health    - _equip_hp,       1)
	health         = mini(health, max_health)
	# 새 장착 보너스 저장 + 적용 (강화 레벨 포함)
	_equip_atk     = data.total_equip_atk()
	_equip_atk_spd = data.total_equip_atk_spd()
	_equip_def     = data.total_equip_def()
	_equip_spd     = data.total_equip_move_spd()
	_equip_hp      = data.total_equip_hp()
	attack_damage  += _equip_atk
	attack_speed   += _equip_atk_spd
	defense        += _equip_def
	move_speed     += _equip_spd
	max_health     += _equip_hp
	if _equip_hp > 0:
		health = min(health + _equip_hp, max_health)
	health_changed.emit(health, max_health)

## 유물 장착 보너스 제거
func remove_equip_bonus() -> void:
	attack_damage  = maxi(attack_damage - _equip_atk,     1)
	attack_speed   = maxi(attack_speed  - _equip_atk_spd, 0)
	defense        = maxi(defense       - _equip_def,      0)
	move_speed     = maxf(move_speed    - _equip_spd,      40.0)
	max_health     = maxi(max_health    - _equip_hp,       1)
	health         = mini(health, max_health)
	_equip_atk     = 0
	_equip_atk_spd = 0
	_equip_def     = 0
	_equip_spd     = 0.0
	_equip_hp      = 0
	health_changed.emit(health, max_health)

## 시너지 보너스 일괄 교체 — GameManager.update_synergies() 에서 호출
func set_synergy_bonus(atk: int, atk_spd: int, def_val: int, spd: float, hp: int) -> void:
	# 이전 시너지 제거
	attack_damage  = maxi(attack_damage - _synergy_atk,     1)
	attack_speed   = maxi(attack_speed  - _synergy_atk_spd, 0)
	defense        = maxi(defense       - _synergy_def,      0)
	move_speed     = maxf(move_speed    - _synergy_spd,      40.0)
	max_health     = maxi(max_health    - _synergy_hp,       1)
	health         = mini(health, max_health)
	# 새 시너지 저장 + 적용
	_synergy_atk     = atk
	_synergy_atk_spd = atk_spd
	_synergy_def     = def_val
	_synergy_spd     = spd
	_synergy_hp      = hp
	attack_damage  += _synergy_atk
	attack_speed   += _synergy_atk_spd
	defense        += _synergy_def
	move_speed     += _synergy_spd
	max_health     += _synergy_hp
	if _synergy_hp > 0:
		health = min(health + _synergy_hp, max_health)
	health_changed.emit(health, max_health)

# ───────────────────────────────
#  스킬용 공개 API  (SkillSwordSpin 등이 호출)
# ───────────────────────────────
## SPIN 상태 진입 — 다른 행동 캔슬 + 이동 차단
func enter_spin() -> void:
	if _attack_active: _cancel_attack()
	_sheathing             = false
	_block_release_pending = false
	is_spinning            = true
	state                  = State.SPIN

## SPIN 상태 종료 — IDLE 복귀
func exit_spin() -> void:
	is_spinning    = false
	spin_can_move  = false
	if state == State.SPIN:
		state = State.IDLE
		_play_anim("idle")

## 방향 포함 애니메이션 재생 공개 래퍼 (스킬에서 호출)
func play_anim(base: String) -> void:
	_play_anim(base)

# ───────────────────────────────
#  스킬
# ───────────────────────────────
func _handle_skill_input() -> void:
	if equipped_skill == null:
		return
	if Input.is_action_just_pressed("skill"):
		equipped_skill.execute(self)

## 스킬 장착 — 기존 스킬은 제거 후 새 스킬을 자식 노드로 추가
func equip_skill(skill: Skill) -> void:
	if equipped_skill != null:
		equipped_skill.queue_free()
	equipped_skill = skill
	if skill != null:
		add_child(skill)

## 스킬 해제
func unequip_skill() -> void:
	if equipped_skill != null:
		equipped_skill.queue_free()
		equipped_skill = null

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
