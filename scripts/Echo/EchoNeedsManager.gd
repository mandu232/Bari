extends Node
class_name EchoNeedsManager
## Echo의 모든 욕구 수치를 중앙 관리
##
## 구조:
##  • 안정도 — 플레이어 상호작용, 던전 클리어로 회복 / 천천히 감소
##  • 출력 — 유물 전시 + 전력 공급 중일 때 회복 / 중간 속도 감소
##  • 활성도   — 시간 경과로 자연 회복 이벤트 / 빠르게 감소
##
## 가장 낮은 수치 기준으로 전체 기분(mood)을 계산합니다.
## mood 는 Echo 의 비주얼 및 영력 생산량에 영향을 줍니다.

# ───────────────────────────────
#  SIGNALS
# ───────────────────────────────
## 전체 기분이 바뀔 때 (행복/보통/불만/고통)
signal mood_changed(new_mood: StringName)
## 수치 중 하나가 위험 구간에 진입했을 때 — UI 경고, 이벤트 트리거에 사용
signal need_critical(need: EchoNeed)

# ───────────────────────────────
#  STATE
# ───────────────────────────────
## 현재 기분 — 가장 낮은 수치의 비율로 자동 결정
var mood: StringName = &"보통":
	set(v):
		if mood == v:
			return
		mood = v
		mood_changed.emit(mood)

var _needs: Dictionary = {}   # StringName → EchoNeed

# ───────────────────────────────
#  영력 생산량 보정 (읽기 전용)
# ───────────────────────────────
## Echo 가 essence_per_second 에 곱해서 최종 영력 생산량 계산
var essence_multiplier: float:
	get:
		match mood:
			&"평온": return 1.5   # 행복하면 영력 50% 보너스
			&"보통": return 1.0
			&"우울": return 0.5   # 불만이면 절반
			&"한계": return 0.0   # 고통 상태면 영력 없음
		return 1.0

# ───────────────────────────────
#  READY — 기본 욕구 3가지 등록
# ───────────────────────────────
func _ready() -> void:
	_register(&"안정도", "안정도", 1.0,
		[{threshold = 70.0, tier = &"평온"},
		 {threshold = 40.0, tier = &"보통"},
		 {threshold = 15.0, tier = &"우울"},
		 {threshold =  0.0, tier = &"한계"}])

	_register(&"출력", "출력", 0.7,
		[{threshold = 65.0, tier = &"넘침"},
		 {threshold = 35.0, tier = &"평온"},
		 {threshold = 10.0, tier = &"부족"},
		 {threshold =  0.0, tier = &"멈춤"}])

	_register(&"활성도", "활성도", 2.2,
		[{threshold = 60.0, tier = &"활발"},
		 {threshold = 30.0, tier = &"느긋"},
		 {threshold = 10.0, tier = &"처짐"},
		 {threshold =  0.0, tier = &"고요"}])

# ───────────────────────────────
#  PROCESS — 매 프레임 감소
# ───────────────────────────────
func _process(delta: float) -> void:
	for need: EchoNeed in _needs.values():
		need.tick(delta)
	_update_mood()

# ───────────────────────────────
#  PUBLIC API
# ───────────────────────────────
## 특정 수치를 amount 만큼 회복
## 예: needs.fulfill(&"만족도", 20.0)
func fulfill(need_id: StringName, amount: float) -> void:
	var need := _needs.get(need_id) as EchoNeed
	if need:
		need.restore(amount)

## 특정 욕구의 초당 감소량을 변경 — ArtifactData 에서 유물별로 주입
func set_decay(need_id: StringName, decay_per_sec: float) -> void:
	var need := _needs.get(need_id) as EchoNeed
	if need:
		need.decay_per_sec = maxf(decay_per_sec, 0.0)

## 특정 수치 조회
func get_need(id: StringName) -> EchoNeed:
	return _needs.get(id, null)

## 전체 수치 배열 반환 (HUD/디버그 UI 표시용)
func get_all_needs() -> Array:
	return _needs.values()

# ───────────────────────────────
#  저장 / 복원
# ───────────────────────────────
## Museum.gd 의 save_game() 에서 호출 — 현재 수치를 딕셔너리로 직렬화
func serialize() -> Dictionary:
	var data: Dictionary = {}
	for id: StringName in _needs:
		data[str(id)] = (_needs[id] as EchoNeed).value
	return data

## 복원 시 호출 — 저장된 수치를 각 EchoNeed 에 주입
func deserialize(data: Dictionary) -> void:
	for key: String in data:
		var need := _needs.get(StringName(key)) as EchoNeed
		if need:
			need.value = clampf(data[key], 0.0, need.max_value)
	_update_mood()

# ───────────────────────────────
#  INTERNAL
# ───────────────────────────────
func _register(id: StringName, label: String,
			   decay: float, tiers: Array) -> void:
	var need := EchoNeed.new()
	need.setup(id, label, decay, tiers)
	need.value_changed.connect(_on_value_changed)
	need.threshold_crossed.connect(_on_threshold_crossed)
	_needs[id] = need

## 전체 수치 중 가장 낮은 비율을 기준으로 기분 결정
func _update_mood() -> void:
	var min_ratio := 1.0
	for need: EchoNeed in _needs.values():
		min_ratio = minf(min_ratio, need.get_ratio())

	if   min_ratio >= 0.65: mood = &"평온"
	elif min_ratio >= 0.40: mood = &"보통"
	elif min_ratio >= 0.20: mood = &"우울"
	else:                   mood = &"한계"

func _on_value_changed(_need: EchoNeed, _old: float, _new_val: float) -> void:
	pass   # 필요 시 HUD 실시간 갱신 훅으로 확장 가능

func _on_threshold_crossed(need: EchoNeed,
							tier: StringName, going_down: bool) -> void:
	# 수치가 내려가며 위험 구간 진입 시 외부에 알림
	if going_down and tier in [&"한계", &"멈춤", &"고요"]:
		need_critical.emit(need)
