extends Node2D

const GRASS_SHADER := preload("res://AutoLoad/shaders/grass_wind.gdshader")

# ── 바람
const WIND_STRENGTH  := 1.5
const WIND_SPEED     := 1.6
const SUBDIVISIONS   := 4

# ── 굽힘
const BEND_AMOUNT   := 10.0
const BEND_DURATION := 0.10
const RISE_DURATION := 0.50

var _mat:   ShaderMaterial = null
var _mesh:  MeshInstance2D = null
var _tween: Tween          = null

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _area:   Area2D   = $Area2D

func _ready() -> void:
	var result := _setup_mesh(_sprite)
	_mat  = result[0]
	_mesh = result[1]

	# 항상 캐릭터 뒤에 렌더링
	z_as_relative = false
	z_index = -3000

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

# ── Area2D 감지 ────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") and not body.is_in_group("enemies"):
		return
	# 진입 방향에 따라 굽히는 방향 결정
	var dir := signf((body as Node2D).global_position.x - global_position.x)
	_bend_to(BEND_AMOUNT * dir)

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player") and not body.is_in_group("enemies"):
		return
	_bend_to(0.0, RISE_DURATION)

# ── 굽힘 트윈 ─────────────────────────────────────────────
func _bend_to(target: float, duration: float = BEND_DURATION) -> void:
	if _mat == null:
		return
	if is_instance_valid(_tween):
		_tween.kill()
	var from := _mat.get_shader_parameter("bend") as float
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(
		func(v: float) -> void: _mat.set_shader_parameter("bend", v),
		from, target, duration
	)

# ── 세분화 메시 생성 ───────────────────────────────────────
func _setup_mesh(sprite: Sprite2D) -> Array:
	if not is_instance_valid(sprite) or not sprite.texture:
		return [null, null]

	var tex  := sprite.texture
	var w    := float(tex.get_width())
	var h    := float(tex.get_height())
	var rows := SUBDIVISIONS + 1

	var verts := PackedVector2Array()
	var uvs   := PackedVector2Array()
	var tris  := PackedInt32Array()

	for row in range(rows):
		var yf := float(row) / float(SUBDIVISIONS)
		verts.append(Vector2(-w * 0.5, -h * 0.5 + h * yf))
		verts.append(Vector2( w * 0.5, -h * 0.5 + h * yf))
		uvs.append(Vector2(0.0, yf))
		uvs.append(Vector2(1.0, yf))

	for row in range(SUBDIVISIONS):
		var b := row * 2
		tris.append_array([b, b + 2, b + 1, b + 1, b + 2, b + 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX]  = tris

	var amesh := ArrayMesh.new()
	amesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	mat.set_shader_parameter("wind_speed",    WIND_SPEED)
	mat.set_shader_parameter("wind_strength", WIND_STRENGTH)
	mat.set_shader_parameter("time_offset",   randf_range(0.0, 100.0))
	mat.set_shader_parameter("bend",          0.0)

	var mesh_inst      := MeshInstance2D.new()
	mesh_inst.mesh      = amesh
	mesh_inst.texture   = tex
	mesh_inst.material  = mat
	mesh_inst.position  = sprite.position
	sprite.get_parent().add_child(mesh_inst)
	sprite.visible = false

	return [mat, mesh_inst]
