extends Skill
class_name SkillDashAttack
## 주먹 돌진 스킬
## 마우스 방향으로 빠르게 돌진하며 강력한 주먹을 날립니다.
## 적중한 적을 크게 밀쳐냅니다.

@export var dash_speed:      float = 500.0   ## 돌진 속도 (px/s)
@export var dash_duration:   float = 0.1    ## 돌진 지속 시간 (초)
@export var damage_mult:     float = 1.2     ## 기본 공격력 대비 데미지 배율
@export var knockback_force: float = 120.0   ## 피격 적을 밀어내는 힘

func _init() -> void:
	skill_name  = "주먹 돌진"
	description = "앞으로 빠르게 돌진하며 강력한 주먹을 날립니다.\n적중한 모든 적을 크게 밀쳐냅니다.\n돌진 중에는 무적 상태가 됩니다."
	cooldown    = 5.0
	mana_cost   = 15

func execute(player: CharacterBody2D) -> void:
	if not can_use():
		return
	if mana_cost > 0 and player.has_method("spend_mana"):
		if not player.call("spend_mana", mana_cost):
			return   # 마나 부족
	_start_cooldown()
	_run_punch(player)

# ───────────────────────────────
#  돌진 주먹 코루틴
# ───────────────────────────────
func _run_punch(player: CharacterBody2D) -> void:
	var sprite  := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var atk_box := player.get_node_or_null("AttackBox") as Area2D
	var orig_pos := atk_box.position if atk_box else Vector2.ZERO
	var cam     := player.get_tree().get_first_node_in_group("camera")

	# 마우스 방향으로 facing 갱신
	var dir := _get_mouse_dir(player)
	player.set("facing", dir)

	# State.SKILL 진입 — 이후 _physics_process 는 애니/이동을 덮어쓰지 않음
	player.call("enter_skill")
	player.velocity = Vector2.ZERO   # 이전 이동 velocity 즉시 정지
	player.set("is_invincible", true)

	# 히트박스를 돌진 방향 앞쪽에 배치
	if atk_box:
		var shape := atk_box.get_node_or_null("CollisionShape2D") as CollisionShape2D
		atk_box.position = dir * 42.0
		atk_box.monitoring = true
		if shape:
			shape.set_deferred("disabled", false)

	# throw 애니메이션 재생 (DIRECTIONAL_ANIMS 등록으로 방향 suffix 자동 적용)
	player.call("play_anim", "throw")

	# ── 예비 동작: 애니메이션 4프레임 대기 + 예비 줌인 (집중감)
	if cam and cam.has_method("zoom_punch"):
		cam.zoom_punch(0.18, 0.22)
	for _i in range(4):
		await sprite.frame_changed

	# ── 돌진 시작: 줌아웃 + 화면 흔들기 (속도감·충격감)
	if cam:
		if cam.has_method("zoom_punch"):
			cam.zoom_punch(-0.22, 0.18)
		if cam.has_method("screen_shake"):
			cam.screen_shake(4.5, 0.20)

	# 첫 프레임 velocity 설정 (다음 _physics_process 에서 move_and_slide 적용)
	player.velocity = dir * dash_speed

	# ── 돌진 페이즈
	# _physics_process(State.SKILL) 가 move_and_slide() 를 대신 호출하므로
	# 코루틴에서는 velocity 설정 + 히트 판정만 수행
	var elapsed    := 0.0
	var hit_bodies := []
	while elapsed < dash_duration:
		await player.get_tree().physics_frame
		var delta: float = player.get_physics_process_delta_time()
		elapsed += delta

		# 다음 프레임에도 velocity 유지
		if elapsed < dash_duration:
			player.velocity = dir * dash_speed

		# 히트박스에 닿은 적 처리 (한 번씩만)
		if atk_box:
			for body in atk_box.get_overlapping_bodies():
				if body == player or body in hit_bodies:
					continue
				if body.has_method("take_damage"):
					var dmg := maxi(1, int(player.get("attack_damage") * damage_mult))
					body.take_damage(dmg, player.global_position)
					_apply_knockback(body, dir)
					hit_bodies.append(body)

	# ── 돌진 종료
	player.velocity = Vector2.ZERO
	player.set("is_invincible", false)

	if atk_box:
		var shape := atk_box.get_node_or_null("CollisionShape2D") as CollisionShape2D
		atk_box.monitoring = false
		if shape:
			shape.set_deferred("disabled", true)
		atk_box.position = orig_pos

	# 남은 throw 애니메이션 마저 대기 후 idle 복귀
	if is_instance_valid(sprite) and sprite.animation.begins_with("throw"):
		await sprite.animation_finished

	if is_instance_valid(player):
		player.call("exit_skill")

# ───────────────────────────────
#  헬퍼
# ───────────────────────────────
## 피격 적에게 방향 벡터로 밀어내기
func _apply_knockback(body: Node, dir: Vector2) -> void:
	if body.has_method("apply_knockback"):
		body.call("apply_knockback", dir * knockback_force)
	elif "velocity" in body:
		body.velocity += dir * knockback_force

## 마우스 방향 벡터 (플레이어 기준)
func _get_mouse_dir(player: CharacterBody2D) -> Vector2:
	var d := player.get_global_mouse_position() - player.global_position
	return d.normalized() if d.length() > 1.0 else player.get("facing") as Vector2
