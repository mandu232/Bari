extends Area2D
class_name DungeonChest
## 모든 몬스터 처치 시 던전 중앙에 생성되는 보물 상자
## 플레이어가 근처에서 E 키를 누르면 열리고 유물 아이템을 드랍한다

const FONT := preload("res://AutoLoad/assets/Font/DungGeunMo.ttf")

const DROP_COUNT := 3

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

@onready var _sprite_closed: Sprite2D = $SpriteClosed
@onready var _sprite_open:   Sprite2D = $SpriteOpen

# ────────────────────────────────────────
#  READY
# ────────────────────────────────────────
func _ready() -> void:
	# 상호작용 힌트 라벨
	_hint_label = Label.new()
	_hint_label.text                  = "[ E ] 열기"
	_hint_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.position              = Vector2(-32, -44)
	_hint_label.custom_minimum_size   = Vector2(64, 0)
	_hint_label.add_theme_font_override("font",            FONT)
	_hint_label.add_theme_font_size_override("font_size", 11)
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
#  PROCESS — Z-소팅 + 두근거리는 스케일
# ────────────────────────────────────────
func _process(delta: float) -> void:
	z_as_relative = false
	z_index       = int(global_position.y)

	if not _is_open:
		_pulse_time += delta * 2.5
		var s := 1.0 + sin(_pulse_time) * 0.04
		scale = Vector2(s, s)

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
		_player_nearby      = true
		_hint_label.visible = not _is_open

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

	# 스프라이트 교체
	_sprite_closed.visible = false
	_sprite_open.visible   = true

	# 열리는 충격 연출
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.15, 0.85), 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(0.90, 1.10), 0.08).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "scale", Vector2.ONE,          0.10).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_spawn_artifacts)

# ────────────────────────────────────────
#  아이템 스폰
# ────────────────────────────────────────
func _spawn_artifacts() -> void:
	var pool  := ARTIFACT_POOL.duplicate()
	pool.shuffle()
	var count := mini(DROP_COUNT, pool.size())

	for i in count:
		var res := load(pool[i]) as ArtifactData
		if res == null:
			continue

		var pickup := ArtifactPickup.new()
		pickup.setup(res)
		get_parent().add_child(pickup)

		var angle := (float(i) / float(count)) * TAU - PI * 0.5
		var dist  := randf_range(44.0, 60.0)
		pickup.global_position = global_position + Vector2(cos(angle), sin(angle)) * dist

		pickup.modulate.a = 0.0
		var dt := create_tween()
		dt.tween_interval(i * 0.12)
		dt.tween_property(pickup, "modulate:a", 1.0, 0.18)
