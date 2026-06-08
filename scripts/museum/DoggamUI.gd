extends CanvasLayer
class_name DoggamUI
## 도감 팝업 — 유물·건물 카탈로그 열람

# ───────────────────────────────
#  전체 카탈로그 (게임에 존재하는 모든 항목)
# ───────────────────────────────
const ALL_ARTIFACT_PATHS: Array[String] = [
	"res://resources/artifacts/artifact_handaxe.tres",
	"res://resources/artifacts/artifact_tanged_tool.tres",
	"res://resources/artifacts/artifact_sword.tres",
	"res://resources/artifacts/artifact_semilunar_stone_knife.tres",
	"res://resources/artifacts/artifact_iron_arrow.tres",
	"res://resources/artifacts/artifact_hwandudaedo.tres",
	"res://resources/artifacts/artifact_mumun_pottery.tres",
	"res://resources/artifacts/monster_mask_roof_tile.tres",
	"res://resources/artifacts/white_porcelain_jar_cloud_dragon.tres",
]

const ALL_BLUEPRINT_PATHS: Array[String] = [
	"res://resources/buildables/museum_hq.tres",
	"res://resources/buildables/artifact_stand.tres",
	"res://resources/buildables/power_plant_Lv1.tres",
	"res://resources/buildables/power_tower.tres",
	"res://resources/buildables/hologram_fountain.tres",
	"res://resources/buildables/charging_station.tres",
	"res://resources/buildables/record_player.tres",
]

# 건설창에는 표시하지 않지만 도감에서는 항상 발견 상태인 건물
const ALWAYS_DISCOVERED_BLUEPRINTS: Array[String] = [
	"res://resources/buildables/museum_hq.tres",
]

enum Tab { ARTIFACT, ECHO, BUILDING }

@onready var _artifact_tab_btn: Button        = $Panel/VBox/TabHBox/ArtifactTabBtn
@onready var _echo_tab_btn:     Button        = $Panel/VBox/TabHBox/EchoTabBtn
@onready var _building_tab_btn: Button        = $Panel/VBox/TabHBox/BuildingTabBtn
@onready var _item_list:        ItemList      = $Panel/VBox/ContentHBox/LeftVBox/ItemScroll/ItemList
@onready var _detail_vbox:      VBoxContainer = $Panel/VBox/ContentHBox/RightVBox/DetailScroll/DetailVBox
@onready var _close_btn:        Button        = $Panel/VBox/TitleHBox/CloseButton

var _current_tab:  Tab            = Tab.ARTIFACT
var _index_to_path: Array[String] = []   # ItemList 인덱스 → 리소스 경로
var _font:          Font          = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_font = load("res://AutoLoad/assets/Font/DungGeunMo.ttf")
	_close_btn.pressed.connect(close)
	_artifact_tab_btn.pressed.connect(func(): _switch_tab(Tab.ARTIFACT))
	_echo_tab_btn.pressed.connect(func():     _switch_tab(Tab.ECHO))
	_building_tab_btn.pressed.connect(func(): _switch_tab(Tab.BUILDING))
	_item_list.item_selected.connect(_on_item_selected)

func open() -> void:
	_switch_tab(Tab.ARTIFACT)
	show()

func close() -> void:
	hide()

# ───────────────────────────────
#  탭 전환
# ───────────────────────────────
func _switch_tab(tab: Tab) -> void:
	_current_tab = tab
	_rebuild_list()
	_clear_detail()
	# 활성 탭: 연두 강조 / 비활성: 회색
	_artifact_tab_btn.modulate = Color(0.45, 1.0, 0.6) if tab == Tab.ARTIFACT else Color(0.7, 0.7, 0.7)
	_echo_tab_btn.modulate     = Color(0.45, 1.0, 0.6) if tab == Tab.ECHO     else Color(0.7, 0.7, 0.7)
	_building_tab_btn.modulate = Color(0.45, 1.0, 0.6) if tab == Tab.BUILDING else Color(0.7, 0.7, 0.7)

# ───────────────────────────────
#  목록 재구성
# ───────────────────────────────
func _rebuild_list() -> void:
	_item_list.clear()
	_index_to_path.clear()

	var paths: Array[String]
	match _current_tab:
		Tab.ARTIFACT: paths = ALL_ARTIFACT_PATHS
		Tab.ECHO:     paths = ALL_ARTIFACT_PATHS   # 동일 리소스, 에코 정보를 표시
		Tab.BUILDING: paths = ALL_BLUEPRINT_PATHS
		_:            paths = ALL_ARTIFACT_PATHS

	var idx := 1
	for path in paths:
		var discovered := _is_discovered(path)
		var label: String
		if discovered:
			var res := load(path)
			match _current_tab:
				Tab.ARTIFACT:
					label = "%d. %s" % [idx, (res as ArtifactData).artifact_name]
				Tab.ECHO:
					label = "%d. %s" % [idx, (res as ArtifactData).echo_name]
				Tab.BUILDING:
					label = "%d. %s" % [idx, (res as BuildableItem).item_name]
				_:
					label = "%d. ???" % idx
		else:
			label = "%d. ???" % idx
		_item_list.add_item(label)
		_index_to_path.append(path)
		idx += 1

func _is_discovered(path: String) -> bool:
	match _current_tab:
		Tab.ARTIFACT, Tab.ECHO:
			return path in GameManager.discovered_artifact_paths
		Tab.BUILDING:
			if path in ALWAYS_DISCOVERED_BLUEPRINTS:
				return true
			for bp: BuildableItem in GameManager.unlocked_blueprints:
				if (bp as Resource).resource_path == path:
					return true
			return false
	return false

# ───────────────────────────────
#  항목 선택 → 상세 패널 갱신
# ───────────────────────────────
func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _index_to_path.size():
		return
	var path       := _index_to_path[index]
	var discovered := _is_discovered(path)
	_build_detail(path, discovered)

func _build_detail(path: String, discovered: bool) -> void:
	_clear_detail()

	if not discovered:
		_add_label("???", 28, Color.WHITE, true)
		_add_spacer(8)
		_add_label("아직 발견하지 못한 항목입니다.", 15, Color(0.55, 0.55, 0.55))
		return

	var res := load(path)
	match _current_tab:
		Tab.ARTIFACT:
			if res is ArtifactData:
				_build_artifact_detail(res as ArtifactData)
		Tab.ECHO:
			if res is ArtifactData:
				_build_echo_detail(res as ArtifactData)
		Tab.BUILDING:
			if res is BuildableItem:
				_build_building_detail(res as BuildableItem)

# ───────────────────────────────
#  유물 상세
# ───────────────────────────────
func _build_artifact_detail(data: ArtifactData) -> void:
	# 이미지
	if data.texture:
		var img := TextureRect.new()
		img.texture              = data.texture
		img.custom_minimum_size  = Vector2(100, 100)
		img.stretch_mode         = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_detail_vbox.add_child(img)
		_add_spacer(4)

	_add_label(data.artifact_name, 20, Color.WHITE, true)
	_add_label("시대: %s" % ArtifactData.era_label(data.era), 14, Color(0.70, 0.85, 1.0))
	_add_separator()

	# 설명
	var desc := data.passive_description if data.passive_description != "" \
										 else data.description
	_add_label(desc, 13, Color(0.82, 0.82, 0.82))
	_add_separator()

	# 영력 생산
	_add_label("영력/초:  %.2f" % data.essence_per_second, 14, Color(0.9, 1.0, 0.55))

	# 욕구 감소율
	_add_label("안정도  -%.2f/초" % data.stability_decay, 13, Color(0.75, 0.75, 0.75))
	_add_label("출력    -%.2f/초" % data.output_decay,    13, Color(0.75, 0.75, 0.75))
	_add_label("활성도  -%.2f/초" % data.activity_decay,  13, Color(0.75, 0.75, 0.75))

	# 플레이어 보너스 최대치
	var has_bonus := (data.bonus_atk_max > 0 or data.bonus_atk_spd_max > 0
					or data.bonus_def_max > 0 or data.bonus_move_spd_max > 0.01
					or data.bonus_hp_max > 0)
	if has_bonus:
		_add_separator()
		_add_label("── 플레이어 보너스 (최대) ──", 13, Color(1.0, 0.85, 0.5))
		if data.bonus_atk_max > 0:
			_add_label("공격력     최대 +%d"        % data.bonus_atk_max,        14, Color(1.0, 0.72, 0.45))
		if data.bonus_atk_spd_max > 0:
			_add_label("공격속도   최대 +%d%%"      % data.bonus_atk_spd_max,    14, Color(1.0, 0.72, 0.45))
		if data.bonus_hp_max > 0:
			_add_label("체력       최대 +%d"        % data.bonus_hp_max,         14, Color(1.0, 0.72, 0.45))
		if data.bonus_def_max > 0:
			_add_label("방어력     최대 +%d"        % data.bonus_def_max,        14, Color(1.0, 0.72, 0.45))
		if data.bonus_move_spd_max > 0.01:
			_add_label("이동속도   최대 +%.1f"      % data.bonus_move_spd_max,   14, Color(1.0, 0.72, 0.45))

# ───────────────────────────────
#  에코 상세
# ───────────────────────────────
func _build_echo_detail(data: ArtifactData) -> void:
	# 에코 스프라이트 (float 애니메이션 첫 프레임)
	if data.echo_frames != null \
			and data.echo_frames.has_animation(&"float") \
			and data.echo_frames.get_frame_count(&"float") > 0:
		var img := TextureRect.new()
		img.texture               = data.echo_frames.get_frame_texture(&"float", 0)
		img.custom_minimum_size   = Vector2(96, 96)
		img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_detail_vbox.add_child(img)
		_add_spacer(4)

	_add_label(data.echo_name, 22, Color.WHITE, true)
	_add_separator()

	if data.echo_description != "":
		_add_label(data.echo_description, 13, Color(0.82, 0.82, 0.82))
		_add_separator()

	_add_label("깃든 유물: %s" % data.artifact_name,     14, Color(0.70, 0.85, 1.0))
	_add_label("시대:      %s" % ArtifactData.era_label(data.era), 14, Color(0.70, 0.85, 1.0))
	_add_label("에코 등급: %d" % data.echo_power,        14, Color(0.9,  1.0,  0.55))
	_add_label("배회 반경: %.0fpx" % data.wander_radius, 14, Color(0.75, 0.75, 0.75))

# ───────────────────────────────
#  건물 상세
# ───────────────────────────────
func _build_building_detail(item: BuildableItem) -> void:
	# 아이콘
	if item.icon:
		var img := TextureRect.new()
		img.texture               = item.icon
		img.custom_minimum_size   = Vector2(80, 80)
		img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_detail_vbox.add_child(img)
		_add_spacer(4)

	_add_label(item.item_name, 20, Color.WHITE, true)
	_add_separator()

	if item.description != "":
		_add_label(item.description, 13, Color(0.82, 0.82, 0.82))
		_add_separator()

	_add_label("건설 비용: %d 영력" % item.cost, 14, Color(0.9, 1.0, 0.55))

	if item.power_output > 0:
		_add_label("전력 공급:  +%d" % item.power_output, 14, Color(0.55, 1.0, 0.65))
	if item.power_consumption > 0:
		_add_label("전력 소비:  %d" % item.power_consumption, 14, Color(0.75, 0.85, 1.0))
	if item.stability_bonus > 0.0:
		_add_label("안정도 회복: %.2f/초" % item.stability_bonus, 14, Color(0.65, 1.0, 0.85))
	if item.output_bonus > 0.0:
		_add_label("출력 회복:  %.2f/초" % item.output_bonus,    14, Color(0.65, 1.0, 0.85))
	if item.activity_bonus > 0.0:
		_add_label("활성도 회복: %.2f/초" % item.activity_bonus, 14, Color(0.65, 1.0, 0.85))

# ───────────────────────────────
#  공통 헬퍼
# ───────────────────────────────
func _clear_detail() -> void:
	for child in _detail_vbox.get_children():
		child.queue_free()

func _add_label(text: String, size: int, color: Color,
				centered: bool = false) -> void:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.modulate             = color
	lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if centered:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_font(lbl, size)
	_detail_vbox.add_child(lbl)

func _add_separator() -> void:
	_detail_vbox.add_child(HSeparator.new())

func _add_spacer(height: int) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, height)
	_detail_vbox.add_child(sp)

func _set_font(node: Control, size: int) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
		node.add_theme_font_size_override("font_size", size)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			close()
