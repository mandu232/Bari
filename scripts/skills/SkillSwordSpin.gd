extends Skill
class_name SkillSwordSpin
## 원형 공격 스킬
## Q 누름 → charge_start_white → charge_release_white → sword_spin_white (루프, Q 유지)
##         → Q 뗌 → charge_end_white → IDLE
##
## Player.enter_spin() / exit_spin() / play_anim() 공개 API 를 사용하므로
## Player 내부를 직접 수정하지 않습니다.

@export var damage_mult:     float  = 0.65   ## 기본 공격력 대비 스핀 데미지 배율
@export var damage_interval: float  = 0.22   ## 스핀 중 데미지 틱 간격 (초)
## 스핀 유지 판정에 사용할 입력 액션 — "skill" 로 설정하면
## 스킬 키를 누르고 있는 동안 스핀이 유지됩니다.
@export var spin_action: String = "skill"

func _init() -> void:
	skill_name = "원형 공격"
	cooldown   = 8.0

func execute(player: CharacterBody2D) -> void:
	if not can_use():
		return
	_start_cooldown()
	# fire-and-forget: await 없이 호출 → 코루틴으로 독립 실행
	_run_spin(player)

# ───────────────────────────────
#  스핀 메인 코루틴
# ───────────────────────────────
func _run_spin(player: CharacterBody2D) -> void:
	var sprite    := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var atk_box   := player.get_node("AttackBox")        as Area2D
	var atk_shape := atk_box.get_node("CollisionShape2D") as CollisionShape2D
	var orig_pos  := atk_box.position

	# 마우스 방향으로 facing 갱신 후 SPIN 상태 진입
	player.set("facing", _get_mouse_dir(player))
	player.call("enter_spin")

	# ── 1. charge_start_white (원샷, 방향 있음)
	player.call("play_anim", "charge_start_white")
	await sprite.animation_finished
	if not _still_spinning(player): return

	# ── 2. charge_release_white (원샷, 방향 있음)
	player.call("play_anim", "charge_release_white")
	await sprite.animation_finished
	if not _still_spinning(player): return

	# ── 3. sword_spin_white (루프, Q 유지 중)
	player.call("play_anim", "sword_spin_white")
	atk_box.position = Vector2.ZERO          # 히트박스를 플레이어 중심으로
	atk_box.monitoring = true
	atk_shape.set_deferred("disabled", false)

	var dmg_tick := damage_interval
	while _still_spinning(player) and Input.is_action_pressed(spin_action):
		var delta: float = player.get_physics_process_delta_time()
		dmg_tick -= delta
		if dmg_tick <= 0.0:
			dmg_tick = damage_interval
			_apply_damage(player, atk_box)
		await player.get_tree().physics_frame

	# ── 히트박스 원위치 복원
	atk_box.monitoring = false
	atk_shape.set_deferred("disabled", true)
	atk_box.position = orig_pos

	if not _still_spinning(player):
		# 피격 등으로 이미 종료된 경우 — exit_spin 은 플레이어가 알아서 처리
		player.call("exit_spin")   # 혹시 is_spinning 플래그가 남아 있을 때 보정
		return

	# ── 4. charge_end_white (원샷, 방향 있음)
	player.call("play_anim", "charge_end_white")
	await sprite.animation_finished

	# ── IDLE 복귀
	player.call("exit_spin")

# ───────────────────────────────
#  헬퍼
# ───────────────────────────────
## 플레이어가 여전히 스핀 상태인지 확인
func _still_spinning(player: CharacterBody2D) -> bool:
	return is_instance_valid(player) and player.get("is_spinning") as bool

## 스핀 범위 내 모든 적에게 데미지
func _apply_damage(player: CharacterBody2D, atk_box: Area2D) -> void:
	var dmg := maxi(1, int(player.get("attack_damage") * damage_mult))
	for body in atk_box.get_overlapping_bodies():
		if body == player: continue
		if body.has_method("take_damage"):
			body.take_damage(dmg, player.global_position)

## 마우스 방향 벡터 (플레이어 기준)
func _get_mouse_dir(player: CharacterBody2D) -> Vector2:
	var d := player.get_global_mouse_position() - player.global_position
	return d.normalized() if d.length() > 1.0 else player.get("facing") as Vector2
