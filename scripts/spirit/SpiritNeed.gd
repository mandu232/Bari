extends RefCounted
class_name SpiritNeed
## 혼(Spirit)의 욕구 수치 하나를 표현
## 값은 0~100 사이를 유지하며, 매 프레임 decay_per_sec 만큼 자연 감소합니다.

# ───────────────────────────────
#  SIGNALS
# ───────────────────────────────
## 수치가 변할 때마다 발신
signal value_changed(need: SpiritNeed, old_val: float, new_val: float)
## 구간(tier)이 바뀔 때 발신 — going_down: true = 수치가 떨어지며 교차
signal threshold_crossed(need: SpiritNeed, tier: StringName, going_down: bool)

# ───────────────────────────────
#  DATA
# ───────────────────────────────
var id:            StringName = &""
var label:         String     = ""
var value:         float      = 100.0
var max_value:     float      = 100.0
var decay_per_sec: float      = 2.0     ## 초당 자연 감소량

## 구간 배열: [{threshold: float, tier: StringName}]
## setup() 에서 threshold 내림차순으로 자동 정렬
var _tiers:        Array      = []
var _current_tier: StringName = &""

# ───────────────────────────────
#  SETUP
# ───────────────────────────────
## id, 레이블, 감소율, 구간 배열을 한 번에 설정
## tiers 예시: [{threshold=70.0, tier=&"행복"}, {threshold=40.0, tier=&"보통"}, ...]
func setup(p_id: StringName, p_label: String,
           p_decay: float, tiers: Array) -> void:
	id            = p_id
	label         = p_label
	decay_per_sec = p_decay
	_tiers        = tiers.duplicate()
	_tiers.sort_custom(func(a, b): return a["threshold"] > b["threshold"])
	_current_tier = _calc_tier(value)

# ───────────────────────────────
#  TICK / RESTORE
# ───────────────────────────────
## SpiritNeedsManager._process() 에서 호출 — 자연 감소
func tick(delta: float) -> void:
	_set_value(value - decay_per_sec * delta)

## 수치 회복 (amount > 0 이면 올라감)
func restore(amount: float) -> void:
	_set_value(value + amount)

# ───────────────────────────────
#  PUBLIC HELPERS
# ───────────────────────────────
## 0~1 비율 반환 (UI 진행 바 등에 사용)
func get_ratio() -> float:
	return value / max_value if max_value > 0.0 else 0.0

## 현재 구간 이름 반환
func get_tier() -> StringName:
	return _current_tier

# ───────────────────────────────
#  INTERNAL
# ───────────────────────────────
func _set_value(new_val: float) -> void:
	var clamped := clampf(new_val, 0.0, max_value)
	if is_equal_approx(clamped, value):
		return
	var old_val := value
	value       = clamped
	value_changed.emit(self, old_val, value)
	_check_threshold(old_val, value)

func _check_threshold(old_val: float, new_val: float) -> void:
	var new_tier := _calc_tier(new_val)
	if new_tier == _current_tier:
		return
	var going_down := new_val < old_val
	_current_tier  = new_tier
	threshold_crossed.emit(self, new_tier, going_down)

func _calc_tier(v: float) -> StringName:
	for entry in _tiers:
		if v >= entry["threshold"]:
			return entry["tier"]
	return _tiers.back()["tier"] if not _tiers.is_empty() else &""
