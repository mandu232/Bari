extends Camera2D

const BASE_ZOOM  := Vector2(3.0, 3.0)
const MIN_ZOOM   := Vector2(3.0, 3.0)   # 기본 줌(3.0) 이하로 축소 불가
const MAX_ZOOM   := Vector2(5.0, 5.0)
const ZOOM_STEP  := 0.25   # 스크롤 한 단계당 줌 변화량

var _shake_intensity: float   = 0.0
var _shake_decay:     float   = 0.0
var _user_zoom:       Vector2 = BASE_ZOOM  # 사용자가 스크롤로 설정한 목표 줌
var _zoom_punching:   bool    = false      # zoom_punch 진행 중 → lerp 일시 중단

func _ready() -> void:
	add_to_group("camera")
	zoom                       = BASE_ZOOM
	position_smoothing_enabled = true
	position_smoothing_speed   = 3.5

# ── 마우스 휠 줌 (박물관 씬 전용)
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	# 박물관 씬에서만 줌 허용
	if not (get_tree().current_scene is Museum):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_user_zoom = (_user_zoom + Vector2(ZOOM_STEP, ZOOM_STEP)).clamp(MIN_ZOOM, MAX_ZOOM)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_DOWN:
			_user_zoom = (_user_zoom - Vector2(ZOOM_STEP, ZOOM_STEP)).clamp(MIN_ZOOM, MAX_ZOOM)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# 사용자 줌 목표로 부드럽게 보간 (zoom_punch 중엔 중단)
	if not _zoom_punching:
		zoom = zoom.lerp(_user_zoom, delta * 12.0)

	# 화면 흔들기
	if _shake_intensity > 0.0:
		offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		_shake_intensity = maxf(_shake_intensity - _shake_decay * delta, 0.0)
		if _shake_intensity <= 0.0:
			offset = Vector2.ZERO

# ── 화면 흔들기
# intensity : 최대 픽셀 흔들림 (카메라 좌표 기준)
# duration  : 흔들림 지속 시간 (초)
func screen_shake(intensity: float = 5.0, duration: float = 0.25) -> void:
	_shake_intensity = intensity
	_shake_decay     = intensity / maxf(duration, 0.01)

# ── 줌 펀치 (zoom_delta > 0 이면 확대, < 0 이면 축소)
# 사용자 줌(_user_zoom) 기준으로 튀었다 복귀
func zoom_punch(zoom_delta: float = 0.2, duration: float = 0.18) -> void:
	_zoom_punching  = true
	var target      := (_user_zoom + Vector2(zoom_delta, zoom_delta)).clamp(MIN_ZOOM, MAX_ZOOM)
	var tw          := create_tween()
	tw.set_parallel(false)
	tw.tween_property(self, "zoom", target,      duration * 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "zoom", _user_zoom,  duration * 0.65) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func() -> void: _zoom_punching = false)
