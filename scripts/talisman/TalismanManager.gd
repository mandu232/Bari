extends Node
## 부적 관리자 (AutoLoad: TalismanManager)
## 던전 런 동안 장착된 부적 상태를 추적하고 플레이어에게 효과를 적용한다

const MAX_SLOTS := 3
const BLOCK_MANA_BASE_COST: int = 20   # 막기 1회 소모 마나 (기본값)

var equipped: Array[TalismanData] = []

var _shield_active:     bool  = false
var _speed_burst_timer: float = 0.0
var _speed_burst_amt:   float = 0.0

# 은영부 — 그림자 기습 충전
var _shadow_charge_timer: float = 0.0
var _shadow_ready:        bool  = false

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

	# 은영부 — 그림자 기습 충전
	if not _shadow_ready:
		var charge_time := _get_ambush_charge_time()
		if charge_time > 0.0:
			_shadow_charge_timer += delta
			if _shadow_charge_timer >= charge_time:
				_shadow_charge_timer = 0.0
				_shadow_ready = true
				_on_shadow_charged()

# ─────────────────────────────────────────────
#  런 종료 시 전부 초기화
# ─────────────────────────────────────────────
func _on_run_ended(_success: bool) -> void:
	_remove_all_bonuses()
	equipped.clear()
	_shield_active        = false
	_speed_burst_timer    = 0.0
	_speed_burst_amt      = 0.0
	_shadow_charge_timer  = 0.0
	_shadow_ready         = false
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
			TalismanData.Effect.HOWL_MIMIC:
				var dur := data.effect_value if data.effect_value > 0.0 else 3.0
				_apply_howl_debuff(_enemy_pos, dur)

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

# ─────────────────────────────────────────────
#  호소부 — 주변 적 둔화 디버프
# ─────────────────────────────────────────────
func _apply_howl_debuff(origin: Vector2, duration: float) -> void:
	const RADIUS := 160.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(origin) <= RADIUS:
			if enemy.has_method("apply_slow"):
				enemy.apply_slow(0.5, duration)

# ─────────────────────────────────────────────
#  은영부 — 그림자 기습
# ─────────────────────────────────────────────
func _get_ambush_charge_time() -> float:
	for data: TalismanData in equipped:
		if data.effect == TalismanData.Effect.GOBLIN_AMBUSH:
			return data.effect_value if data.effect_value > 0.0 else 4.0
	return 0.0

## 충전 완료 시 플레이어에 보라빛 플래시
func _on_shadow_charged() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var spr: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if not is_instance_valid(spr):
		return
	spr.modulate = Color(1.4, 0.3, 2.2, 1.0)
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color.WHITE, 0.7)

## 플레이어 피격 시 충전 초기화 — Player.take_damage 에서 호출
func on_player_took_damage() -> void:
	_shadow_ready        = false
	_shadow_charge_timer = 0.0

## 공격 히트 시 기습 배율 반환 — Player._on_attack_hit 에서 호출
## 충전 완료 + 순찰 중인 적이면 3.0 반환 후 소모, 아니면 1.0
func consume_ambush_bonus(enemy: Node) -> float:
	if not _shadow_ready:
		return 1.0
	if not is_instance_valid(enemy) or not enemy.has_method("is_unaware"):
		return 1.0
	if not enemy.is_unaware():
		return 1.0
	_shadow_ready        = false
	_shadow_charge_timer = 0.0
	return 3.0

# ─────────────────────────────────────────────
#  태산부 — 막기 마나 비용 / 패링 마나 회복
# ─────────────────────────────────────────────
## 이번 막기에 소모될 마나 반환 — 태산부 장착 시 절반
func get_block_mana_cost() -> int:
	for data: TalismanData in equipped:
		if data.effect == TalismanData.Effect.MOUNTAIN_WEIGHT:
			return BLOCK_MANA_BASE_COST / 2   # 20 → 10
	return BLOCK_MANA_BASE_COST

## 패링 성공 시 회복할 마나 반환 — 태산부 없으면 0
func get_parry_mana_recovery() -> int:
	for data: TalismanData in equipped:
		if data.effect == TalismanData.Effect.MOUNTAIN_WEIGHT:
			return int(data.effect_value) if data.effect_value > 0.0 else 30
	return 0
