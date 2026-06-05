extends Skill
class_name SkillBowShot
## 활 스킬 — 삼연시
## Q 꾹 누름  → bow_pull (활 당기기)
## 차징 완료 → bow_base (풀 차징 유지, Q 유지)
## Q 뗌       → 화살 발사 + 반동 + bow_release (팔로우스루)
##
## Player 공개 API(enter_skill / exit_skill / play_anim)만 사용합니다.

const ARROW_SCENE := preload("res://AutoLoad/scenes/skills/BowArrow.tscn")

@export var arrow_speed:  float = 650.0   ## 화살 비행 속도 (px/s)
@export var damage_mult:  float = 1.2     ## 기본 공격력 대비 데미지 배율
@export var spread_angle: float = 15.0    ## 화살 간 벌어짐 각도 (도)
@export var arrow_count:  int   = 3       ## 발사 화살 수
@export var pierce_count: int   = 2       ## 화살당 관통 횟수
@export var recoil_force: float = 180.0   ## 발사 반동 세기 (px/s)

func _init() -> void:
	skill_name  = "삼연시"
	description = "Q 를 꾹 눌러 활을 당기고 놓으면 화살 3발을 발사합니다.\n" \
				+ "각 화살은 적을 관통합니다."
	cooldown    = 1.5
	mana_cost   = 25

func execute(player: CharacterBody2D) -> void:
	if not can_use():
		return
	if mana_cost > 0 and player.has_method("spend_mana"):
		if not player.call("spend_mana", mana_cost):
			return   # 마나 부족
	_start_cooldown()
	_run_bow(player)

# ───────────────────────────────
#  메인 코루틴
# ───────────────────────────────
func _run_bow(player: CharacterBody2D) -> void:
	var sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var cam    := player.get_tree().get_first_node_in_group("camera")

	var dir := _get_mouse_dir(player)
	player.set("facing", dir)
	player.call("enter_skill")
	player.velocity = Vector2.ZERO

	# ── 1. bow_pull — 활 당기기 (끝까지 재생)
	if cam and cam.has_method("zoom_punch"):
		cam.zoom_punch(0.12, 0.30)
	player.call("play_anim", "bow_pull")
	await sprite.animation_finished

	if not is_instance_valid(player):
		return

	# 차징 완료 전에 Q 를 뗐으면 취소 (탭 방지)
	if not Input.is_action_pressed("skill"):
		player.call("exit_skill")
		return

	# ── 2. bow_base — 풀 차징 유지 (Q 누른 채로)
	player.call("play_anim", "bow_base")
	while Input.is_action_pressed("skill") and is_instance_valid(player):
		# bow_base 가 비루프 애니메이션일 때 마지막 프레임 유지
		if sprite.animation.begins_with("bow_base") and not sprite.is_playing():
			sprite.play(sprite.animation)
		await player.get_tree().physics_frame

	if not is_instance_valid(player):
		return

	# ── 3. 화살 발사
	var dmg        := maxi(1, int(player.get("attack_damage") * damage_mult))
	var base_angle := dir.angle()
	var half       := (arrow_count - 1) * 0.5

	for i in arrow_count:
		var a    := base_angle + deg_to_rad(spread_angle * (i - half))
		var adir := Vector2(cos(a), sin(a))
		_spawn_arrow(player, adir, dmg)

	# 발사 반동 — 발사 방향 반대로 밀리며 0.25초간 감속
	player.velocity = -dir * recoil_force
	var tw := player.create_tween()
	tw.tween_property(player, "velocity", Vector2.ZERO, 0.25)

	if cam:
		if cam.has_method("zoom_punch"):
			cam.zoom_punch(-0.12, 0.18)
		if cam.has_method("screen_shake"):
			cam.screen_shake(2.5, 0.14)

	# ── 4. bow_release — 발사 팔로우스루
	player.call("play_anim", "bow_release")
	if is_instance_valid(sprite) and sprite.animation.begins_with("bow_release"):
		await sprite.animation_finished

	if is_instance_valid(player):
		player.call("exit_skill")

# ───────────────────────────────
#  헬퍼
# ───────────────────────────────
func _spawn_arrow(player: CharacterBody2D, dir: Vector2, dmg: int) -> void:
	var arrow          := ARROW_SCENE.instantiate() as BowArrow
	arrow.direction    = dir
	arrow.speed        = arrow_speed
	arrow.damage       = dmg
	arrow.pierce_count = pierce_count
	player.get_parent().add_child(arrow)
	arrow.global_position = player.global_position + dir * 24.0

func _get_mouse_dir(player: CharacterBody2D) -> Vector2:
	var d := player.get_global_mouse_position() - player.global_position
	return d.normalized() if d.length() > 1.0 else player.get("facing") as Vector2
