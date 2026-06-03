extends Skill
class_name SkillDashAttack
## 대시 공격 스킬
## 마우스 방향으로 빠르게 돌진하며 경로 위의 적에게 피해를 입힙니다.

@export var dash_speed:    float = 400.0
@export var dash_duration: float = 0.22
@export var damage_mult:   float = 2.0   # 플레이어 공격력 배율

func _init() -> void:
	skill_name = "대시 공격"
	cooldown   = 4.0

func execute(player: CharacterBody2D) -> void:
	if not can_use():
		return
	_start_cooldown()
	_perform_dash(player)

func _perform_dash(player: CharacterBody2D) -> void:
	var dir: Vector2 = _get_mouse_dir(player)
	player.is_invincible = true

	# 대시 히트박스 — 플레이어 AttackBox 재사용
	var atk_box: Area2D = player.get_node_or_null("AttackBox")
	if atk_box:
		atk_box.position   = dir * 36.0
		atk_box.monitoring = true
		atk_box.get_node("CollisionShape2D").set_deferred("disabled", false)

	var elapsed := 0.0
	while elapsed < dash_duration:
		var delta: float = player.get_process_delta_time()
		player.velocity = dir * dash_speed
		player.move_and_slide()
		elapsed += delta
		await player.get_tree().process_frame

	player.velocity      = Vector2.ZERO
	player.is_invincible = false
	if atk_box:
		atk_box.monitoring = false
		atk_box.get_node("CollisionShape2D").set_deferred("disabled", true)

func _get_mouse_dir(player: CharacterBody2D) -> Vector2:
	var d := player.get_global_mouse_position() - player.global_position
	return d.normalized() if d.length() > 1.0 else player.get("facing") as Vector2
