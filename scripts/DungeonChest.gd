extends Area2D
class_name DungeonChest
## 모든 몬스터 처치 시 던전 중앙에 생성되는 보물 상자
## 플레이어가 근처에서 E 키를 누르면 열리고 유물 아이템을 드랍한다

const FONT := preload("res://AutoLoad/assets/Font/DungGeunMo.ttf")

# ── 드랍 수
const DROP_COUNT := 3

# ── 유물 풀 (던전 드랍 후보)
const ARTIFACT_POOL: Array[String] = [
	"res://resources/artifacts/artifact_sword.tres",
	"res://resources/artifacts/artifact_handaxe.tres",
	"res://resources/artifacts/artifact_tanged_tool.tres",
	"res://resources/artifacts/artifact_semilunar_stone_knife.tres",
	"res://resources/artifacts/artifact_iron_arrow.tres",
	"res://resources/artifacts/artifact_hwandudaedo.tres",
	"res://resources/artifacts/artifact_mumun_pottery.tres",
	"res://resources/artifacts/monster_mask_roof_tile.tres",
	"res://resources/artifacts/white_porcelain_jar_cloud_dragon.tres",
]

var _is_open:       bool  = false
var _player_nearby: bool  = false
var _hint_label:    Label
var _pulse_time:    float = 0.0

# ────────────────────────────────────────
#  READY
# ────────────────────────────────────────
func _ready() -> void:
	# 상호작용 감지 영역
	var col  := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 48.0
	col.shape   = circ
	add_child(col)

	collision_layer = 0
	collision_mask  = 1   # Player 레이어

	# 상호작용 힌트 라벨
	_hint_label = Label.new()
	_hint_label.text                  = "[ E ] 열기"
	_hint_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.position              = Vector2(-32, -44)
	_hint_label.custom_minimum_size   = Vector2(64, 0)
	_hint_label.add_theme_font_override("font",             FONT)
	_hint_label.add_theme_font_size_override("font_size",  11)
	_hint_label.add_theme_color_override("font_color",         Color(1.0, 0.95, 0.5))
	_hint_label.add_theme_color_override("font_shadow_color",  Color.BLACK)
	_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	_hint_label.visible = false
	add_child(_hint_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	set_process(true)

# ────────────────────────────────────────
#  Y-소팅 + 두근거리는 효果
# ────────────────────────────────────────
func _process(delta: float) -> void:
	z_as_relative = false
	z_index       = int(global_position.y)

	if not _is_open:
		_pulse_time   += delta * 2.5
		var s          := 1.0 + sin(_pulse_time) * 0.04
		scale          = Vector2(s, s)
		queue_redraw()

# ────────────────────────────────────────
#  비주얼 — _draw() 로 상자 묘사
# ────────────────────────────────────────
func _draw() -> void:
	if _is_open:
		_draw_open_chest()
	else:
		_draw_closed_chest()

func _draw_closed_chest() -> void:
	# 그림자 (Godot 4 내장 draw_ellipse: center, x_radius, y_radius, color)
	draw_ellipse(Vector2(0, 10), 20.0, 5.0, Color(0, 0, 0, 0.25))

	# 뚜껑 (위)
	var lid_col := Color(0.72, 0.48, 0.18)
	draw_rect(Rect2(-18, -26, 36, 14), lid_col)
	# 뚜껑 테두리
	draw_rect(Rect2(-18, -26, 36, 14), Color(0.25, 0.12, 0.04), false, 1.8)

	# 몸통 (아래)
	var body_col := Color(0.55, 0.34, 0.12)
	draw_rect(Rect2(-18, -13, 36, 20), body_col)
	draw_rect(Rect2(-18, -13, 36, 20), Color(0.25, 0.12, 0.04), false, 1.8)

	# 가로 금속 띠
	var band_col := Color(0.6, 0.5, 0.15)
	draw_rect(Rect2(-18, -15, 36, 4), band_col)
	draw_rect(Rect2(-18, -15, 36, 4), Color(0.3, 0.2, 0.04), false, 1.0)

	# 자물쇠 (원형)
	draw_circle(Vector2(0, -13),  5.5, Color(0.85, 0.70, 0.12))
	draw_circle(Vector2(0, -13),  5.5, Color(0.25, 0.12, 0.04), false, 1.2)
	draw_circle(Vector2(0, -13),  2.5, Color(0.45, 0.35, 0.06))

	# 뚜껑 하이라이트
	draw_line(Vector2(-16, -25), Vector2(16, -25), Color(1.0, 0.85, 0.5, 0.5), 1.5)

func _draw_open_chest() -> void:
	# 그림자
	draw_ellipse(Vector2(0, 10), 20.0, 5.0, Color(0, 0, 0, 0.18))

	# 열린 내부 (어두운 속)
	draw_rect(Rect2(-18, -13, 36, 20), Color(0.18, 0.09, 0.03))
	draw_rect(Rect2(-15, -10, 30, 14), Color(0.08, 0.04, 0.01))

	# 몸통 테두리만
	draw_rect(Rect2(-18, -13, 36, 20), Color(0.25, 0.12, 0.04), false, 1.8)

	# 뒤로 젖혀진 뚜껑 (위쪽에 얇게)
	draw_rect(Rect2(-18, -32, 36, 10), Color(0.50, 0.30, 0.10))
	draw_rect(Rect2(-18, -32, 36, 10), Color(0.25, 0.12, 0.04), false, 1.5)

# ────────────────────────────────────────
#  입력 (E키)
# ────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or _is_open:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.keycode == KEY_E and ke.pressed and not ke.echo:
			get_viewport().set_input_as_handled()
			_open_chest()

# ────────────────────────────────────────
#  플레이어 근접 감지
# ────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby          = true
		_hint_label.visible     = not _is_open

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_nearby      = false
		_hint_label.visible = false

# ────────────────────────────────────────
#  상자 열기
# ────────────────────────────────────────
func _open_chest() -> void:
	_is_open            = true
	_hint_label.visible = false
	scale               = Vector2.ONE

	# 열리는 충격 연출: 살짝 튀어 오름
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.15, 0.85), 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(0.90, 1.10), 0.08).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "scale", Vector2.ONE,          0.10).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_spawn_artifacts)

# ────────────────────────────────────────
#  아이템 스폰
# ────────────────────────────────────────
func _spawn_artifacts() -> void:
	queue_redraw()   # 열린 비주얼로 갱신

	var pool  := ARTIFACT_POOL.duplicate()
	pool.shuffle()
	var count := mini(DROP_COUNT, pool.size())

	for i in count:
		var res := load(pool[i]) as ArtifactData
		if res == null:
			continue

		var pickup := ArtifactPickup.new()
		pickup.setup(res)   # add_child 전에 데이터 주입 (ready에서 visuals 적용)
		get_parent().add_child(pickup)

		# 부채꼴 형태로 배치, 약간의 랜덤 오프셋
		var angle := (float(i) / float(count)) * TAU - PI * 0.5
		var dist  := randf_range(44.0, 60.0)
		pickup.global_position = global_position + Vector2(cos(angle), sin(angle)) * dist

		# 약간의 딜레이로 순차 등장
		pickup.modulate.a = 0.0
		var dt := create_tween()
		dt.tween_interval(i * 0.12)
		dt.tween_property(pickup, "modulate:a", 1.0, 0.18)
