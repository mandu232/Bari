extends CanvasLayer
class_name MenuUI
## 통합 메뉴 패널
## 왼쪽: 탭 버튼(스탯·인벤토리·도감)  오른쪽: 선택한 탭의 콘텐츠
## ESC 또는 오버레이 클릭으로 닫기

# museum.gd 호환용 시그널 — 현재 버전에서는 발신하지 않음
signal stats_requested
signal doggam_requested
signal inventory_requested

# ───────────────────────────────
#  도감 카탈로그 경로 (DoggamUI 에서 이관)
# ───────────────────────────────
const ALL_ARTIFACT_PATHS: Array[String] = [
	"res://resources/artifacts/artifact_handaxe.tres",
	"res://resources/artifacts/artifact_tanged_tool.tres",
	"res://resources/artifacts/artifact_sword.tres",
	"res://resources/artifacts/artifact_semilunar_stone_knife.tres",
	"res://resources/artifacts/artifact_hwandudaedo.tres",
	"res://resources/artifacts/artifact_mumun_pottery.tres",
	"res://resources/artifacts/monster_mask_roof_tile.tres",
	"res://resources/artifacts/white_porcelain_jar_cloud_dragon.tres",
	"res://resources/artifacts/artifact_iron_arrow.tres",
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
const ALWAYS_DISCOVERED_BLUEPRINTS: Array[String] = [
	"res://resources/buildables/museum_hq.tres",
]

# ───────────────────────────────
#  STATE
# ───────────────────────────────
enum Tab       { STATS, INVENTORY, ENHANCE, DOGGAM, SKILL }
enum DoggamTab { ARTIFACT, ECHO, BUILDING }

var _font: Font = null
var _current_tab:       Tab       = Tab.STATS
var _current_doggam_tab: DoggamTab = DoggamTab.ARTIFACT

# ── 레이아웃 노드 참조
var _content_vbox: VBoxContainer = null   # 오른쪽 콘텐츠 영역
var _tab_btns:     Array[Button] = []     # 왼쪽 탭 버튼 [Stats, Inv, Doggam]

# ── 인벤토리 상태
var _inv_artifacts:      Array         = []
var _inv_item_list:      ItemList      = null   # 미사용 (호환용)
var _inv_detail_vbox:    VBoxContainer = null
var _inv_grid_buttons:   Array         = []
var _inv_selected_index: int           = -1

# ── 강화 탭 상태
const ENHANCE_COST_PER_LEVEL: int = 100   # 레벨당 영력 기본 비용
var _enh_artifacts:    Array         = []   # 인벤토리 스냅샷
var _enh_target:       ArtifactData  = null
var _enh_material:     ArtifactData  = null
var _enh_target_idx:   int           = -1
var _enh_material_idx: int           = -1
var _enh_target_btns:  Array         = []
var _enh_mat_btns:     Array         = []
var _enh_mat_vbox:     VBoxContainer = null   # 재료 목록 컨테이너
var _enh_preview_vbox: VBoxContainer = null   # 미리보기 컨테이너
var _enh_mode:         int           = 0      # 0=메인, 1=대상선택, 2=재료선택

# ── 강화 피커 선택 상태 (피커 화면에서만 사용)
var _enh_picker_selected:    ArtifactData  = null   # 피커에서 하이라이트된 유물
var _enh_picker_cell_btns:   Array         = []     # 피커 그리드 셀 버튼 목록
var _enh_picker_detail_vbox: VBoxContainer = null   # 피커 우측 상세 패널
var _enh_picker_select_btn:  Button        = null   # 피커 선택 확정 버튼

# ── 스탯 탭 — 시너지 선택 상태
var _syn_detail_vbox:  VBoxContainer = null
var _syn_era_btns:     Array         = []   # [{btn, era_int}]
var _syn_selected_era: int           = -1

# ── 도감 상태
var _dog_index_to_path: Array[String] = []
var _dog_item_list:     ItemList      = null
var _dog_detail_vbox:   VBoxContainer = null
var _dog_sub_btns:      Array[Button] = []

# ───────────────────────────────
#  READY
# ───────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 10
	_font = load("res://AutoLoad/assets/Font/DungGeunMo.ttf")
	_build_layout()
	hide()

func open() -> void:
	_switch_tab(_current_tab)
	show()

func close() -> void:
	hide()

# ───────────────────────────────
#  레이아웃 빌드
# ───────────────────────────────
func _build_layout() -> void:
	# 반투명 오버레이 (클릭하면 닫기)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color        = Color(0, 0, 0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_overlay_input)
	add_child(overlay)

	# 메인 패널 (960 × 590)
	var panel := Panel.new()
	panel.offset_left   = 160.0
	panel.offset_top    = 65.0
	panel.offset_right  = 1120.0
	panel.offset_bottom = 655.0
	add_child(panel)

	# 패널 루트 HBox (왼쪽 탭 | 오른쪽 콘텐츠)
	var root_hbox := HBoxContainer.new()
	root_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_hbox.add_theme_constant_override("separation", 0)
	panel.add_child(root_hbox)

	# ── 왼쪽 사이드바
	var left_bg := PanelContainer.new()
	left_bg.custom_minimum_size = Vector2(175, 0)
	root_hbox.add_child(left_bg)

	var left_margin := MarginContainer.new()
	left_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_margin.add_theme_constant_override("margin_left",   12)
	left_margin.add_theme_constant_override("margin_right",  12)
	left_margin.add_theme_constant_override("margin_top",    16)
	left_margin.add_theme_constant_override("margin_bottom", 16)
	left_bg.add_child(left_margin)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_margin.add_child(left_vbox)

	var title_lbl := Label.new()
	title_lbl.text                = "메뉴"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_font(title_lbl, 21)
	left_vbox.add_child(title_lbl)
	left_vbox.add_child(HSeparator.new())

	# 탭 버튼
	var tab_labels := ["스탯", "인벤토리", "강화", "도감", "스킬"]
	_tab_btns.clear()
	for i in tab_labels.size():
		var btn := Button.new()
		btn.text                = tab_labels[i]
		btn.custom_minimum_size = Vector2(0, 50)
		btn.focus_mode          = Control.FOCUS_NONE
		var t := i as Tab
		btn.pressed.connect(func(): _switch_tab(t))
		_set_font(btn, 17)
		left_vbox.add_child(btn)
		_tab_btns.append(btn)

	# ── 세로 구분선
	root_hbox.add_child(VSeparator.new())

	# ── 오른쪽 콘텐츠 마진
	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left",   16)
	right_margin.add_theme_constant_override("margin_right",  16)
	right_margin.add_theme_constant_override("margin_top",    14)
	right_margin.add_theme_constant_override("margin_bottom", 14)
	root_hbox.add_child(right_margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 8)
	right_margin.add_child(_content_vbox)

# ───────────────────────────────
#  탭 전환
# ───────────────────────────────
func _switch_tab(tab: Tab) -> void:
	_current_tab = tab

	# 탭 버튼 색상 갱신
	for i in _tab_btns.size():
		_tab_btns[i].modulate = \
			Color(0.45, 1.0, 0.6) if i == int(tab) else Color(0.82, 0.82, 0.82)

	# 콘텐츠 초기화 + 참조 무효화
	# remove_child 로 즉시 트리에서 분리 후 queue_free — 같은 프레임 내 레이아웃 충돌 방지
	for child in _content_vbox.get_children():
		_content_vbox.remove_child(child)
		child.queue_free()
	_inv_item_list      = null
	_inv_detail_vbox    = null
	_inv_grid_buttons.clear()
	_inv_selected_index = -1
	_dog_item_list      = null
	_dog_detail_vbox    = null
	_dog_sub_btns.clear()
	_enh_target         = null
	_enh_material       = null
	_enh_target_idx     = -1
	_enh_material_idx   = -1
	_enh_target_btns.clear()
	_enh_mat_btns.clear()
	_enh_mat_vbox       = null
	_enh_preview_vbox   = null
	_enh_mode           = 0
	_enh_picker_selected    = null
	_enh_picker_cell_btns.clear()
	_enh_picker_detail_vbox = null
	_enh_picker_select_btn  = null
	_syn_detail_vbox  = null
	_syn_era_btns.clear()
	_syn_selected_era = -1

	match tab:
		Tab.STATS:     _build_stats_content()
		Tab.INVENTORY: _build_inventory_content()
		Tab.DOGGAM:    _build_doggam_content()
		Tab.ENHANCE:   _build_enhance_content()
		Tab.SKILL:     _build_skill_content()

# ═══════════════════════════════
#  ① 스탯 콘텐츠
# ═══════════════════════════════
func _build_stats_content() -> void:
	_add_section_title(_content_vbox, "플레이어 스탯")

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_add_to(_content_vbox, "플레이어를 찾을 수 없습니다", 15, Color(0.6, 0.6, 0.6))
		return

	const ICONS := {
		"atk":     "res://AutoLoad/assets/Stats/icon_atk.png",
		"atk_spd": "res://AutoLoad/assets/Stats/icon_atk_spd.png",
		"def":     "res://AutoLoad/assets/Stats/icon_def.png",
		"spd":     "res://AutoLoad/assets/Stats/icon_move_spd.png",
		"hp":      "res://AutoLoad/assets/Stats/icon_hp.png",
	}

	var rows := [
		["atk",     "공격력",   "%d"       % player.get("attack_damage")],
		["atk_spd", "공격속도", "%d%%"     % player.get("attack_speed")],
		["hp",      "체력",     "%d / %d"  % [player.get("health"), player.get("max_health")]],
		["def",     "방어력",   "%d"       % player.get("defense")],
		["spd",     "이동속도", "%.1f"     % player.get("move_speed")],
	]

	for row in rows:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		_content_vbox.add_child(hbox)

		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(28, 28)
		tex.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var icon_path: String = ICONS.get(row[0], "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			tex.texture = load(icon_path)
		hbox.add_child(tex)

		var name_lbl := Label.new()
		name_lbl.text                = row[1]
		name_lbl.custom_minimum_size = Vector2(90, 0)
		_set_font(name_lbl, 18)
		hbox.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text     = row[2]
		val_lbl.modulate = Color(0.85, 1.0, 0.65)
		_set_font(val_lbl, 18)
		hbox.add_child(val_lbl)

	# ── 시대 시너지 섹션 (버튼 + 우측 상세)
	_content_vbox.add_child(HSeparator.new())
	_add_section_title(_content_vbox, "시대 시너지")
	_build_synergy_section()

## 시너지 섹션: 왼쪽 버튼 목록 | 오른쪽 상세 패널
func _build_synergy_section() -> void:
	const ERA_ORDER: Array[int] = [1, 3, 5, 8]

	var syn_hbox := HBoxContainer.new()
	syn_hbox.add_theme_constant_override("separation", 0)
	syn_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(syn_hbox)

	# ── 왼쪽: 시너지 버튼 목록
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(128, 0)
	left_vbox.add_theme_constant_override("separation", 5)
	syn_hbox.add_child(left_vbox)

	syn_hbox.add_child(VSeparator.new())

	# ── 오른쪽: 상세 패널 (스크롤)
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	syn_hbox.add_child(right_scroll)

	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left",  12)
	right_margin.add_theme_constant_override("margin_right",  8)
	right_margin.add_theme_constant_override("margin_top",    4)
	right_scroll.add_child(right_margin)

	_syn_detail_vbox = VBoxContainer.new()
	_syn_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_syn_detail_vbox.add_theme_constant_override("separation", 8)
	right_margin.add_child(_syn_detail_vbox)
	_add_to(_syn_detail_vbox, "좌측 시너지를 눌러\n효과를 확인하세요", 13, Color(0.38, 0.38, 0.38))

	# ── 버튼 생성
	_syn_era_btns.clear()
	for era_int in ERA_ORDER:
		var tiers: Array = GameManager.ERA_SYNERGY_TIERS.get(era_int, [])
		if tiers.is_empty(): continue

		var current_count := GameManager.get_exhibited_era_count(era_int)
		var is_active: bool = not (GameManager.active_synergies.get(era_int, {}) as Dictionary).is_empty()

		# 분모: 다음 미달성 티어 임계값, 이미 최대면 최대
		var show_denom: int = (tiers[-1] as Dictionary)["count"] as int
		for tier in tiers:
			if current_count < (tier["count"] as int):
				show_denom = tier["count"] as int
				break

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.focus_mode          = Control.FOCUS_NONE
		# 활성 → 금빛, 비활성 → 어두운 회색
		btn.modulate = Color(0.95, 0.82, 0.32) if is_active else Color(0.40, 0.40, 0.40)

		var bv := VBoxContainer.new()
		bv.alignment  = BoxContainer.ALIGNMENT_CENTER
		bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bv)

		var nl := Label.new()
		nl.text                = ArtifactData.era_label(era_int as ArtifactData.Era)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		_set_font(nl, 15)
		bv.add_child(nl)

		var cl := Label.new()
		cl.text                = "%d / %d" % [current_count, show_denom]
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		cl.modulate = Color(1.0, 0.95, 0.6) if is_active else Color(0.48, 0.48, 0.48)
		_set_font(cl, 13)
		bv.add_child(cl)

		var era_capture := era_int
		btn.pressed.connect(func(): _on_syn_btn_pressed(era_capture))
		left_vbox.add_child(btn)
		_syn_era_btns.append({"btn": btn, "era": era_int})

## 시너지 버튼 클릭 처리
func _on_syn_btn_pressed(era_int: int) -> void:
	_syn_selected_era = era_int
	# 버튼 하이라이트 갱신
	for entry in _syn_era_btns:
		var b   := entry["btn"] as Button
		var e   := entry["era"] as int
		var act: bool = not (GameManager.active_synergies.get(e, {}) as Dictionary).is_empty()
		if e == era_int:
			b.modulate = Color(1.0, 1.0, 1.0)          # 선택됨 — 흰색
		elif act:
			b.modulate = Color(0.95, 0.82, 0.32)        # 활성 미선택
		else:
			b.modulate = Color(0.40, 0.40, 0.40)        # 비활성 미선택
	_rebuild_syn_detail(era_int)

## 우측 상세 패널 갱신
func _rebuild_syn_detail(era_int: int) -> void:
	if _syn_detail_vbox == null: return
	for c in _syn_detail_vbox.get_children():
		_syn_detail_vbox.remove_child(c)
		c.queue_free()

	var tiers:         Array  = GameManager.ERA_SYNERGY_TIERS.get(era_int, [])
	var current_count: int    = GameManager.get_exhibited_era_count(era_int)
	var era_name:      String = ArtifactData.era_label(era_int as ArtifactData.Era)

	# 헤더
	var hdr := Label.new()
	hdr.text    = "%s 시대   (%d개 전시 중)" % [era_name, current_count]
	hdr.modulate = Color(0.85, 0.85, 0.85)
	_set_font(hdr, 15)
	_syn_detail_vbox.add_child(hdr)
	_syn_detail_vbox.add_child(HSeparator.new())

	# 각 티어 표시
	for i in tiers.size():
		var tier      := tiers[i] as Dictionary
		var tc        := tier["count"] as int
		var tier_act  := current_count >= tc
		var is_last   := i == tiers.size() - 1

		# 티어 제목 행
		var title_hbox := HBoxContainer.new()
		title_hbox.add_theme_constant_override("separation", 8)
		_syn_detail_vbox.add_child(title_hbox)

		var icon_lbl := Label.new()
		icon_lbl.text    = "✦" if tier_act else "○"
		icon_lbl.modulate = Color(1.0, 0.85, 0.3) if tier_act else Color(0.35, 0.35, 0.35)
		_set_font(icon_lbl, 16)
		title_hbox.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text                = "%s" % tier["name"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.modulate            = Color(1.0, 0.92, 0.45) if tier_act else Color(0.38, 0.38, 0.38)
		_set_font(name_lbl, 15)
		title_hbox.add_child(name_lbl)

		var req_lbl := Label.new()
		req_lbl.text    = "%d개" % tc
		req_lbl.modulate = Color(0.7, 0.7, 0.7) if tier_act else Color(0.35, 0.35, 0.35)
		_set_font(req_lbl, 13)
		title_hbox.add_child(req_lbl)

		# 효과 설명
		var desc_lbl := Label.new()
		desc_lbl.text          = "    " + tier["desc"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.modulate      = Color(1.0, 0.72, 0.45) if tier_act else Color(0.30, 0.30, 0.30)
		_set_font(desc_lbl, 13)
		_syn_detail_vbox.add_child(desc_lbl)

		# 달성 상태 메시지
		var status_lbl := Label.new()
		if tier_act:
			status_lbl.text    = "    ✓ 달성"
			status_lbl.modulate = Color(0.45, 1.0, 0.6)
		else:
			status_lbl.text    = "    전시 %d개 더 필요" % (tc - current_count)
			status_lbl.modulate = Color(0.42, 0.42, 0.42)
		_set_font(status_lbl, 12)
		_syn_detail_vbox.add_child(status_lbl)

		if not is_last:
			_syn_detail_vbox.add_child(HSeparator.new())

# ═══════════════════════════════
#  ② 인벤토리 콘텐츠
# ═══════════════════════════════
const INV_COLS:      int = 4     # 한 줄에 표시할 아이템 수
const INV_CELL_SIZE: int = 72    # 셀 한 변 크기 (px)
const INV_CELL_GAP:  int = 4     # 셀 간격 (px)

func _build_inventory_content() -> void:
	_inv_artifacts = GameManager.artifacts.duplicate()
	_inv_grid_buttons.clear()
	_inv_selected_index = -1

	# ── 타이틀 + 개수
	var hdr := HBoxContainer.new()
	_content_vbox.add_child(hdr)

	var t := Label.new()
	t.text                  = "인벤토리"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_font(t, 20)
	hdr.add_child(t)

	var cnt := Label.new()
	cnt.text     = "보유 유물: %d개" % _inv_artifacts.size()
	cnt.modulate = Color(0.72, 0.72, 0.72)
	_set_font(cnt, 14)
	hdr.add_child(cnt)

	_content_vbox.add_child(HSeparator.new())

	# ── 본문: 그리드(왼쪽) | 구분선 | 상세(오른쪽)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(body)

	# 왼쪽 그리드 영역
	var grid_scroll := ScrollContainer.new()
	# 4열 × 셀크기 + 3칸 간격 + 좌우 여백 8
	var grid_w := INV_COLS * INV_CELL_SIZE + (INV_COLS - 1) * INV_CELL_GAP + 8
	grid_scroll.custom_minimum_size    = Vector2(grid_w, 0)
	grid_scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(grid_scroll)

	var grid_margin := MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_left",  4)
	grid_margin.add_theme_constant_override("margin_right", 4)
	grid_margin.add_theme_constant_override("margin_top",   4)
	grid_scroll.add_child(grid_margin)

	var grid := GridContainer.new()
	grid.columns = INV_COLS
	grid.add_theme_constant_override("h_separation", INV_CELL_GAP)
	grid.add_theme_constant_override("v_separation", INV_CELL_GAP)
	grid_margin.add_child(grid)

	if _inv_artifacts.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "보유한 유물이 없습니다"
		empty_lbl.modulate = Color(0.5, 0.5, 0.5)
		_set_font(empty_lbl, 14)
		grid.add_child(empty_lbl)
	else:
		for i in _inv_artifacts.size():
			var data := _inv_artifacts[i] as ArtifactData
			if data == null: continue
			var cell := _make_inv_cell(data, i)
			grid.add_child(cell)
			_inv_grid_buttons.append(cell)

	body.add_child(VSeparator.new())

	# 오른쪽 상세 (fill)
	var ds := ScrollContainer.new()
	ds.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	ds.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(ds)

	_inv_detail_vbox = VBoxContainer.new()
	_inv_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_detail_vbox.add_theme_constant_override("separation", 6)
	ds.add_child(_inv_detail_vbox)

	_add_to(_inv_detail_vbox, "유물을 선택하세요", 14, Color(0.5, 0.5, 0.5))

## 정사각형 아이콘 셀 생성 (이름 없이 아이콘만, 강화 레벨 오버레이)
func _make_inv_cell(data: ArtifactData, index: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(INV_CELL_SIZE, INV_CELL_SIZE)
	btn.focus_mode          = Control.FOCUS_NONE
	btn.text                = ""
	btn.expand_icon         = true
	btn.icon                = data.texture
	btn.pressed.connect(func(): _on_inv_grid_pressed(index))

	# 강화 레벨 오버레이 (+N, 우하단)
	if data.enhance_level > 0:
		var lbl := Label.new()
		lbl.text                 = "+%d" % data.enhance_level
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.offset_right  = -4.0
		lbl.offset_bottom = -2.0
		lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		lbl.modulate      = Color(1.0, 0.85, 0.3)   # 금색
		_set_font(lbl, 12)
		btn.add_child(lbl)

	return btn

func _on_inv_grid_pressed(index: int) -> void:
	if _inv_detail_vbox == null: return
	if index < 0 or index >= _inv_artifacts.size(): return

	# 이전 선택 해제
	if _inv_selected_index >= 0 and _inv_selected_index < _inv_grid_buttons.size():
		_inv_grid_buttons[_inv_selected_index].modulate = Color.WHITE
	# 새 선택 강조
	_inv_selected_index = index
	_inv_grid_buttons[index].modulate = Color(0.45, 1.0, 0.6)

	_build_inv_detail(_inv_artifacts[index] as ArtifactData)

func _on_inv_item_selected(index: int) -> void:
	_on_inv_grid_pressed(index)  # 호환용

# ═══════════════════════════════
#  ④ 강화 탭 콘텐츠
#  _enh_mode: 0=메인, 1=강화 대상 선택, 2=재료 선택
# ═══════════════════════════════
func _build_enhance_content() -> void:
	_enh_artifacts = GameManager.artifacts.duplicate()
	if _enh_mode == 0:
		_enh_show_main()
	else:
		_enh_show_picker()

# ── 메인 화면 (두 슬롯 + 스탯 비교 + 강화 버튼)
func _enh_show_main() -> void:

	# ── 제목
	_add_section_title(_content_vbox, "합성 강화")

	# ── 슬롯 영역 (두 개의 네모 박스, 가운데 정렬)
	var slots_hbox := HBoxContainer.new()
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hbox.add_theme_constant_override("separation", 40)
	_content_vbox.add_child(slots_hbox)

	slots_hbox.add_child(_make_enh_slot_box("강화할 유물", _enh_target, func(): _enh_open_picker(1)))
	slots_hbox.add_child(_make_enh_slot_box("재료 유물",   _enh_material, func(): _enh_open_picker(2)))

	_content_vbox.add_child(HSeparator.new())

	# ── 스탯 비교 영역 (fill)
	_enh_preview_vbox = VBoxContainer.new()
	_enh_preview_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enh_preview_vbox.add_theme_constant_override("separation", 6)
	_content_vbox.add_child(_enh_preview_vbox)
	_enh_refresh_stats_view()

	# ── 하단 강화 버튼 (중앙 정렬)
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_vbox.add_child(btn_hbox)

	var cur_lv := _enh_target.enhance_level if _enh_target != null else 0
	var cost   := (cur_lv + 1) * ENHANCE_COST_PER_LEVEL
	var can    := _enh_target != null and _enh_material != null \
				  and _enh_target.enhance_level < ArtifactData.MAX_ENHANCE_LEVEL \
				  and GameManager.echo_essence >= cost

	var enh_btn := Button.new()
	enh_btn.custom_minimum_size = Vector2(220, 54)
	enh_btn.focus_mode          = Control.FOCUS_NONE
	enh_btn.disabled            = not can
	if can:
		enh_btn.text     = "강화하기  (영력 %d)" % cost
		enh_btn.modulate = Color(0.5, 1.0, 0.6)
	elif _enh_target == null:
		enh_btn.text = "강화할 유물을 선택하세요"
	elif _enh_material == null:
		enh_btn.text = "재료 유물을 선택하세요"
	elif _enh_target.enhance_level >= ArtifactData.MAX_ENHANCE_LEVEL:
		enh_btn.text = "✦ 최대 강화 달성"
	else:
		enh_btn.text     = "영력 부족  (필요: %d)" % cost
		enh_btn.modulate = Color(1.0, 0.5, 0.5)
	enh_btn.pressed.connect(_do_enhance_action)
	_set_font(enh_btn, 17)
	btn_hbox.add_child(enh_btn)

## 슬롯 박스 생성 — 비어있으면 "클릭하여 선택", 채워지면 유물 정보 표시
func _make_enh_slot_box(title: String, data: ArtifactData, callback: Callable) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(220, 190)
	btn.focus_mode          = Control.FOCUS_NONE
	btn.pressed.connect(callback)

	var vbox := VBoxContainer.new()
	vbox.alignment   = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	# 제목 라벨
	var t := Label.new()
	t.text                = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	t.modulate            = Color(0.75, 0.75, 0.75)
	_set_font(t, 13)
	vbox.add_child(t)

	vbox.add_child(_make_mouse_ignore_sep())

	if data == null:
		# 빈 슬롯
		var ph := Label.new()
		ph.text                = "클릭하여 선택"
		ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ph.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		ph.modulate            = Color(0.55, 0.55, 0.55)
		_set_font(ph, 14)
		vbox.add_child(ph)
	else:
		# 유물 아이콘
		if data.texture:
			var img := TextureRect.new()
			img.texture               = data.texture
			img.custom_minimum_size   = Vector2(80, 80)
			img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			img.mouse_filter          = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(img)

		var name_lbl := Label.new()
		name_lbl.text                = data.artifact_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		_set_font(name_lbl, 14)
		vbox.add_child(name_lbl)

		var lv_lbl := Label.new()
		lv_lbl.text                = "Lv.%d" % data.enhance_level
		lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv_lbl.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		lv_lbl.modulate            = Color(1.0, 0.85, 0.3)
		_set_font(lv_lbl, 13)
		vbox.add_child(lv_lbl)

	return btn

## mouse_filter=IGNORE 인 HSeparator 헬퍼
func _make_mouse_ignore_sep() -> Control:
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep

# ── 유물 선택 피커 화면 (뒤로가기 | 왼쪽 그리드 | 오른쪽 상세+선택버튼)
func _enh_show_picker() -> void:
	_enh_picker_selected = null
	_enh_picker_cell_btns.clear()

	# ── 상단: 뒤로가기 + 제목
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	_content_vbox.add_child(top_hbox)

	var back_btn := Button.new()
	back_btn.text       = "← 뒤로"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(func():
		_enh_mode = 0
		_rebuild_enhance())
	_set_font(back_btn, 14)
	top_hbox.add_child(back_btn)

	var picker_title := Label.new()
	picker_title.text = "강화할 유물 선택" if _enh_mode == 1 else "재료 유물 선택"
	picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_title.modulate = Color(0.9, 0.9, 0.9)
	_set_font(picker_title, 16)
	top_hbox.add_child(picker_title)

	_content_vbox.add_child(HSeparator.new())

	# ── 선택 가능 후보 필터링
	var candidates: Array = []
	for i in _enh_artifacts.size():
		var a := _enh_artifacts[i] as ArtifactData
		if a == null: continue
		if _enh_mode == 1:
			candidates.append({"data": a, "index": i})
		elif _enh_mode == 2 and _enh_target != null:
			if a != _enh_target and a.artifact_name == _enh_target.artifact_name:
				candidates.append({"data": a, "index": i})

	if candidates.is_empty():
		var empty_msg := "보유한 유물이 없습니다" if _enh_mode == 1 else \
						  "사용 가능한 재료 유물이 없습니다\n(강화할 유물과 동일한 유물이 필요합니다)"
		_add_to(_content_vbox, empty_msg, 14, Color(0.55, 0.55, 0.55))
		return

	# ── 본문: 그리드(왼쪽) | 구분선 | 상세+선택버튼(오른쪽)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(body)

	# 왼쪽: 그리드 스크롤
	var grid_scroll := ScrollContainer.new()
	var grid_w := INV_COLS * INV_CELL_SIZE + (INV_COLS - 1) * INV_CELL_GAP + 8
	grid_scroll.custom_minimum_size    = Vector2(grid_w, 0)
	grid_scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(grid_scroll)

	var gm := MarginContainer.new()
	gm.add_theme_constant_override("margin_left", 4)
	gm.add_theme_constant_override("margin_top",  4)
	grid_scroll.add_child(gm)

	var grid := GridContainer.new()
	grid.columns = INV_COLS
	grid.add_theme_constant_override("h_separation", INV_CELL_GAP)
	grid.add_theme_constant_override("v_separation", INV_CELL_GAP)
	gm.add_child(grid)

	var mode_capture := _enh_mode
	for c in candidates:
		var data := c["data"] as ArtifactData
		var idx  := c["index"] as int
		var cell := _make_picker_cell(data, idx, mode_capture)
		grid.add_child(cell)
		_enh_picker_cell_btns.append(cell)

	body.add_child(VSeparator.new())

	# 오른쪽: 상세 패널 + 선택 버튼
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 6)
	body.add_child(right_vbox)

	# 상세 영역 (스크롤)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(detail_scroll)

	_enh_picker_detail_vbox = VBoxContainer.new()
	_enh_picker_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enh_picker_detail_vbox.add_theme_constant_override("separation", 6)
	detail_scroll.add_child(_enh_picker_detail_vbox)
	_add_to(_enh_picker_detail_vbox, "유물을 클릭하면\n능력치가 표시됩니다", 14, Color(0.5, 0.5, 0.5))

	# 하단 선택 버튼 (패널 고정)
	right_vbox.add_child(HSeparator.new())
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_child(btn_row)

	_enh_picker_select_btn = Button.new()
	_enh_picker_select_btn.text             = "선택"
	_enh_picker_select_btn.custom_minimum_size = Vector2(160, 44)
	_enh_picker_select_btn.focus_mode       = Control.FOCUS_NONE
	_enh_picker_select_btn.disabled         = true
	_enh_picker_select_btn.modulate         = Color(0.55, 0.55, 0.55)
	_set_font(_enh_picker_select_btn, 17)
	_enh_picker_select_btn.pressed.connect(func():
		if _enh_picker_selected != null:
			_enh_pick(_enh_picker_selected, mode_capture))
	btn_row.add_child(_enh_picker_select_btn)

## 피커 그리드 셀 생성 — 클릭 시 상세 표시만, 확정은 "선택" 버튼으로
func _make_picker_cell(data: ArtifactData, index: int, mode: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(INV_CELL_SIZE, INV_CELL_SIZE)
	btn.focus_mode          = Control.FOCUS_NONE
	btn.text                = ""
	btn.expand_icon         = true
	btn.icon                = data.texture
	# btn 을 클로저로 캡처해서 하이라이트 처리에 사용
	btn.pressed.connect(func(): _on_enh_picker_cell_pressed(btn, data))

	if data.enhance_level > 0:
		var lbl := Label.new()
		lbl.text                 = "+%d" % data.enhance_level
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.offset_right         = -4.0
		lbl.offset_bottom        = -2.0
		lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		lbl.modulate             = Color(1.0, 0.85, 0.3)
		_set_font(lbl, 12)
		btn.add_child(lbl)

	return btn

## 피커 셀 클릭 — 강조 + 상세 갱신 (확정은 "선택" 버튼)
func _on_enh_picker_cell_pressed(pressed_btn: Button, data: ArtifactData) -> void:
	# 이전 강조 해제
	for b in _enh_picker_cell_btns:
		(b as Button).modulate = Color.WHITE
	# 새 강조
	pressed_btn.modulate = Color(0.45, 1.0, 0.6)
	_enh_picker_selected = data

	# 우측 상세 패널 갱신
	_rebuild_enh_picker_detail(data)

	# 선택 버튼 활성화
	if _enh_picker_select_btn != null:
		_enh_picker_select_btn.disabled = false
		_enh_picker_select_btn.modulate = Color(0.45, 1.0, 0.6)

## 피커 우측 상세 패널 갱신
func _rebuild_enh_picker_detail(data: ArtifactData) -> void:
	if _enh_picker_detail_vbox == null: return
	for c in _enh_picker_detail_vbox.get_children():
		_enh_picker_detail_vbox.remove_child(c)
		c.queue_free()

	# 아이콘 (중앙)
	if data.texture:
		var img := TextureRect.new()
		img.texture               = data.texture
		img.custom_minimum_size   = Vector2(80, 80)
		img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_enh_picker_detail_vbox.add_child(img)

	# 이름 + 강화 레벨
	_add_to(_enh_picker_detail_vbox, data.artifact_name, 17, Color.WHITE)
	if data.enhance_level > 0:
		_add_to(_enh_picker_detail_vbox, "강화 Lv.%d" % data.enhance_level, 13, Color(1.0, 0.85, 0.3))
	else:
		_add_to(_enh_picker_detail_vbox, "미강화", 13, Color(0.6, 0.6, 0.6))

	_enh_picker_detail_vbox.add_child(HSeparator.new())

	# 스탯 보너스
	_add_to(_enh_picker_detail_vbox, "── 스탯 보너스 ──", 13, Color(1.0, 0.85, 0.5))
	var any_stat := false
	if data.bonus_max_health > 0:
		_add_to(_enh_picker_detail_vbox,
			"체력       +%d" % data.total_max_health(), 13, Color(1.0, 0.72, 0.45))
		any_stat = true
	if data.bonus_attack > 0:
		_add_to(_enh_picker_detail_vbox,
			"공격력     +%d" % data.total_attack(), 13, Color(1.0, 0.72, 0.45))
		any_stat = true
	if data.bonus_attack_speed > 0:
		_add_to(_enh_picker_detail_vbox,
			"공격속도  +%d%%" % data.total_attack_speed(), 13, Color(1.0, 0.72, 0.45))
		any_stat = true
	if data.bonus_defense > 0:
		_add_to(_enh_picker_detail_vbox,
			"방어력     +%d" % data.total_defense(), 13, Color(1.0, 0.72, 0.45))
		any_stat = true
	if data.bonus_move_speed > 0.0:
		_add_to(_enh_picker_detail_vbox,
			"이동속도  +%.1f" % data.total_move_speed(), 13, Color(1.0, 0.72, 0.45))
		any_stat = true
	if not any_stat:
		_add_to(_enh_picker_detail_vbox, "없음", 13, Color(0.55, 0.55, 0.55))

	# 패시브/설명
	var desc := data.passive_description if data.passive_description != "" else data.description
	if desc != "":
		_enh_picker_detail_vbox.add_child(HSeparator.new())
		_add_to(_enh_picker_detail_vbox, desc, 12, Color(0.8, 0.8, 0.8))

## 유물 선택 완료 처리
func _enh_pick(data: ArtifactData, mode: int) -> void:
	if mode == 1:
		_enh_target   = data
		_enh_material = null   # 대상 바뀌면 재료 초기화
	else:
		_enh_material = data
	_enh_mode = 0
	_rebuild_enhance()

## 강화 탭 내용 재빌드 (슬롯/스탯/버튼 갱신)
func _rebuild_enhance() -> void:
	_enh_artifacts = GameManager.artifacts.duplicate()
	for child in _content_vbox.get_children():
		_content_vbox.remove_child(child)
		child.queue_free()
	_enh_preview_vbox = null
	_build_enhance_content()

## 스탯 비교 뷰 갱신
func _enh_refresh_stats_view() -> void:
	if _enh_preview_vbox == null: return
	for c in _enh_preview_vbox.get_children():
		_enh_preview_vbox.remove_child(c)
		c.queue_free()

	if _enh_target == null:
		_add_to(_enh_preview_vbox, "강화할 유물과 재료를 선택하면 결과가 표시됩니다.",
			13, Color(0.5, 0.5, 0.5))
		return

	var lv := _enh_target.enhance_level

	if lv >= ArtifactData.MAX_ENHANCE_LEVEL:
		_add_to(_enh_preview_vbox, "✦ 이미 최대 강화 상태입니다 (Lv.%d)" % lv,
			14, Color(1.0, 0.85, 0.3))
		return

	# 헤더 행
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	_enh_preview_vbox.add_child(header)

	var before_lbl := Label.new()
	before_lbl.text                = "강화 전 (Lv.%d)" % lv
	before_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	before_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	before_lbl.modulate = Color(0.75, 0.75, 0.75)
	_set_font(before_lbl, 14)
	header.add_child(before_lbl)

	var arrow_lbl := Label.new()
	arrow_lbl.text    = "→"
	arrow_lbl.modulate = Color(1.0, 0.85, 0.3)
	_set_font(arrow_lbl, 16)
	header.add_child(arrow_lbl)

	var after_lbl := Label.new()
	after_lbl.text                = "강화 후 (Lv.%d)" % (lv + 1)
	after_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	after_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	after_lbl.modulate = Color(0.55, 1.0, 0.65)
	_set_font(after_lbl, 14)
	header.add_child(after_lbl)

	_enh_preview_vbox.add_child(HSeparator.new())

	# 스탯 비교 행들
	if _enh_target.bonus_max_health > 0:
		_add_stat_row("체력",
			"+%d" % _enh_target.total_max_health(),
			"+%d" % (_enh_target.total_max_health() + 1))
	if _enh_target.bonus_attack > 0:
		_add_stat_row("공격력",
			"+%d" % _enh_target.total_attack(),
			"+%d" % (_enh_target.total_attack() + 1))
	if _enh_target.bonus_attack_speed > 0:
		_add_stat_row("공격속도",
			"+%d%%" % _enh_target.total_attack_speed(),
			"+%d%%" % (_enh_target.total_attack_speed() + 1))
	if _enh_target.bonus_defense > 0:
		_add_stat_row("방어력",
			"+%d" % _enh_target.total_defense(),
			"+%d" % (_enh_target.total_defense() + 1))
	if _enh_target.bonus_move_speed > 0.0:
		_add_stat_row("이동속도",
			"+%.1f" % _enh_target.total_move_speed(),
			"+%.1f" % (_enh_target.total_move_speed() + 2.0))

	_enh_preview_vbox.add_child(HSeparator.new())

	# 영력 비용
	var cost     := (lv + 1) * ENHANCE_COST_PER_LEVEL
	var has_ess  := GameManager.echo_essence >= cost
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 8)
	_enh_preview_vbox.add_child(cost_row)

	var cost_lbl := Label.new()
	cost_lbl.text                = "영력 비용:"
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	_set_font(cost_lbl, 14)
	cost_row.add_child(cost_lbl)

	var cost_val := Label.new()
	cost_val.text    = "%d  (보유: %d)" % [cost, GameManager.echo_essence]
	cost_val.modulate = Color(0.9, 1.0, 0.55) if has_ess else Color(1.0, 0.4, 0.4)
	_set_font(cost_val, 14)
	cost_row.add_child(cost_val)

## 스탯 비교 한 행 추가 헬퍼
func _add_stat_row(stat_name: String, before: String, after: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	_enh_preview_vbox.add_child(row)

	var n_lbl := Label.new()
	n_lbl.text                = stat_name
	n_lbl.custom_minimum_size = Vector2(70, 0)
	n_lbl.modulate            = Color(0.8, 0.8, 0.8)
	_set_font(n_lbl, 13)
	row.add_child(n_lbl)

	var b_lbl := Label.new()
	b_lbl.text                = before
	b_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	b_lbl.modulate = Color(0.75, 0.75, 0.75)
	_set_font(b_lbl, 13)
	row.add_child(b_lbl)

	var arr := Label.new()
	arr.text    = "→"
	arr.modulate = Color(1.0, 0.85, 0.3)
	_set_font(arr, 13)
	row.add_child(arr)

	var a_lbl := Label.new()
	a_lbl.text                = after
	a_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	a_lbl.modulate = Color(0.55, 1.0, 0.65)
	_set_font(a_lbl, 13)
	row.add_child(a_lbl)

## 강화 실행
func _do_enhance_action() -> void:
	if _enh_target == null or _enh_material == null: return
	if _enh_target.enhance_level >= ArtifactData.MAX_ENHANCE_LEVEL: return

	var cost := (_enh_target.enhance_level + 1) * ENHANCE_COST_PER_LEVEL
	if not GameManager.spend_essence(cost):
		_rebuild_enhance()
		return

	var enhanced := _enh_target
	GameManager.artifacts.erase(_enh_material)
	enhanced.enhance_level += 1
	_enh_material = null

	_enh_mode = 0
	_rebuild_enhance()
	# 강화된 유물 다시 대상으로 유지
	for i in _enh_artifacts.size():
		if _enh_artifacts[i] == enhanced:
			_enh_target = enhanced
			_enh_refresh_stats_view()
			_rebuild_enhance()
			break

## 강화 피커를 엽니다 (mode: 1=대상, 2=재료)
func _enh_open_picker(mode: int) -> void:
	_enh_mode = mode
	_rebuild_enhance()

## 인벤토리에서의 구버전 합성 함수 — 강화 탭으로 이관됨 (호환용)
func _do_enhance_artifact(_index: int) -> void:
	_switch_tab(Tab.ENHANCE)

func _build_inv_detail(data: ArtifactData) -> void:
	for c in _inv_detail_vbox.get_children():
		_inv_detail_vbox.remove_child(c)
		c.queue_free()
	if data == null: return

	# 이미지 행
	var ih := HBoxContainer.new()
	ih.alignment = BoxContainer.ALIGNMENT_CENTER
	ih.add_theme_constant_override("separation", 20)
	_inv_detail_vbox.add_child(ih)

	_add_img_col(ih, data.texture, "유물")

	var echo_tex: Texture2D = null
	if data.echo_frames != null and data.echo_frames.has_animation(&"float") \
			and data.echo_frames.get_frame_count(&"float") > 0:
		echo_tex = data.echo_frames.get_frame_texture(&"float", 0)
	_add_img_col(ih, echo_tex, "에코")

	_inv_detail_vbox.add_child(HSeparator.new())

	_add_to(_inv_detail_vbox, data.artifact_name,                        18, Color.WHITE)
	_add_to(_inv_detail_vbox, "에코:    %s"    % data.echo_name,         14, Color(0.75, 0.9, 1.0))
	_add_to(_inv_detail_vbox, "영력/초: %.2f"  % data.essence_per_second, 13, Color(0.9, 1.0, 0.55))
	_inv_detail_vbox.add_child(HSeparator.new())

	# ── 스탯 보너스 (강화 레벨 포함)
	_add_to(_inv_detail_vbox, "── 스탯 보너스 ──", 13, Color(1.0, 0.85, 0.5))
	var any := false
	if data.bonus_max_health  > 0:
		var txt := "체력       +%d" % data.total_max_health()
		if data.enhance_level > 0: txt += "  (기본 +%d)" % data.bonus_max_health
		_add_to(_inv_detail_vbox, txt, 13, Color(1.0, 0.72, 0.45)); any = true
	if data.bonus_attack      > 0:
		var txt := "공격력     +%d" % data.total_attack()
		if data.enhance_level > 0: txt += "  (기본 +%d)" % data.bonus_attack
		_add_to(_inv_detail_vbox, txt, 13, Color(1.0, 0.72, 0.45)); any = true
	if data.bonus_attack_speed > 0:
		var txt := "공격속도  +%d%%" % data.total_attack_speed()
		if data.enhance_level > 0: txt += "  (기본 +%d%%)" % data.bonus_attack_speed
		_add_to(_inv_detail_vbox, txt, 13, Color(1.0, 0.72, 0.45)); any = true
	if data.bonus_defense     > 0:
		var txt := "방어력     +%d" % data.total_defense()
		if data.enhance_level > 0: txt += "  (기본 +%d)" % data.bonus_defense
		_add_to(_inv_detail_vbox, txt, 13, Color(1.0, 0.72, 0.45)); any = true
	if data.bonus_move_speed  > 0.0:
		var txt := "이동속도  +%.1f" % data.total_move_speed()
		if data.enhance_level > 0: txt += "  (기본 +%.1f)" % data.bonus_move_speed
		_add_to(_inv_detail_vbox, txt, 13, Color(1.0, 0.72, 0.45)); any = true
	if not any: _add_to(_inv_detail_vbox, "없음", 13, Color(0.55, 0.55, 0.55))

	var desc := data.passive_description if data.passive_description != "" else data.description
	if desc != "":
		_inv_detail_vbox.add_child(HSeparator.new())
		_add_to(_inv_detail_vbox, desc, 12, Color(0.8, 0.8, 0.8))

	# 강화 레벨 표시 (참고용)
	if data.enhance_level > 0:
		_inv_detail_vbox.add_child(HSeparator.new())
		_add_to(_inv_detail_vbox,
			"강화 레벨:  +%d  (강화 탭에서 합성 가능)" % data.enhance_level,
			13, Color(1.0, 0.85, 0.3))

# ═══════════════════════════════
#  ③ 도감 콘텐츠
# ═══════════════════════════════
func _build_doggam_content() -> void:
	_add_section_title(_content_vbox, "도감")

	# 서브탭 버튼
	var sth := HBoxContainer.new()
	sth.add_theme_constant_override("separation", 4)
	_content_vbox.add_child(sth)

	const SUB_LABELS := ["유물", "에코", "건물"]
	_dog_sub_btns.clear()
	for i in SUB_LABELS.size():
		var btn := Button.new()
		btn.text                = SUB_LABELS[i]
		btn.custom_minimum_size = Vector2(80, 32)
		btn.focus_mode          = Control.FOCUS_NONE
		var st := i as DoggamTab
		btn.pressed.connect(func(): _switch_doggam_tab(st))
		_set_font(btn, 15)
		sth.add_child(btn)
		_dog_sub_btns.append(btn)

	_content_vbox.add_child(HSeparator.new())

	# 목록 | 상세 수평 분할
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(body)

	# 왼쪽 목록 (210px) — ItemList 자체 스크롤 사용
	_dog_item_list = ItemList.new()
	_dog_item_list.custom_minimum_size = Vector2(210, 0)
	_dog_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dog_item_list.item_selected.connect(_on_doggam_item_selected)
	_set_font(_dog_item_list, 14)
	body.add_child(_dog_item_list)

	body.add_child(VSeparator.new())

	# 오른쪽 상세 (fill)
	var ds := ScrollContainer.new()
	ds.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	ds.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(ds)

	_dog_detail_vbox = VBoxContainer.new()
	_dog_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dog_detail_vbox.add_theme_constant_override("separation", 6)
	ds.add_child(_dog_detail_vbox)

	_switch_doggam_tab(_current_doggam_tab)

func _switch_doggam_tab(dtab: DoggamTab) -> void:
	_current_doggam_tab = dtab
	for i in _dog_sub_btns.size():
		_dog_sub_btns[i].modulate = \
			Color(0.45, 1.0, 0.6) if i == int(dtab) else Color(0.82, 0.82, 0.82)
	_rebuild_doggam_list()
	if _dog_detail_vbox:
		for c in _dog_detail_vbox.get_children():
			_dog_detail_vbox.remove_child(c)
			c.queue_free()
		_add_to(_dog_detail_vbox, "항목을 선택하세요", 14, Color(0.5, 0.5, 0.5))

func _rebuild_doggam_list() -> void:
	if _dog_item_list == null: return
	_dog_item_list.clear()
	_dog_index_to_path.clear()

	var paths: Array[String]
	match _current_doggam_tab:
		DoggamTab.ARTIFACT, DoggamTab.ECHO: paths = ALL_ARTIFACT_PATHS
		DoggamTab.BUILDING:                 paths = ALL_BLUEPRINT_PATHS
		_: paths = ALL_ARTIFACT_PATHS

	var idx := 1
	for path in paths:
		var disc := _dog_is_discovered(path)
		var label: String
		if disc:
			var res := load(path)
			match _current_doggam_tab:
				DoggamTab.ARTIFACT: label = "%d.  %s" % [idx, (res as ArtifactData).artifact_name]
				DoggamTab.ECHO:     label = "%d.  %s" % [idx, (res as ArtifactData).echo_name]
				DoggamTab.BUILDING: label = "%d.  %s" % [idx, (res as BuildableItem).item_name]
				_: label = "%d.  ???" % idx
		else:
			label = "%d.  ???" % idx
		_dog_item_list.add_item(label)
		_dog_index_to_path.append(path)
		idx += 1

func _dog_is_discovered(path: String) -> bool:
	match _current_doggam_tab:
		DoggamTab.ARTIFACT, DoggamTab.ECHO:
			return path in GameManager.discovered_artifact_paths
		DoggamTab.BUILDING:
			if path in ALWAYS_DISCOVERED_BLUEPRINTS: return true
			for bp: BuildableItem in GameManager.unlocked_blueprints:
				if (bp as Resource).resource_path == path: return true
			return false
	return false

func _on_doggam_item_selected(index: int) -> void:
	if _dog_detail_vbox == null: return
	if index < 0 or index >= _dog_index_to_path.size(): return
	var path := _dog_index_to_path[index]
	for c in _dog_detail_vbox.get_children():
		_dog_detail_vbox.remove_child(c)
		c.queue_free()

	if not _dog_is_discovered(path):
		_add_to(_dog_detail_vbox, "???", 26, Color.WHITE)
		_add_to(_dog_detail_vbox, "아직 발견하지 못한 항목입니다.", 14, Color(0.5, 0.5, 0.5))
		return

	var res := load(path)
	match _current_doggam_tab:
		DoggamTab.ARTIFACT:
			if res is ArtifactData: _build_dog_artifact(res as ArtifactData)
		DoggamTab.ECHO:
			if res is ArtifactData: _build_dog_echo(res as ArtifactData)
		DoggamTab.BUILDING:
			if res is BuildableItem: _build_dog_building(res as BuildableItem)

func _build_dog_artifact(data: ArtifactData) -> void:
	if data.texture:
		var img := TextureRect.new()
		img.texture               = data.texture
		img.custom_minimum_size   = Vector2(88, 88)
		img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_dog_detail_vbox.add_child(img)

	_add_to(_dog_detail_vbox, data.artifact_name, 18, Color.WHITE)
	_add_to(_dog_detail_vbox, "시대: %s" % ArtifactData.era_label(data.era), 13, Color(0.70, 0.85, 1.0))
	_dog_detail_vbox.add_child(HSeparator.new())
	var desc := data.passive_description if data.passive_description != "" else data.description
	_add_to(_dog_detail_vbox, desc, 12, Color(0.82, 0.82, 0.82))
	_dog_detail_vbox.add_child(HSeparator.new())
	_add_to(_dog_detail_vbox, "영력/초:  %.2f"       % data.essence_per_second, 13, Color(0.9,  1.0, 0.55))
	_add_to(_dog_detail_vbox, "안정도  -%.2f/초" % data.stability_decay,    12, Color(0.72, 0.72, 0.72))
	_add_to(_dog_detail_vbox, "출력    -%.2f/초" % data.output_decay,       12, Color(0.72, 0.72, 0.72))
	_add_to(_dog_detail_vbox, "활성도  -%.2f/초" % data.activity_decay,     12, Color(0.72, 0.72, 0.72))
	var hb := (data.bonus_atk_max > 0 or data.bonus_atk_spd_max > 0 or
			   data.bonus_def_max > 0 or data.bonus_move_spd_max > 0.01 or data.bonus_hp_max > 0)
	if hb:
		_dog_detail_vbox.add_child(HSeparator.new())
		_add_to(_dog_detail_vbox, "── 보너스 (최대) ──", 12, Color(1.0, 0.85, 0.5))
		if data.bonus_atk_max      > 0:    _add_to(_dog_detail_vbox, "공격력     최대 +%d"    % data.bonus_atk_max,      13, Color(1.0, 0.72, 0.45))
		if data.bonus_atk_spd_max  > 0:    _add_to(_dog_detail_vbox, "공격속도   최대 +%d%%"  % data.bonus_atk_spd_max,   13, Color(1.0, 0.72, 0.45))
		if data.bonus_hp_max       > 0:    _add_to(_dog_detail_vbox, "체력       최대 +%d"    % data.bonus_hp_max,        13, Color(1.0, 0.72, 0.45))
		if data.bonus_def_max      > 0:    _add_to(_dog_detail_vbox, "방어력     최대 +%d"    % data.bonus_def_max,       13, Color(1.0, 0.72, 0.45))
		if data.bonus_move_spd_max > 0.01: _add_to(_dog_detail_vbox, "이동속도   최대 +%.1f"  % data.bonus_move_spd_max,  13, Color(1.0, 0.72, 0.45))

func _build_dog_echo(data: ArtifactData) -> void:
	if data.echo_frames != null and data.echo_frames.has_animation(&"float") \
			and data.echo_frames.get_frame_count(&"float") > 0:
		var img := TextureRect.new()
		img.texture               = data.echo_frames.get_frame_texture(&"float", 0)
		img.custom_minimum_size   = Vector2(88, 88)
		img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_dog_detail_vbox.add_child(img)

	_add_to(_dog_detail_vbox, data.echo_name,                             20, Color.WHITE)
	if data.echo_description != "":
		_add_to(_dog_detail_vbox, data.echo_description,                  12, Color(0.82, 0.82, 0.82))
	_dog_detail_vbox.add_child(HSeparator.new())
	_add_to(_dog_detail_vbox, "깃든 유물: %s" % data.artifact_name,       13, Color(0.70, 0.85, 1.0))
	_add_to(_dog_detail_vbox, "시대:      %s" % ArtifactData.era_label(data.era), 13, Color(0.70, 0.85, 1.0))
	_add_to(_dog_detail_vbox, "에코 등급: %d" % data.echo_power,           13, Color(0.9,  1.0, 0.55))
	_add_to(_dog_detail_vbox, "배회 반경: %.0fpx" % data.wander_radius,    13, Color(0.75, 0.75, 0.75))

func _build_dog_building(item: BuildableItem) -> void:
	if item.icon:
		var img := TextureRect.new()
		img.texture               = item.icon
		img.custom_minimum_size   = Vector2(72, 72)
		img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_dog_detail_vbox.add_child(img)

	_add_to(_dog_detail_vbox, item.item_name, 18, Color.WHITE)
	if item.description != "":
		_dog_detail_vbox.add_child(HSeparator.new())
		_add_to(_dog_detail_vbox, item.description, 12, Color(0.82, 0.82, 0.82))
	_dog_detail_vbox.add_child(HSeparator.new())
	_add_to(_dog_detail_vbox, "건설 비용: %d 영력" % item.cost,            13, Color(1.0,  0.85, 0.3))
	if item.power_consumption > 0:
		_add_to(_dog_detail_vbox, "소모 전력: %d" % item.power_consumption, 13, Color(0.55, 0.85, 1.0))
	if item.power_output > 0:
		_add_to(_dog_detail_vbox, "생산 전력: +%d" % item.power_output,     13, Color(1.0,  0.95, 0.4))

# ═══════════════════════════════
#  ⑤ 스킬 콘텐츠
# ═══════════════════════════════
const AVAILABLE_SKILL_PATHS: Array[String] = [
	"res://scripts/skills/SkillDashAttack.gd",
	"res://scripts/skills/SkillProjectile.gd",
]

func _build_skill_content() -> void:
	_add_section_title(_content_vbox, "스킬 장착")

	# 현재 장착 스킬 표시
	var equipped := GameManager.equipped_skill_path
	var cur_lbl  := Label.new()
	if equipped == "":
		cur_lbl.text    = "현재 장착: 없음"
		cur_lbl.modulate = Color(0.55, 0.55, 0.55)
	else:
		var info := _get_skill_info(equipped)
		cur_lbl.text    = "현재 장착: %s" % info.get("name", "???")
		cur_lbl.modulate = Color(0.45, 1.0, 0.6)
	_set_font(cur_lbl, 15)
	_content_vbox.add_child(cur_lbl)
	_content_vbox.add_child(HSeparator.new())

	# 스킬 카드 목록
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	for path in AVAILABLE_SKILL_PATHS:
		var info := _get_skill_info(path)
		if info.is_empty():
			continue
		list.add_child(_make_skill_card(info, path, path == equipped))

## 스킬 스크립트를 임시 인스턴스로 메타데이터 읽기
func _get_skill_info(path: String) -> Dictionary:
	var script := load(path) as GDScript
	if script == null:
		return {}
	var inst: Node = script.new()
	var info := {
		"name":     str(inst.get("skill_name")) if inst.get("skill_name") != null else "???",
		"cooldown": float(inst.get("cooldown"))  if inst.get("cooldown")  != null else 0.0,
		"icon":     inst.get("icon"),
		"path":     path,
	}
	inst.free()
	return info

## 스킬 한 장의 카드 버튼 생성
func _make_skill_card(info: Dictionary, path: String, is_equipped: bool) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 80)
	btn.focus_mode          = Control.FOCUS_NONE
	if is_equipped:
		btn.modulate = Color(0.45, 1.0, 0.6)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("margin_left",  10)
	hbox.add_theme_constant_override("margin_right", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	# 아이콘
	var icon_tex: Texture2D = info.get("icon")
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	if icon_tex:
		icon_rect.texture = icon_tex
	hbox.add_child(icon_rect)

	# 이름 + 쿨다운
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	info_vbox.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text        = info.get("name", "???")
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_font(name_lbl, 17)
	info_vbox.add_child(name_lbl)

	var cd_lbl := Label.new()
	cd_lbl.text        = "쿨다운: %.1f초" % float(info.get("cooldown", 0.0))
	cd_lbl.modulate    = Color(0.72, 0.72, 0.72)
	cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_font(cd_lbl, 13)
	info_vbox.add_child(cd_lbl)

	# 장착 상태 라벨
	var eq_lbl := Label.new()
	eq_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eq_lbl.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	if is_equipped:
		eq_lbl.text    = "장착 중"
		eq_lbl.modulate = Color(0.45, 1.0, 0.6)
	else:
		eq_lbl.text    = "장착"
		eq_lbl.modulate = Color(0.75, 0.75, 0.75)
	_set_font(eq_lbl, 14)
	hbox.add_child(eq_lbl)

	btn.pressed.connect(func(): _on_skill_card_pressed(path))
	return btn

## 스킬 카드 클릭 → 장착 처리
func _on_skill_card_pressed(path: String) -> void:
	if GameManager.equipped_skill_path == path:
		# 이미 장착된 스킬 클릭 → 해제
		GameManager.equipped_skill_path = ""
		var player := get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.has_method("unequip_skill"):
			player.call("unequip_skill")
	else:
		GameManager.equipped_skill_path = path
		var script := load(path) as GDScript
		if script:
			var player := get_tree().get_first_node_in_group("player")
			if is_instance_valid(player) and player.has_method("equip_skill"):
				player.call("equip_skill", script.new())
	# UI 갱신
	_switch_tab(Tab.SKILL)

# ───────────────────────────────
#  헬퍼
# ───────────────────────────────
func _add_section_title(container: VBoxContainer, title: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	_set_font(lbl, 20)
	container.add_child(lbl)
	container.add_child(HSeparator.new())

## 이미지 + 캡션 세로 묶음을 img_hbox 에 추가
func _add_img_col(parent: HBoxContainer, tex: Texture2D, caption: String) -> void:
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(vb)

	if tex:
		var img := TextureRect.new()
		img.texture               = tex
		img.custom_minimum_size   = Vector2(80, 80)
		img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(img)

	var cap := Label.new()
	cap.text                = caption
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.modulate             = Color(0.6, 0.6, 0.6)
	_set_font(cap, 12)
	vb.add_child(cap)

func _add_to(container: VBoxContainer, text: String,
			 font_size: int, color: Color = Color.WHITE) -> void:
	var lbl := Label.new()
	lbl.text          = text
	lbl.modulate      = color
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_font(lbl, font_size)
	container.add_child(lbl)

func _set_font(node: Control, size: int) -> void:
	if _font:
		node.add_theme_font_override("font", _font)
		node.add_theme_font_size_override("font_size", size)

# ───────────────────────────────
#  입력
# ───────────────────────────────
func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
