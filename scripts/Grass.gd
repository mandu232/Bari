extends Node2D

const GRASS_SHADER := preload("res://AutoLoad/shaders/grass_wind.gdshader")

# ── 바람
const WIND_STRENGTH  := 2.0
const WIND_SPEED     := 1.5
const BEND_AMOUNT    := 14.0
const BEND_DURATION  := 0.10
const RISE_DURATION  := 0.55
const SUBDIVISIONS   := 6

# ── 베임 감지
## 공격박스 중심과 풀 Area2D 중심 간 최대 거리 (픽셀)
const CUT_DETECT_RADIUS := 18.0

# ── 베임 이펙트
const CUT_FLASH_COLOR  := Color(3.0, 3.0, 3.0)
const CUT_FLASH_TIME   := 0.10
const CUT_EFFECT_TEX   := preload("res://AutoLoad/assets/Grass/Grasscut_effect.png")
const CUT_FX_COUNT     := 1    # 튀어나오는 조각 수

# ── cut 텍스처 경로 (해당 파일을 추가하면 자동으로 적용)
const CUT_TEX_L := "res://AutoLoad/assets/Grass/Grass_L_cut.png"
const CUT_TEX_R := "res://AutoLoad/assets/Grass/Grass_R_cut.png"

var _mat_l:  ShaderMaterial = null
var _mat_r:  ShaderMaterial = null
var _mesh_l: MeshInstance2D = null
var _mesh_r: MeshInstance2D = null
var _tween_l: Tween = null
var _tween_r: Tween = null

var _cut_l   := false
var _cut_r   := false
var _player:     Node2D  = null
var _attack_box: Area2D  = null

@onready var _grass_l: Sprite2D = $grass_L
@onready var _grass_r: Sprite2D = $grass_R
@onready var _area_l:  Area2D   = $grass_L/Area2D
@onready var _area_r:  Area2D   = $grass_R/Area2D

func _ready() -> void:
	var r_l := _setup_grass_mesh(_grass_l)
	_mat_l  = r_l[0];  _mesh_l = r_l[1]
	var r_r := _setup_grass_mesh(_grass_r)
	_mat_r  = r_r[0];  _mesh_r = r_r[1]

	_area_l.body_entered.connect(func(b): _on_bend(b, true))
	_area_l.body_exited.connect(func(b):  _on_rise(b, true))
	_area_r.body_entered.connect(func(b): _on_bend(b, false))
	_area_r.body_exited.connect(func(b):  _on_rise(b, false))

	# 탑다운 Y축 정렬: Y가 클수록(아래쪽) 앞에 그려짐 (플레이어와 동일한 절대값 기준)
	z_as_relative = false
	z_index = int(global_position.y)

# ── 공격 감지 ──────────────────────────────────────────────
func _process(_delta: float) -> void:
	if _cut_l and _cut_r:
		set_process(false)
		return

	# 플레이어 + AttackBox 캐시
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if not is_instance_valid(_player):
			return
		_attack_box = _player.get_node_or_null("AttackBox") as Area2D

	if not is_instance_valid(_attack_box) or not _attack_box.monitoring:
		return

	var apos := _attack_box.global_position
	if not _cut_l and apos.distance_to(_area_l.global_position) < CUT_DETECT_RADIUS:
		_cut_grass(true)
	if not _cut_r and apos.distance_to(_area_r.global_position) < CUT_DETECT_RADIUS:
		_cut_grass(false)

# ── 풀 베기 ────────────────────────────────────────────────
func _cut_grass(is_left: bool) -> void:
	var mat  := _mat_l  if is_left else _mat_r
	var mesh := _mesh_l if is_left else _mesh_r
	var h      := float(mesh.texture.get_height()) if is_instance_valid(mesh) and mesh.texture else 16.0
	var fx_pos := mesh.global_position + Vector2(0.0, -h * 0.05)

	if is_left: _cut_l = true
	else:       _cut_r = true

	# 바람 정지
	_kill_tween(is_left)
	if mat:
		mat.set_shader_parameter("wind_strength", 0.0)
		mat.set_shader_parameter("bend", 0.0)

	if not is_instance_valid(mesh):
		return

	# 텍스처 교체
	var cut_path := CUT_TEX_L if is_left else CUT_TEX_R
	if ResourceLoader.exists(cut_path):
		mesh.texture = load(cut_path) as Texture2D
	else:
		# cut 텍스처가 없으면 갈색 틴트로 임시 표현
		mesh.modulate = Color(0.6, 0.38, 0.12)

	# 흰 플래시
	mesh.modulate = CUT_FLASH_COLOR
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	var end_color := Color.WHITE if ResourceLoader.exists(cut_path) else Color(0.6, 0.38, 0.12)
	tw.tween_property(mesh, "modulate", end_color, CUT_FLASH_TIME)

	# 베임 파티클
	_spawn_cut_fx(fx_pos)

# ── 베임 이펙트 (Grasscut_effect.png 조각 3개가 위로 튀어오름) ───
func _spawn_cut_fx(world_pos: Vector2) -> void:
	for _i in CUT_FX_COUNT:
		var spr := Sprite2D.new()
		spr.texture  = CUT_EFFECT_TEX
		spr.z_index  = 100
		spr.scale    = Vector2.ONE * randf_range(0.7, 1.3)
		spr.rotation = randf_range(-0.8, 0.8)
		get_parent().add_child(spr)
		spr.global_position = world_pos + Vector2(randf_range(-5.0, 5.0), 0.0)

		var fly := Vector2(randf_range(-14.0, 14.0), randf_range(-28.0, -14.0))
		var dur  := randf_range(0.28, 0.45)

		var tw := spr.create_tween().set_parallel(true)
		tw.tween_property(spr, "global_position", spr.global_position + fly, dur)\
		  .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(spr, "modulate:a", 0.0, dur * 0.55)\
		  .set_delay(dur * 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.finished.connect(spr.queue_free)

# ── 세분화 메시 생성 ───────────────────────────────────────
func _setup_grass_mesh(sprite: Sprite2D) -> Array:
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

	var mesh_inst       := MeshInstance2D.new()
	mesh_inst.mesh       = amesh
	mesh_inst.texture    = tex
	mesh_inst.material   = mat
	mesh_inst.position   = sprite.position
	sprite.get_parent().add_child(mesh_inst)
	sprite.visible = false

	return [mat, mesh_inst]

# ── 눕기 / 일어나기 ───────────────────────────────────────
func _on_bend(body: Node, is_left: bool) -> void:
	if not body.is_in_group("player") and not body.is_in_group("enemies"):
		return
	var mat    := _mat_l if is_left else _mat_r
	if mat == null: return
	var target := -BEND_AMOUNT if is_left else BEND_AMOUNT
	_kill_tween(is_left)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("bend", v),
		mat.get_shader_parameter("bend") as float, target, BEND_DURATION
	)
	if is_left: _tween_l = tw
	else:       _tween_r = tw

func _on_rise(body: Node, is_left: bool) -> void:
	if not body.is_in_group("player") and not body.is_in_group("enemies"):
		return
	var mat := _mat_l if is_left else _mat_r
	if mat == null: return
	var cur := mat.get_shader_parameter("bend") as float
	_kill_tween(is_left)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("bend", v),
		cur, 0.0, RISE_DURATION
	)
	if is_left: _tween_l = tw
	else:       _tween_r = tw

func _kill_tween(is_left: bool) -> void:
	var tw: Tween = _tween_l if is_left else _tween_r
	if is_instance_valid(tw):
		tw.kill()
