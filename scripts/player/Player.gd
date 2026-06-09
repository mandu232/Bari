extends CharacterBody2D

# ───────────────────────────────
#  STATS
# ───────────────────────────────
@export_group("Movement")
@export var move_speed: float    = 110.0
@export var dash_speed: float    = 200.0
@export var dash_duration: float = 0.44
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
	"attack_1", "attack_2",
	"attack_sheathe",
	"hit",
	"sword_hack",
	"faint",
	"block_unsheathe", "block_idle", "block_sheathe",
	"charge_start_white", "charge_release_white",
	"sword_spin_white", "charge_end_white",
	"throw",
	"bow_pull", "bow_base", "bow_release",
]

# sword_hack 히트 판정 프레임 (애니메이션 확인 후 필요 시 조정)
const SWORD_HACK_HIT_FRAMES: Array[int] = [3, 4, 5]

# ───────────────────────────────
#  프레임 히트박스 설정
#  키 = 콤보 인덱스(0~3) — 방향 무관하게 동일 프레임 적용
# ───────────────────────────────
const HIT_FRAMES: Dictionary = {
	0: [0, 1, 2],       # attack_1
	1: [1, 2, 3],       # attack_2
}

# ───────────────────────────────
#  STATE
# ───────────────────────────────
enum State { IDLE, MOVE, DASH, ATTACK, HIT, DEAD, BLOCK, SPIN, SKILL }
var state: State        = State.IDLE
var facing: Vector2     = Vector2.DOWN
var is_invincible: bool = false
var health: int

var _dash_timer: float    = 0.0
var _dash_cd_timer: float = 0.0
var _dash_dir: Vector2    = Vector2.ZERO
# HIT 상태 감속도 — 막기 넉백은 낮춰서 물리감 있게 미끄러짐
var _hit_decel: float     = 800.0

var _combo_index: int    = 0
var _combo_timer: float  = 0.0
var _attack_active: bool = false
var _combo_queued: bool  = false
var _sheathing: bool     = false  # 검 집어넣기 재생 중
var _lunge_velocity: Vector2 = Vector2.ZERO  # 공격 시 전진 런지 속도

# ── 막기 (우클릭 — 프로젝트 입력 설정에서 "block" 액션을 MOUSE_BUTTON_RIGHT 에 매핑)
var _block_release_pending: bool = false  # unsheathe 도중 우클릭을 떼면 true
var _parry_in_progress:     bool = false  # 막기 피격 넉백 중 — block_sheathe 재생 완료까지 유지
var _parry_window_active:   bool    = false   # block_unsheathe 첫 4프레임 이내면 패링 판정
# ── 패링 후 추적 찍기 공격
var _parry_followup_window: float   = 0.0    # 남은 입력 허용 시간
var _parry_followup_target: Node2D  = null   # 패링한 적
var _in_hack_followup:      bool    = false  # sword_hack 실행 중
var _hack_hit_done:         bool    = false  # 한 번만 피해

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

# ── 부적 보너스 (set_talisman_bonus 로 일괄 교체됨)
var _talisman_atk: int   = 0
var _talisman_def: int   = 0
var _talisman_spd: float = 0.0
var _talisman_hp:  int   = 0

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
	add_to_group("player")
	_set_attack_box(false)

	hurt_box.area_entered.connect(_on_hurt_box_area_entered)
	attack_box.body_entered.connect(_on_attack_hit)
	inv_timer.timeout.connect(_on_inv_timer_timeout)
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_sprite_animation_finished)

	# 던전 입장 시 영구 스탯 적용 (스킬·시너지 보너스 적용 전 베이스 확정)
	if GameManager.current_run_active:
		max_health    = GameManager.player_max_health
		attack_damage += GameManager.player_damage_bonus
		move_speed    += GameManager.player_speed_bonus

	if GameManager.player_current_health > 0:
		health = GameManager.player_current_health
		GameManager.player_current_health = -1
	else:
		health = max_health

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

	# 박물관 시너지 보너스 던전에 재적용
	if GameManager.current_run_active:
		GameManager.reapply_synergies_to_player(self)

# ───────────────────────────────
#  PROCESS
# ───────────────────────────────
func _physics_process(delta: float) -> void:
	# 탑다운 뷰 Y-소팅 — CollisionShape2D(발) 기준 (y=+5 오프셋)
	z_as_relative = false
	z_index       = int(global_position.y + 5)
	_tick_timers(delta)

	# 패링 후 추적 찍기 공격 — 모든 상태에서 입력 감지 (DEAD·SKILL 제외)
	if _parry_followup_window > 0.0 \
			and state != State.DEAD and state != State.SKILL \
			and Input.is_action_just_pressed("attack") \
			and is_instance_valid(_parry_followup_target):
		var _tgt := _parry_followup_target
		_parry_followup_window = 0.0
		_parry_followup_target = null
		_start_hack_followup(_tgt)
		return

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
			_lunge_velocity = _lunge_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			velocity = _lunge_velocity
			move_and_slide()
		State.HIT:
			velocity = velocity.move_toward(Vector2.ZERO, _hit_decel * delta)
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
		State.SKILL:
			# velocity 는 스킬 코루틴이 직접 설정 — 여기선 apply 만
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
	_parry_window_active   = true   # 패링 판정 창 열기
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
		_combo_index = (_combo_index + 1) % 2

	state          = State.ATTACK
	_attack_active = true
	_lunge_velocity = facing * 130.0  # 공격 방향으로 전진 런지

	attack_box.position = facing * 20.0
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
	_attack_active  = false
	_combo_queued   = false
	_combo_timer    = 0.0
	_sheathing      = false
	_lunge_velocity = Vector2.ZERO
	_set_attack_box(false)
	state = State.IDLE

# ───────────────────────────────
#  프레임별 히트박스
# ───────────────────────────────
func _on_frame_changed() -> void:
	# block_unsheathe 4프레임 초과 시 패링 판정 창 종료
	if _parry_window_active and sprite.animation.begins_with("block_unsheathe"):
		if sprite.frame >= 4:
			_parry_window_active = false

	# sword_hack 히트 프레임 — 범위 내 적에게 데미지 + 카메라 임팩트
	if _in_hack_followup and sprite.animation.begins_with("sword_hack"):
		if sprite.frame in SWORD_HACK_HIT_FRAMES and not _hack_hit_done:
			_hack_hit_done = true
			# 카메라: 줌아웃 펀치 + 화면 흔들기
			var cam_node := get_tree().get_first_node_in_group("camera")
			if is_instance_valid(cam_node):
				if cam_node.has_method("zoom_punch"):
					cam_node.zoom_punch(-0.65, 0.25)
				if cam_node.has_method("screen_shake"):
					cam_node.screen_shake(6.0, 0.20)
			# 히트 스탑
			Engine.time_scale = 0.0
			await get_tree().create_timer(0.08, true, false, true).timeout
			Engine.time_scale = 1.0
			# 데미지
			for enemy in get_tree().get_nodes_in_group("enemies"):
				var e := enemy as Node2D
				if not is_instance_valid(e):
					continue
				if global_position.distance_to(e.global_position) <= 52.0:
					if e.has_method("take_damage"):
						e.take_damage(int(attack_damage * 1.8), global_position, 180.0)

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
		_parry_window_active = false   # 애니 끝나면 패링 창 확실히 닫기
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
	# 막기 sheathe 끝 → IDLE 복귀 (일반 해제 + 파리 피격 모두 처리)
	if state == State.BLOCK and sprite.animation.begins_with("block_sheathe"):
		state = State.IDLE
		_play_anim("idle")

func _set_attack_box(active: bool) -> void:
	attack_box.set_deferred("monitoring", active)
	attack_shape.set_deferred("disabled", not active)

func _on_attack_hit(body: Node2D) -> void:
	if body == self:
		return   # 자기 자신은 공격 불가
	if is_spinning:
		return   # 스핀 데미지는 SkillSwordSpin 의 폴링으로 처리
	if state == State.SKILL:
		return   # 스킬 데미지는 각 스킬 스크립트에서 직접 처리 (중복 피격 방지)
	if body.has_method("take_damage"):
		var ambush_mult := TalismanManager.consume_ambush_bonus(body)
		body.take_damage(int(attack_damage * ambush_mult), global_position)
		if ambush_mult > 1.0:
			var cam := get_tree().get_first_node_in_group("camera")
			if is_instance_valid(cam):
				if cam.has_method("zoom_punch"):
					cam.zoom_punch(-0.14, 0.22)
				if cam.has_method("screen_shake"):
					cam.screen_shake(8.0, 0.28)

# ───────────────────────────────
#  DAMAGE / DEATH
# ───────────────────────────────
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, source_node: Node = null) -> void:
	if is_invincible or state == State.DEAD:
		return

	# 부적 방어막 — 첫 피격 1회 무효
	if TalismanManager.consume_shield():
		_flash()   # 흡수 시각 피드백
		return

	# 막기 중 피격 — 공격이 facing 방향 앞에서 오면 막기 성공
	if state == State.BLOCK:
		var blocked := true
		if source_pos != Vector2.ZERO:
			var attack_dir := (source_pos - global_position).normalized()
			# facing 과 공격 방향의 내적이 0 이상이면 정면(90° 이내) → 막기 성공
			blocked = facing.dot(attack_dir) > 0.0
		if blocked:
			var mana_cost := TalismanManager.get_block_mana_cost()
			if mana >= float(mana_cost):
				spend_mana(mana_cost)
				_block_parried(source_pos, source_node)
				return
			# 마나 부족 → 막기 실패, 피해 계속
		# 방향이 맞지 않으면 막기 실패 → 일반 피해 처리 계속

	if _attack_active:
		_cancel_attack()
	is_spinning = false   # SkillSwordSpin 의 스핀 루프가 이 플래그로 종료를 감지

	TalismanManager.on_player_took_damage()   # 은영부 기습 충전 해제
	health = max(0, health - max(1, amount - defense))
	health_changed.emit(health, max_health)

	if source_pos != Vector2.ZERO:
		velocity = (global_position - source_pos).normalized() * 320.0
	_hit_decel    = 800.0   # 일반 피격은 빠른 감속 유지

	is_invincible = true
	state         = State.HIT
	inv_timer.start(0.6)

	# 공격 출처 방향 기준으로 방향성 hit 애니메이션 재생
	var prev_facing := facing
	if source_pos != Vector2.ZERO:
		facing = (source_pos - global_position).normalized()
	_play_anim("hit")
	facing = prev_facing

	# 화면 흔들기
	var cam := get_tree().get_first_node_in_group("camera")
	if is_instance_valid(cam) and cam.has_method("screen_shake"):
		cam.screen_shake(6.0, 0.22)

	# 히트 스탑 — time_scale=0 으로 순간 정지 (Tween 도 멈추므로 flash는 이후에 재생)
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.07, true, false, true).timeout
	Engine.time_scale = 1.0

	_flash()

	if health <= 0:
		_die()
	else:
		await get_tree().create_timer(0.2).timeout
		if state == State.HIT:
			state = State.IDLE

func _block_parried(source_pos: Vector2, source_node: Node = null) -> void:
	var is_parry          := _parry_window_active   # block_unsheathe 4프레임 이내 = 패링
	_parry_window_active   = false
	_block_release_pending = false
	_parry_in_progress     = true
	# 공격 반대 방향으로 넉백 — 살짝 밀리는 느낌으로 힘을 줄이고 감속도 낮춤
	if source_pos != Vector2.ZERO:
		velocity   = (global_position - source_pos).normalized() * 160.0
		_hit_decel = 260.0   # 낮은 감속 → 물리감 있게 서서히 정지
	# HIT 물리(넉백 감속)를 사용
	state         = State.HIT
	is_invincible = true
	inv_timer.start(0.5)
	# 막기 포즈 유지
	_play_anim("block_idle")

	# ── 패링 성공: 공격자 밀어내기 + 추적 찍기 공격 창 열기
	if is_parry and is_instance_valid(source_node) and source_node.has_method("take_parry_hit"):
		source_node.take_parry_hit(global_position)
		_parry_followup_window = 0.5
		_parry_followup_target = source_node as Node2D
		# 태산부: 패링 성공 시 마나 회복
		var mana_recovery := TalismanManager.get_parry_mana_recovery()
		if mana_recovery > 0:
			mana = minf(mana + float(mana_recovery), float(max_mana))
			mana_changed.emit(mana, max_mana)

	# ── 카메라 효과
	var cam := get_tree().get_first_node_in_group("camera")
	if is_instance_valid(cam):
		if cam.has_method("screen_shake"):
			cam.screen_shake(5.5 if is_parry else 3.0, 0.16 if is_parry else 0.12)
		if is_parry:
			# 패링: 줌아웃 → 줌인 → 복귀 (충격 후 포커스 연출)
			if cam.has_method("zoom_out_then_in"):
				cam.zoom_out_then_in(0.9, 0.55, 0.06, 0.18, 0.32)
		else:
			if cam.has_method("zoom_punch"):
				cam.zoom_punch(-0.07, 0.14)

	# ── 히트 스탑 — 패링은 조금 더 길게
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.09 if is_parry else 0.06, true, false, true).timeout
	Engine.time_scale = 1.0

	# 히트 스탑 해제 후 가벼운 플래시
	_block_flash()

	# 넉백이 가라앉을 때까지 대기 후 막기 해제
	await get_tree().create_timer(0.25).timeout
	if not _parry_in_progress or state == State.DEAD:
		return
	_parry_in_progress = false
	state = State.BLOCK   # block_sheathe → IDLE 전환은 _on_sprite_animation_finished 가 처리
	_play_anim("block_sheathe")

func heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)

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
	if _parry_followup_window > 0.0:
		_parry_followup_window -= delta
		if _parry_followup_window <= 0.0:
			_parry_followup_target = null
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

## 패링 후 추적 찍기 공격 — 멀리서 적 앞으로 대시 후 sword_hack 재생
func _start_hack_followup(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	# 진행 중인 행동 정리
	if _attack_active:  _cancel_attack()
	_parry_in_progress     = false
	_block_release_pending = false
	_sheathing             = false
	_in_hack_followup      = true
	_hack_hit_done         = false
	state                  = State.SKILL
	velocity               = Vector2.ZERO

	var dir := (target.global_position - global_position).normalized()
	facing        = dir
	sprite.flip_h = dir.x < 0.0

	# 최소 시작 거리 보장 — 가까우면 뒤로 물러나서 멀리서 날아오는 연출
	const MIN_DASH_DIST := 160.0
	if global_position.distance_to(target.global_position) < MIN_DASH_DIST:
		global_position = target.global_position - dir * MIN_DASH_DIST

	# ── 대시 트윈 (EXPO Out — 폭발적 가속 후 급감속)
	var dest := target.global_position - dir * 45.0
	var tw   := create_tween()
	tw.tween_property(self, "global_position", dest, 0.13) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tw.finished

	if state != State.SKILL:
		_in_hack_followup = false
		return

	# 최종 facing 보정 후 sword_hack 재생
	if is_instance_valid(target):
		facing        = (target.global_position - global_position).normalized()
		sprite.flip_h = facing.x < 0.0
	_play_anim("sword_hack")

	await sprite.animation_finished

	_in_hack_followup = false
	if state == State.SKILL:
		state = State.IDLE
		_play_anim("idle")

## 막기 성공 플래시 — 순간 새하얗게 밝아졌다가 서서히 복귀
func _block_flash() -> void:
	sprite.modulate = Color(2.8, 2.8, 2.8, 1.0)
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.14)

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

## 부적 보너스 일괄 교체 — TalismanManager._recalc 에서 호출
func set_talisman_bonus(atk: int, def_val: int, spd: float, hp: int) -> void:
	# 이전 부적 보너스 제거
	attack_damage = maxi(attack_damage - _talisman_atk, 1)
	defense       = maxi(defense       - _talisman_def, 0)
	move_speed    = maxf(move_speed    - _talisman_spd, 40.0)
	max_health    = maxi(max_health    - _talisman_hp,  1)
	health        = mini(health, max_health)
	# 새 부적 보너스 저장 + 적용
	_talisman_atk = atk
	_talisman_def = def_val
	_talisman_spd = spd
	_talisman_hp  = hp
	attack_damage  = maxi(attack_damage + _talisman_atk, 1)
	defense        = maxi(defense       + _talisman_def, 0)
	move_speed     = maxf(move_speed    + _talisman_spd, 40.0)
	max_health     = maxi(max_health    + _talisman_hp,  1)
	if _talisman_hp > 0:
		health = mini(health + _talisman_hp, max_health)
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

## 스킬 전용 상태 진입 — 이동/애니메이션 오버라이드 차단
func enter_skill() -> void:
	if _attack_active: _cancel_attack()
	_sheathing             = false
	_block_release_pending = false
	state                  = State.SKILL

## 스킬 전용 상태 종료 — IDLE 복귀
func exit_skill() -> void:
	velocity = Vector2.ZERO
	if state == State.SKILL:
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

# ───────────────────────────────
#  던전 입장 연출 (Dungeon.gd 에서 호출)
# ───────────────────────────────
func start_entry_walk() -> void:
	is_invincible = true
	facing = Vector2.UP
	_play_anim("walk")
	set_physics_process(false)
	set_process_unhandled_input(false)

func end_entry_walk() -> void:
	is_invincible = false
	velocity = Vector2.ZERO
	state = State.IDLE
	set_physics_process(true)
	set_process_unhandled_input(true)
	_play_anim("idle")
