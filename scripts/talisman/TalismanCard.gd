extends Area2D
class_name TalismanCard
## 던전 바닥에 드랍되는 부적
## 플레이어가 가까이 가면 자석처럼 끌려가 자동 획득 → 슬롯 선택 UI 표시

const CHARM_RED    := preload("res://AutoLoad/assets/Charm/Charm_item_red.png")
const CHARM_BLUE   := preload("res://AutoLoad/assets/Charm/Charm_item_blue.png")
const CHARM_GREEN  := preload("res://AutoLoad/assets/Charm/Charm_item_green.png")
const CHARM_PURPLE := preload("res://AutoLoad/assets/Charm/Charm_item_purple.png")

var _data:       TalismanData = null
var _collected:  bool         = false
var _attracting: bool         = false
var _float_time: float        = 0.0
var _ui_open:    bool         = false

var _sprite: Sprite2D = null

func setup(data: TalismanData) -> void:
	_data = data

func _ready() -> void:
	add_to_group("talisman_cards")

	# 유물과 동일한 Sprite2D — 부적 이름에 따라 색상 텍스처 선택
	_sprite         = Sprite2D.new()
	_sprite.texture = _pick_charm_tex()
	_sprite.scale   = Vector2.ZERO   # 등장 연출 후 0.75로
	add_child(_sprite)

	var col  := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 40.0
	col.shape   = circ
	add_child(col)

	collision_layer = 0
	collision_mask  = 1   # 플레이어 레이어(1)만 감지

	body_entered.connect(_on_body_entered)

	# 등장 연출 (유물과 동일)
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(0.82, 0.82), 0.18)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_sprite, "scale", Vector2(0.75, 0.75), 0.08)\
		.set_ease(Tween.EASE_IN)

# ────────────────────────────────────────
#  프로세스 — 둥둥 + 자석 흡인
# ────────────────────────────────────────
func _process(delta: float) -> void:
	if _collected:
		return

	z_as_relative = false
	z_index       = int(global_position.y) + 1

	_float_time        += delta * 2.8
	_sprite.position.y  = sin(_float_time) * 4.0

	# 자석 흡인 (UI 열려있으면 멈춤)
	if _attracting and not _ui_open:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(player):
			var to_player := player.global_position - global_position
			if to_player.length() < 16.0:
				_collect()
				return
			var speed := lerpf(180.0, 420.0, 1.0 - clampf(to_player.length() / 60.0, 0.0, 1.0))
			global_position += to_player.normalized() * speed * delta

# ────────────────────────────────────────
#  감지 → 흡인 시작
# ────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _collected:
		_attracting = true

# ────────────────────────────────────────
#  부적 이름 → 색상 텍스처 선택
# ────────────────────────────────────────
func _pick_charm_tex() -> Texture2D:
	if _data == null:
		return CHARM_PURPLE
	match _data.talisman_name:
		"흡성부": return CHARM_RED
		"파석부": return CHARM_RED
		"신각부": return CHARM_BLUE
		"철신부": return CHARM_GREEN
		_:        return CHARM_PURPLE

func land() -> void:
	collision_mask = 1

# ────────────────────────────────────────
#  획득 → 슬롯 선택 UI
# ────────────────────────────────────────
func _collect() -> void:
	if _collected or _data == null or _ui_open:
		return
	_ui_open    = true
	_attracting = false
	var ui := TalismanSwapUI.new()
	ui.setup(_data, self)
	get_tree().root.add_child(ui)

## TalismanSwapUI 에서 호출: 플레이어가 슬롯을 선택했을 때
func on_swap_confirmed(slot_index: int) -> void:
	_ui_open   = false
	_collected = true
	if slot_index >= 0:
		if slot_index < TalismanManager.equipped.size():
			TalismanManager.replace(_data, slot_index)
		else:
			TalismanManager.equip(_data)
	_play_collect_anim()

func _play_collect_anim() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite,  "scale",      Vector2.ZERO, 0.18).set_ease(Tween.EASE_IN)
	tw.tween_property(self,     "modulate:a", 0.0,          0.14)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
