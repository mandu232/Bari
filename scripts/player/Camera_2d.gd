extends Camera2D

const BASE_ZOOM := Vector2(3.0, 3.0)

var _shake_intensity: float = 0.0
var _shake_decay:     float = 0.0

func _ready() -> void:
	add_to_group("camera")
	zoom                     = BASE_ZOOM
	position_smoothing_enabled = true
	position_smoothing_speed   = 3.5

func _process(delta: float) -> void:
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
# 빠르게 목표 배율로 이동한 뒤 베이스 배율로 복귀
func zoom_punch(zoom_delta: float = 0.2, duration: float = 0.18) -> void:
	var target := BASE_ZOOM + Vector2(zoom_delta, zoom_delta)
	var tw     := create_tween()
	tw.set_parallel(false)
	tw.tween_property(self, "zoom", target,    duration * 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(self, "zoom", BASE_ZOOM, duration * 0.65).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
