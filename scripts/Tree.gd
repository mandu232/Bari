extends CharacterBody2D

const WIND_SHADER := preload("res://AutoLoad/shaders/wind_leaf.gdshader")

# ── 에디터에서 나무마다 조절 가능한 바람 파라미터 ─────────────
@export_group("바람")
@export var wind_speed_min:    float = 0.9
@export var wind_speed_max:    float = 1.4
@export var wind_strength_min: float = 2.4
@export var wind_strength_max: float = 3.6

# ── 플레이어 감지 투명도 ───────────────────────────────────────
@export_group("투명도")
@export var alpha_fade:     float = 0.35
@export var fade_duration:  float = 0.30

var _fade_tween: Tween = null

func _ready() -> void:
	# ── 탑다운 Y 정렬
	z_as_relative = false
	z_index = int(global_position.y)

	# ── 바람 셰이더: Leaf_* 이름의 Sprite2D 를 재귀 탐색
	var leaves := find_children("Leaf_*", "Sprite2D", true, false)
	for leaf in leaves:
		var spr := leaf as Sprite2D
		var mat := ShaderMaterial.new()
		mat.shader = WIND_SHADER
		mat.set_shader_parameter("time_offset",   randf_range(0.0, 100.0))
		mat.set_shader_parameter("wind_speed",    randf_range(wind_speed_min,    wind_speed_max))
		mat.set_shader_parameter("wind_strength", randf_range(wind_strength_min, wind_strength_max))
		spr.material = mat

	# ── Area2D 시그널 연결 (없으면 스킵)
	var area := get_node_or_null("Area2D") as Area2D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_fade_to(alpha_fade)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_fade_to(1.0)

func _fade_to(target: float) -> void:
	if is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_fade_tween.tween_property(self, "modulate:a", target, fade_duration)
