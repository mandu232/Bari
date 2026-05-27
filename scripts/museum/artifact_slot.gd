extends Node2D
class_name ArtifactSlot
## 유물 전시대
## 플레이어가 가까이 오면 E키로 유물 배치 가능

# ───────────────────────────────
#  EXPORT
# ───────────────────────────────
@export var echo_scene: PackedScene = null

# ───────────────────────────────
#  STATE
# ───────────────────────────────
var artifact: ArtifactData = null
var echo: Echo             = null
var is_occupied: bool      = false
var is_powered: bool       = false   # 전력이 공급되면 true
var power_cost: int        = 0       # museum.gd 이 배치 전에 주입
var _player_nearby: bool   = false
var _essence_accum: float  = 0.0
var _float_tween: Tween    = null
var _label_base_y: float   = 0.0

const FLOAT_AMPLITUDE: float = 2.0    # 위아래 진폭 (픽셀)
const FLOAT_PERIOD:    float = 2.0    # 한 사이클 시간 (초)
const FLOAT_BASE_Y:    float = -20.0  # 배치대 기준 유물 기본 높이

# ───────────────────────────────
#  SIGNALS
# ───────────────────────────────
signal artifact_placed(slot: ArtifactSlot, data: ArtifactData)
signal artifact_removed(slot: ArtifactSlot)
signal essence_generated(amount: int)
signal interact_requested(slot: ArtifactSlot)   # Museum 으로 전달
signal wire_requested(source: Node2D)            # [F] 전선 연결 — Museum 이 처리

# ───────────────────────────────
#  NODES
# ───────────────────────────────
@onready var artifact_sprite:  Sprite2D         = $ArtifactSprite
@onready var pedestal_sprite:  AnimatedSprite2D  = $PedestalSprite
@onready var empty_indicator:  Node2D    = $EmptyIndicator
@onready var interact_area:    Area2D    = $InteractArea
@onready var slot_label:       Label     = $SlotLabel
@onready var hint_label:       Label     = $HintLabel     # "E - 유물 배치" 안내

# ───────────────────────────────
#  READY
# ───────────────────────────────
func _ready() -> void:
	add_to_group("placed_structure")   # 건설 중첩 방지용 그룹
	_label_base_y = slot_label.position.y
	hint_label.visible = false
	_refresh_visuals()
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	# 초기 전력 상태 — 비용 없는 슬롯만 즉시 켜짐
	# 실제 할당은 Museum._reallocate_power() 가 결정
	is_powered = (power_cost == 0)
	_update_powered_visuals()

# ───────────────────────────────
#  PROCESS
# ───────────────────────────────
func _process(delta: float) -> void:
	# 영력 생성 — 전력이 공급된 경우에만 생성
	# Echo의 기분(needs.essence_multiplier)이 생산량에 곱해짐
	if is_occupied and artifact != null and is_powered:
		var mult := 1.0
		if is_instance_valid(echo) and echo.needs != null:
			mult = echo.needs.essence_multiplier
		_essence_accum += artifact.essence_per_second * mult * delta
		if _essence_accum >= 1.0:
			var amount := int(_essence_accum)
			_essence_accum -= amount
			essence_generated.emit(amount)

	# 상호작용 입력 감지 — 전력 없으면 차단
	if _player_nearby and Input.is_action_just_pressed("interact"):
		if is_powered:
			interact_requested.emit(self)

# ───────────────────────────────
#  PUBLIC API
# ───────────────────────────────
func place_artifact(data: ArtifactData) -> void:
	if not is_powered or is_occupied:
		return
	artifact    = data
	is_occupied = true
	_refresh_visuals()
	_start_float()
	_spawn_echo()
	artifact_placed.emit(self, data)
	# 유물이 배치되면 출력·안정도 즉시 회복
	_fulfill_echo_needs(&"출력",   35.0)
	_fulfill_echo_needs(&"안정도", 15.0)

func remove_artifact() -> ArtifactData:
	if not is_occupied:
		return null
	_despawn_echo()
	_stop_float()
	var removed   := artifact
	artifact       = null
	is_occupied    = false
	_essence_accum = 0.0
	_refresh_visuals()
	artifact_removed.emit(self)
	return removed

# ───────────────────────────────
#  ECHO
# ───────────────────────────────
func _spawn_echo() -> void:
	if echo_scene == null:
		push_warning("ArtifactSlot: echo_scene 미설정")
		return
	echo = echo_scene.instantiate() as Echo
	get_parent().add_child(echo)
	echo.setup(artifact, global_position)

func _despawn_echo() -> void:
	if is_instance_valid(echo):
		echo.queue_free()
	echo = null

# ───────────────────────────────
#  PLAYER 감지
# ───────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_update_nearby_ui()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby     = false
		hint_label.visible = false
		if is_occupied:
			slot_label.visible = false

# ───────────────────────────────
#  FLOAT ANIMATION
# ───────────────────────────────
func _start_float() -> void:
	_stop_float()
	artifact_sprite.position.y = FLOAT_BASE_Y
	slot_label.position.y      = _label_base_y
	_float_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(artifact_sprite, "position:y", FLOAT_BASE_Y - FLOAT_AMPLITUDE, FLOAT_PERIOD * 0.5)
	_float_tween.parallel().tween_property(slot_label, "position:y", _label_base_y - FLOAT_AMPLITUDE, FLOAT_PERIOD * 0.5)
	_float_tween.tween_property(artifact_sprite, "position:y", FLOAT_BASE_Y + FLOAT_AMPLITUDE, FLOAT_PERIOD * 0.5)
	_float_tween.parallel().tween_property(slot_label, "position:y", _label_base_y + FLOAT_AMPLITUDE, FLOAT_PERIOD * 0.5)

func _stop_float() -> void:
	if _float_tween and _float_tween.is_valid():
		_float_tween.kill()
	_float_tween = null
	if is_inside_tree():
		artifact_sprite.position.y = 0.0
		slot_label.position.y      = _label_base_y

# ───────────────────────────────
#  전력 관리 (Museum 중앙 할당)
# ───────────────────────────────
## Museum._reallocate_power() 가 호출 — 전력 ON/OFF 세팅
func set_powered(value: bool) -> void:
	if is_powered == value:
		return
	is_powered = value
	_update_powered_visuals()
	# 전력이 들어오면 출력 회복 / 끊기면 자연 감소에 맡김
	if is_powered:
		_fulfill_echo_needs(&"출력", 25.0)

## 전력 상태에 따라 배치대 애니메이션 전환
func _update_powered_visuals() -> void:
	modulate = Color.WHITE  # 전체 노드 모듈레이트 초기화
	if pedestal_sprite and pedestal_sprite.sprite_frames:
		var anim: StringName = &"on" if is_powered else &"off"
		if pedestal_sprite.sprite_frames.has_animation(anim):
			pedestal_sprite.play(anim)
	if _player_nearby:
		_update_nearby_ui()

## 플레이어 근처일 때 힌트 레이블 상태 업데이트
func _update_nearby_ui() -> void:

	if not is_powered and power_cost > 0:
		slot_label.visible = false
		hint_label.text    = "⚡ 전력 없음"
		hint_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		hint_label.visible = true
	elif is_occupied:
		slot_label.visible = true
		hint_label.text    = "[E] 유물 교체"
		hint_label.add_theme_color_override("font_color", Color(0.56078434, 0.972549, 0.8862745))
		hint_label.visible = true
	else:
		slot_label.visible = false
		hint_label.text    = "[E] 유물 배치"
		hint_label.add_theme_color_override("font_color", Color(0.56078434, 0.972549, 0.8862745))
		hint_label.visible = true

# ───────────────────────────────
#  NEEDS 헬퍼
# ───────────────────────────────
## 이 슬롯의 Echo가 유효하고 needs 가 있을 때만 회복
func _fulfill_echo_needs(need_id: StringName, amount: float) -> void:
	if is_instance_valid(echo) and echo.needs != null:
		echo.needs.fulfill(need_id, amount)

# ───────────────────────────────
#  [F] 키 — 배선 요청
# ───────────────────────────────
## 플레이어가 근처에 있을 때만 처리 — 전력 비용이 있는 슬롯만 배선 대상으로 허용
func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or power_cost == 0:
		return
	if event.is_action_pressed("sub_interact"):
		wire_requested.emit(self)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	pass  # 범위 기반 전력: 해제 시 별도 반환 불필요

# ───────────────────────────────
#  VISUALS
# ───────────────────────────────
func _refresh_visuals() -> void:
	if not is_inside_tree():
		return
	if is_occupied and artifact != null:
		artifact_sprite.texture = artifact.texture
		artifact_sprite.visible = true
		empty_indicator.visible = false
		slot_label.text         = artifact.artifact_name
		slot_label.visible      = _player_nearby  # 가까이 갈 때만 표시
		hint_label.visible      = false
	else:
		artifact_sprite.texture = null
		artifact_sprite.visible = false
		empty_indicator.visible = true
		slot_label.text         = ""
		slot_label.visible      = false
		# hint 는 플레이어 접근 시에만 표시
