extends Node
## 부적 관리자 (AutoLoad: TalismanManager)
## 던전 런 동안 장착된 부적 상태를 추적하고 플레이어에게 효과를 적용한다

const MAX_SLOTS := 3

var equipped: Array[TalismanData] = []

var _shield_active:     bool  = false
var _speed_burst_timer: float = 0.0
var _speed_burst_amt:   float = 0.0

signal talisman_changed   # equipped 배열 변화 시 발생 (HUD 갱신 트리거)

# ─────────────────────────────────────────────
#  초기화
# ─────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.run_ended.connect(_on_run_ended)

func _process(delta: float) -> void:
	# 속도 버스트 타이머
	if _speed_burst_timer > 0.0:
		_speed_burst_timer -= delta
		if _speed_burst_timer <= 0.0:
			_speed_burst_timer = 0.0
			_end_speed_burst()

# ─────────────────────────────────────────────
#  런 종료 시 전부 초기화
# ─────────────────────────────────────────────
func _on_run_ended(_success: bool) -> void:
	_remove_all_bonuses()
	equipped.clear()
	_shield_active     = false
	_speed_burst_timer = 0.0
	_speed_burst_amt   = 0.0
	talisman_changed.emit()

# ─────────────────────────────────────────────
#  장착 / 교체
# ─────────────────────────────────────────────
func can_equip() -> bool:
	return equipped.size() < MAX_SLOTS

func equip(data: TalismanData) -> void:
	if equipped.size() >= MAX_SLOTS:
		return
	equipped.append(data)
	_recalc(null)
	if data.effect == TalismanData.Effect.SHIELD:
		_shield_active = true
	talisman_changed.emit()

## 슬롯 가득 찼을 때 index 번 부적과 교체
func replace(new_data: TalismanData, index: int) -> void:
	if index < 0 or index >= equipped.size():
		return
	var old := equipped[index]
	equipped[index] = new_data
	# 교체되는 부적이 SHIELD였으면 방어막 재확인
	if old.effect == TalismanData.Effect.SHIELD:
		_refresh_shield()
	_recalc(null)
	if new_data.effect == TalismanData.Effect.SHIELD:
		_shield_active = true
	talisman_changed.emit()

# ─────────────────────────────────────────────
#  적 처치 시 특수 효과 트리거 (Enemy._die 에서 호출)
# ─────────────────────────────────────────────
func on_enemy_died(_enemy_pos: Vector2) -> void:
	if equipped.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	for data: TalismanData in equipped:
		match data.effect:
			TalismanData.Effect.LIFESTEAL:
				var amount := int(data.effect_value) if data.effect_value >= 1 else 1
				if player.has_method("heal"):
					player.heal(amount)
			TalismanData.Effect.SPEED_BURST:
				var dur := data.effect_value if data.effect_value > 0.0 else 2.0
				_start_speed_burst(30.0, dur)

# ─────────────────────────────────────────────
#  방어막 소비 (Player.take_damage 에서 호출)
#  방어막이 활성화 중이면 true 반환 후 해제
# ─────────────────────────────────────────────
func consume_shield() -> bool:
	if not _shield_active:
		return false
	_shield_active = false
	talisman_changed.emit()
	return true

func is_shield_active() -> bool:
	return _shield_active

# ─────────────────────────────────────────────
#  내부 — 스탯 재계산
# ─────────────────────────────────────────────
func _recalc(player: Node) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or not player.has_method("set_talisman_bonus"):
		return

	var total_atk: int   = 0
	var total_def: int   = 0
	var total_hp:  int   = 0
	var total_spd: float = _speed_burst_amt  # 버스트 포함

	for data: TalismanData in equipped:
		total_atk += data.bonus_atk
		total_def += data.bonus_def
		total_hp  += data.bonus_hp
		total_spd += data.bonus_speed

	player.call("set_talisman_bonus", total_atk, total_def, total_spd, total_hp)

func _remove_all_bonuses() -> void:
	_speed_burst_amt   = 0.0
	_speed_burst_timer = 0.0
	_recalc(null)

func _refresh_shield() -> void:
	_shield_active = false
	for data: TalismanData in equipped:
		if data.effect == TalismanData.Effect.SHIELD:
			_shield_active = true
			break

# ─────────────────────────────────────────────
#  속도 버스트
# ─────────────────────────────────────────────
func _start_speed_burst(amount: float, duration: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	# 이미 버스트 중이면 시간만 연장
	if _speed_burst_timer <= 0.0:
		_speed_burst_amt = amount
		_recalc(player)
	_speed_burst_timer = duration

func _end_speed_burst() -> void:
	_speed_burst_amt = 0.0
	_recalc(null)
