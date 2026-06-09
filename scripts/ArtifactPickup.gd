extends Area2D
class_name ArtifactPickup
## 던전 바닥에 드랍되는 유물 아이템
## 플레이어가 가까이 가면 자석처럼 끌려가 자동 획득

const FONT := preload("res://AutoLoad/assets/Font/DungGeunMo.ttf")

var _artifact_data: ArtifactData = null
var _collected:     bool         = false
var _attracting:    bool         = false
var _float_time:    float        = 0.0

# 코드로 생성
var _sprite:     Sprite2D
var _name_label: Label

# ────────────────────────────────────────
#  초기화 (add_child 전에 호출)
# ────────────────────────────────────────
func setup(data: ArtifactData) -> void:
	_artifact_data = data

func _ready() -> void:
	add_to_group("artifact_pickups")

	# ── 자식 노드 생성
	_build_nodes()

	# ── 충돌 영역
	var col  := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 40.0
	col.shape   = circ
	add_child(col)

	# ── 비주얼 적용
	if _artifact_data != null:
		_sprite.texture  = _artifact_data.texture
		_name_label.text = _artifact_data.artifact_name

	collision_layer = 0
	collision_mask  = 1   #플레이어 레이어만 감지

	body_entered.connect(_on_body_entered)

	# 스폰 직후 바운스 연출
	_sprite.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(1.1, 1.1), 0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_sprite, "scale", Vector2.ONE, 0.08) \
		.set_ease(Tween.EASE_IN)

# 포물선 착지 후 호출 — 흡인 활성화
func land() -> void:
	collision_mask = 1

func _build_nodes() -> void:
	# 아이템 스프라이트
	_sprite = Sprite2D.new()
	_sprite.scale = Vector2(0.65, 0.65)
	add_child(_sprite)

	# 이름 라벨 (폰트 크기 5)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position             = Vector2(-44, -30)
	_name_label.custom_minimum_size  = Vector2(88, 0)
	_name_label.add_theme_font_override("font",              FONT)
	_name_label.add_theme_font_size_override("font_size",    5)
	_name_label.add_theme_color_override("font_color",         Color.WHITE)
	_name_label.add_theme_color_override("font_shadow_color",  Color.BLACK)
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_name_label)

# ────────────────────────────────────────
#  프로세스
# ────────────────────────────────────────
func _process(delta: float) -> void:
	if _collected:
		return

	# Y-소팅
	z_as_relative = false
	z_index       = int(global_position.y) + 1

	# 아이콘 효과
	_float_time        += delta * 2.8
	_sprite.position.y  = sin(_float_time) * 4.0

	# 자석 흡인
	if _attracting:
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
#  획득
# ────────────────────────────────────────
func _collect() -> void:
	if _collected:
		return
	_collected = true

	GameManager.add_artifact(_artifact_data)

	# 수집 연출: 축소 + 페이드 후 free
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite,     "scale",      Vector2.ZERO, 0.14).set_ease(Tween.EASE_IN)
	tw.tween_property(_name_label, "modulate:a", 0.0,          0.10)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
