extends Skill
class_name SkillProjectile
## 원거리 투사체 스킬
## 마우스 방향으로 투사체를 발사합니다.
## 투사체 씬이 없으면 즉시 히트 처리(라인캐스트)로 대체합니다.

@export var projectile_scene: PackedScene = null  # 투사체 씬 (없으면 즉시 히트)
@export var projectile_speed: float       = 500.0
@export var damage_mult:      float       = 1.5
@export var max_range:        float       = 600.0  # 즉시 히트 최대 사거리

func _init() -> void:
	skill_name = "투사체"
	cooldown   = 3.0

func execute(player: CharacterBody2D) -> void:
	if not can_use():
		return
	_start_cooldown()

	if projectile_scene != null:
		_fire_projectile(player)
	else:
		_instant_hit(player)

func _fire_projectile(player: CharacterBody2D) -> void:
	var dir  := _get_mouse_dir(player)
	var proj := projectile_scene.instantiate() as Node2D
	proj.global_position = player.global_position

	# 투사체에 speed, direction, damage 가 있으면 주입
	if proj.has_method("set_direction"):
		proj.call("set_direction", dir)
	if "speed" in proj:
		proj.set("speed", projectile_speed)
	if "damage" in proj:
		proj.set("damage", int(player.get("attack_damage") * damage_mult))

	player.get_parent().add_child(proj)

func _instant_hit(player: CharacterBody2D) -> void:
	var dir    := _get_mouse_dir(player)
	var origin := player.global_position
	var space  := player.get_world_2d().direct_space_state
	var query  := PhysicsRayQueryParameters2D.create(
		origin, origin + dir * max_range, 0b10)   # 레이어 2 = 적

	var result := space.intersect_ray(query)
	if result and result["collider"].has_method("take_damage"):
		result["collider"].take_damage(
			int(player.get("attack_damage") * damage_mult),
			player.global_position)

func _get_mouse_dir(player: CharacterBody2D) -> Vector2:
	var d := player.get_global_mouse_position() - player.global_position
	return d.normalized() if d.length() > 1.0 else player.get("facing") as Vector2
