extends CanvasLayer
## 화면 후처리 효과 — 비네트

const VIGNETTE_SHADER := preload("res://AutoLoad/shaders/vignette.gdshader")

const VIG_NORMAL_INTENSITY := 0.55
const VIG_LOW_HP_INTENSITY  := 1.10
const VIG_LERP_SPEED        := 2.5

var _vignette_mat: ShaderMaterial = null

var _target_intensity: float = VIG_NORMAL_INTENSITY
var _target_tint:      Color  = Color(0.0, 0.0, 0.0, 1.0)

func _ready() -> void:
	layer = 50
	_build_vignette()
	add_to_group("screen_effects")

func _process(delta: float) -> void:
	if _vignette_mat == null:
		return
	var cur_intensity: float = _vignette_mat.get_shader_parameter("intensity")
	var cur_tint:      Color  = _vignette_mat.get_shader_parameter("tint_color")
	_vignette_mat.set_shader_parameter(
		"intensity",
		lerp(cur_intensity, _target_intensity, delta * VIG_LERP_SPEED)
	)
	_vignette_mat.set_shader_parameter(
		"tint_color",
		cur_tint.lerp(_target_tint, delta * VIG_LERP_SPEED)
	)

func _build_vignette() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = VIGNETTE_SHADER
	mat.set_shader_parameter("intensity",  VIG_NORMAL_INTENSITY)
	mat.set_shader_parameter("softness",   0.40)
	mat.set_shader_parameter("tint_color", Color(0.0, 0.0, 0.0, 1.0))
	_vignette_mat = mat

	var rect := ColorRect.new()
	rect.color         = Color.TRANSPARENT
	rect.material      = mat
	rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	rect.anchor_right  = 1.0
	rect.anchor_bottom = 1.0
	add_child(rect)

## HP 비율(0.0~1.0)에 따라 비네트 강도·색조 갱신
func update_hp_ratio(ratio: float) -> void:
	if ratio > 0.5:
		_target_intensity = VIG_NORMAL_INTENSITY
		_target_tint      = Color(0.0, 0.0, 0.0, 1.0)
	elif ratio > 0.25:
		var t := 1.0 - (ratio - 0.25) / 0.25
		_target_intensity = lerp(VIG_NORMAL_INTENSITY, VIG_LOW_HP_INTENSITY * 0.75, t)
		_target_tint      = Color(t * 0.5, 0.0, 0.0, 1.0)
	else:
		_target_intensity = VIG_LOW_HP_INTENSITY
		_target_tint      = Color(0.55, 0.0, 0.0, 1.0)
