extends CharacterBody2D

const SHAKE_SHADER := preload("res://AutoLoad/shaders/tree_shake.gdshader")

@export_group("흔들림")
@export var shake_duration  : float = 0.50
@export var shake_amplitude : float = 14.0
@export var shake_speed     : float = 26.0

@export_group("바람")
@export var wind_speed_min:    float = 0.9
@export var wind_speed_max:    float = 1.4
@export var wind_strength_min: float = 2.4
@export var wind_strength_max: float = 3.6

@export_group("투명도")
@export var alpha_fade:    float = 0.35
@export var fade_duration: float = 0.30

var _fade_tween:  Tween = null
var _shake_tween: Tween = null
var _shake_mats:  Array = []

func _ready() -> void:
	z_as_relative = false
	_update_z_sort()
	_setup_shaders()

	var area := get_node_or_null("Area2D") as Area2D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func _setup_shaders() -> void:
	_shake_mats.clear()

	# Body: 흔들림만 (바람 없음 — 몸통은 고정)
	var body := get_node_or_null("Body") as Sprite2D
	if is_instance_valid(body):
		var mat := ShaderMaterial.new()
		mat.shader = SHAKE_SHADER
		mat.set_shader_parameter("wind_strength", 0.0)
		mat.set_shader_parameter("hit_amplitude", shake_amplitude)
		mat.set_shader_parameter("hit_speed",     shake_speed)
		body.material = mat
		_shake_mats.append(mat)

	# Leaf_*: 바람 + 흔들림
	var leaves := find_children("Leaf_*", "Sprite2D", true, false)
	for leaf in leaves:
		var spr := leaf as Sprite2D
		var mat := ShaderMaterial.new()
		mat.shader = SHAKE_SHADER
		mat.set_shader_parameter("time_offset",   randf_range(0.0, 100.0))
		mat.set_shader_parameter("wind_speed",    randf_range(wind_speed_min, wind_speed_max))
		mat.set_shader_parameter("wind_strength", randf_range(wind_strength_min, wind_strength_max))
		mat.set_shader_parameter("hit_amplitude", shake_amplitude)
		mat.set_shader_parameter("hit_speed",     shake_speed)
		spr.material = mat
		_shake_mats.append(mat)

# ── 피격 ─────────────────────────────────────────────────────────────────────

func take_damage(_amount, _source_pos := Vector2.ZERO, _extra = null) -> void:
	_shake()
	var cam := get_tree().get_first_node_in_group("camera")
	if is_instance_valid(cam):
		if cam.has_method("screen_shake"):
			cam.screen_shake(2.5, 0.14)
		if cam.has_method("zoom_punch"):
			cam.zoom_punch(-0.05, 0.14)

func _shake() -> void:
	if is_instance_valid(_shake_tween):
		_shake_tween.kill()

	_set_hit_strength(1.0)
	_shake_tween = create_tween()
	_shake_tween.tween_method(_set_hit_strength, 1.0, 0.0, shake_duration)

func _set_hit_strength(v: float) -> void:
	for mat in _shake_mats:
		if is_instance_valid(mat):
			mat.set_shader_parameter("hit_strength", v)

# ── Y 정렬 ───────────────────────────────────────────────────────────────────

func _update_z_sort() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var foot_y := col.position.y if is_instance_valid(col) else 0.0
	z_index = int(global_position.y + foot_y)

# ── 투명도 ───────────────────────────────────────────────────────────────────

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
