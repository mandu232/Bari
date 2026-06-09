extends CanvasLayer
class_name DungeonMenuUI
## 던전 전용 메뉴 (ESC 키로 열기/닫기)
## 스탯 · 이번 런 획득 아이템 · 장착 부적 표시
## 유물 장착은 불가

const FONT := preload("res://AutoLoad/assets/Font/DungGeunMo.ttf")

enum Tab { STATS, ITEMS, TALISMAN }

const INV_COLS:      int = 4
const INV_CELL_SIZE: int = 72
const INV_CELL_GAP:  int = 4

var _current_tab:   Tab             = Tab.STATS
var _content_vbox:  VBoxContainer   = null
var _tab_btns:      Array[Button]   = []
var _is_open:       bool            = false

# 인벤토리 탭 상태
var _run_artifacts:     Array       = []
var _run_grid_btns:     Array       = []
var _run_selected_idx:  int         = -1
var _run_detail_vbox:   VBoxContainer = null

# 스탯 탭 — 시너지 패널 상태
var _syn_detail_vbox:  VBoxContainer = null
var _syn_era_btns:     Array         = []   # [{btn, era_int}]
var _syn_selected_era: int           = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 10
	_build_layout()
	hide()

# ───────────────────────────────
#  열기 / 닫기
# ───────────────────────────────
func open() -> void:
	_is_open = true
	_switch_tab(_current_tab)
	show()

func close() -> void:
	_is_open = false
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _is_open:
				close()
			else:
				open()

# ───────────────────────────────
#  레이아웃 빌드
# ───────────────────────────────
func _build_layout() -> void:
	# 반투명 오버레이 (클릭하면 닫기)
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color        = Color(0, 0, 0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			close())
	add_child(overlay)

	# 메인 패널 (960 × 590)
	var panel := Panel.new()
	panel.offset_left   = 160.0
	panel.offset_top    = 65.0
	panel.offset_right  = 1120.0
	panel.offset_bottom = 655.0
	panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	add_child(panel)

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
	_sf(title_lbl, 21)
	left_vbox.add_child(title_lbl)
	left_vbox.add_child(HSeparator.new())

	# 탭 버튼
	_tab_btns.clear()
	var tab_labels := ["스탯", "인벤토리", "장착 부적"]
	for i in tab_labels.size():
		var btn := Button.new()
		btn.text                = tab_labels[i]
		btn.custom_minimum_size = Vector2(0, 50)
		btn.focus_mode          = Control.FOCUS_NONE
		var t := i as Tab
		btn.pressed.connect(func(): _switch_tab(t))
		_sf(btn, 15)
		left_vbox.add_child(btn)
		_tab_btns.append(btn)

	root_hbox.add_child(VSeparator.new())

	# ── 오른쪽 콘텐츠
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

	for i in _tab_btns.size():
		_tab_btns[i].modulate = Color(0.45, 1.0, 0.6) if i == int(tab) else Color(0.82, 0.82, 0.82)

	for child in _content_vbox.get_children():
		_content_vbox.remove_child(child)
		child.queue_free()

	_run_grid_btns.clear()
	_run_selected_idx = -1
	_run_detail_vbox  = null
	_syn_detail_vbox  = null
	_syn_era_btns.clear()
	_syn_selected_era = -1

	match tab:
		Tab.STATS:    _build_stats()
		Tab.ITEMS:    _build_items()
		Tab.TALISMAN: _build_talisman()

# ═══════════════════════════════
#  ① 스탯  (박물관 MenuUI._build_stats_content() 와 동일한 레이아웃)
# ═══════════════════════════════
func _build_stats() -> void:
	_add_section_title(_content_vbox, "플레이어 스탯")

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_add_lbl(_content_vbox, "플레이어를 찾을 수 없습니다", 15, Color(0.6, 0.6, 0.6))
		return

	# ── 부적 보너스 합산 (부적 전용 — 박물관은 유물 equip_bonus 표시)
	var t_atk: int   = 0
	var t_def: int   = 0
	var t_hp:  int   = 0
	var t_spd: float = 0.0
	for td: TalismanData in TalismanManager.equipped:
		t_atk += td.bonus_atk
		t_def += td.bonus_def
		t_hp  += td.bonus_hp
		t_spd += td.bonus_speed

	# 장착 유물 보너스도 합산 (박물관과 동일하게 (+N) 표시)
	var equipped_art: ArtifactData = GameManager.equipped_artifact

	const ICONS := {
		"atk":     "res://AutoLoad/assets/Stats/icon_atk.png",
		"atk_spd": "res://AutoLoad/assets/Stats/icon_atk_spd.png",
		"def":     "res://AutoLoad/assets/Stats/icon_def.png",
		"spd":     "res://AutoLoad/assets/Stats/icon_move_spd.png",
		"hp":      "res://AutoLoad/assets/Stats/icon_hp.png",
		"mana":    "res://AutoLoad/assets/Stats/icon_mana.png",
	}

	# ── 상단 HBox: 스탯 목록(왼쪽) | 장착 유물 패널(오른쪽)  — 박물관과 동일
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	_content_vbox.add_child(top_hbox)

	var stat_vbox := VBoxContainer.new()
	stat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_vbox.add_theme_constant_override("separation", 8)
	top_hbox.add_child(stat_vbox)

	# [icon_key, label, value_str, talisman_bonus_key]
	# 박물관과 동일한 순서: atk, atk_spd, hp, mana, def, spd
	var rows := [
		["atk",     "공격력",   "%d"        % player.get("attack_damage"),                         "atk"],
		["atk_spd", "공격속도", "%d%%"      % player.get("attack_speed"),                          ""],
		["hp",      "체력",     "%d / %d"   % [player.get("health"), player.get("max_health")],   "hp"],
		["mana",    "마나",     "%.0f / %d" % [player.get("mana"),   player.get("max_mana")],     ""],
		["def",     "방어력",   "%d"        % player.get("defense"),                               "def"],
		["spd",     "이동속도", "%.1f"      % player.get("move_speed"),                            "spd"],
	]

	for row in rows:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		stat_vbox.add_child(hbox)

		# 아이콘 28×28 (박물관과 동일)
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(28, 28)
		tex.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var icon_path: String = ICONS.get(row[0], "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			tex.texture = load(icon_path)
		hbox.add_child(tex)

		# 스탯 이름 (width 90, font 18 — 박물관과 동일)
		var name_lbl := Label.new()
		name_lbl.text                = row[1]
		name_lbl.custom_minimum_size = Vector2(90, 0)
		_sf(name_lbl, 18)
		hbox.add_child(name_lbl)

		# 수치 (연두색, font 18)
		var val_lbl := Label.new()
		val_lbl.text     = row[2]
		val_lbl.modulate = Color(0.85, 1.0, 0.65)
		_sf(val_lbl, 18)
		hbox.add_child(val_lbl)

		# 부적 보너스 (+N) — 금색 font 14 (박물관 유물 보너스와 동일 포맷)
		var bonus_key: String = row[3]
		if bonus_key != "":
			var bonus_txt := ""
			match bonus_key:
				"atk": if t_atk > 0: bonus_txt = "(+%d)"   % t_atk
				"hp":  if t_hp  > 0: bonus_txt = "(+%d)"   % t_hp
				"def": if t_def > 0: bonus_txt = "(+%d)"   % t_def
				"spd": if t_spd > 0: bonus_txt = "(+%.1f)" % t_spd
			if bonus_txt != "":
				var bon_lbl := Label.new()
				bon_lbl.text     = bonus_txt
				bon_lbl.modulate = Color(1.0, 0.82, 0.3)
				_sf(bon_lbl, 14)
				hbox.add_child(bon_lbl)

	# ── 오른쪽: 장착 유물 패널 (읽기 전용 — 박물관과 동일 레이아웃, 클릭 없음)
	top_hbox.add_child(VSeparator.new())

	var equip_panel := PanelContainer.new()
	equip_panel.custom_minimum_size = Vector2(185, 0)
	top_hbox.add_child(equip_panel)

	var equip_vbox := VBoxContainer.new()
	equip_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	equip_vbox.add_theme_constant_override("separation", 5)
	equip_panel.add_child(equip_vbox)

	var panel_hdr := Label.new()
	panel_hdr.text                 = "유물 장착"
	panel_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_hdr.modulate             = Color(0.85, 0.85, 0.85)
	_sf(panel_hdr, 14)
	equip_vbox.add_child(panel_hdr)
	equip_vbox.add_child(HSeparator.new())

	if equipped_art != null and GameManager.equipped_skill_path != "":
		if equipped_art.texture:
			var img := TextureRect.new()
			img.texture               = equipped_art.texture
			img.custom_minimum_size   = Vector2(56, 56)
			img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			equip_vbox.add_child(img)

		var art_lbl := Label.new()
		art_lbl.text                 = equipped_art.artifact_name
		art_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sf(art_lbl, 14)
		equip_vbox.add_child(art_lbl)

		var info := _get_skill_info(GameManager.equipped_skill_path)
		var skill_lbl := Label.new()
		skill_lbl.text                 = "스킬: %s" % info.get("name", "???")
		skill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_lbl.modulate             = Color(0.6, 0.9, 1.0)
		_sf(skill_lbl, 13)
		equip_vbox.add_child(skill_lbl)

		var has_bonus := (equipped_art.equip_bonus_atk > 0 or equipped_art.equip_bonus_atk_spd > 0
			or equipped_art.equip_bonus_def > 0 or equipped_art.equip_bonus_move_spd > 0.0
			or equipped_art.equip_bonus_hp > 0)
		if has_bonus:
			equip_vbox.add_child(HSeparator.new())
			_add_lbl(equip_vbox, "장착 보너스", 12, Color(1.0, 0.9, 0.4))
			if equipped_art.equip_bonus_atk      > 0:   _add_lbl(equip_vbox, "공격력    +%d"   % equipped_art.total_equip_atk(),       13, Color(1.0, 0.85, 0.3))
			if equipped_art.equip_bonus_atk_spd  > 0:   _add_lbl(equip_vbox, "공격속도  +%d%%" % equipped_art.total_equip_atk_spd(),   13, Color(1.0, 0.85, 0.3))
			if equipped_art.equip_bonus_hp       > 0:   _add_lbl(equip_vbox, "체력      +%d"   % equipped_art.total_equip_hp(),        13, Color(1.0, 0.85, 0.3))
			if equipped_art.equip_bonus_def      > 0:   _add_lbl(equip_vbox, "방어력    +%d"   % equipped_art.total_equip_def(),       13, Color(1.0, 0.85, 0.3))
			if equipped_art.equip_bonus_move_spd > 0.0: _add_lbl(equip_vbox, "이동속도  +%.1f" % equipped_art.total_equip_move_spd(),  13, Color(1.0, 0.85, 0.3))
	else:
		var empty_lbl := Label.new()
		empty_lbl.text                 = "장착 없음"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate             = Color(0.4, 0.4, 0.4)
		_sf(empty_lbl, 14)
		equip_vbox.add_child(empty_lbl)

	# ── 시대 시너지 섹션 (박물관과 동일한 레이아웃, 읽기 전용)
	_content_vbox.add_child(HSeparator.new())
	_add_section_title(_content_vbox, "시대 시너지")
	_build_synergy_section()

## 시너지 섹션: 왼쪽 버튼 목록 | 오른쪽 상세 패널  (박물관과 동일)
func _build_synergy_section() -> void:
	const ERA_ORDER: Array[int] = [1, 3, 5, 8]

	var syn_hbox := HBoxContainer.new()
	syn_hbox.add_theme_constant_override("separation", 0)
	syn_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(syn_hbox)

	# 왼쪽 버튼 목록
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(128, 0)
	left_vbox.add_theme_constant_override("separation", 5)
	syn_hbox.add_child(left_vbox)

	syn_hbox.add_child(VSeparator.new())

	# 오른쪽 상세 스크롤
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
	_add_lbl(_syn_detail_vbox, "좌측 시너지를 눌러\n효과를 확인하세요", 13, Color(0.38, 0.38, 0.38))

	# 버튼 생성 (박물관과 동일)
	_syn_era_btns.clear()
	for era_int in ERA_ORDER:
		var tiers: Array = GameManager.ERA_SYNERGY_TIERS.get(era_int, [])
		if tiers.is_empty(): continue

		var current_count := GameManager.get_exhibited_era_count(era_int)
		var is_active: bool = not (GameManager.active_synergies.get(era_int, {}) as Dictionary).is_empty()

		var show_denom: int = (tiers[-1] as Dictionary)["count"] as int
		for tier in tiers:
			if current_count < (tier["count"] as int):
				show_denom = tier["count"] as int
				break

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.focus_mode          = Control.FOCUS_NONE
		btn.modulate = Color(0.95, 0.82, 0.32) if is_active else Color(0.40, 0.40, 0.40)

		var bv := VBoxContainer.new()
		bv.alignment    = BoxContainer.ALIGNMENT_CENTER
		bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bv)

		var nl := Label.new()
		nl.text                = ArtifactData.era_label(era_int as ArtifactData.Era)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		_sf(nl, 15)
		bv.add_child(nl)

		var cl := Label.new()
		cl.text                = "%d / %d" % [current_count, show_denom]
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		cl.modulate = Color(1.0, 0.95, 0.6) if is_active else Color(0.48, 0.48, 0.48)
		_sf(cl, 13)
		bv.add_child(cl)

		var era_capture := era_int
		btn.pressed.connect(func(): _on_syn_btn_pressed(era_capture))
		left_vbox.add_child(btn)
		_syn_era_btns.append({"btn": btn, "era": era_int})

## 시너지 버튼 클릭 처리 (박물관과 동일)
func _on_syn_btn_pressed(era_int: int) -> void:
	_syn_selected_era = era_int
	for entry in _syn_era_btns:
		var b   := entry["btn"] as Button
		var e   := entry["era"] as int
		var act: bool = not (GameManager.active_synergies.get(e, {}) as Dictionary).is_empty()
		if e == era_int:
			b.modulate = Color(1.0, 1.0, 1.0)
		elif act:
			b.modulate = Color(0.95, 0.82, 0.32)
		else:
			b.modulate = Color(0.40, 0.40, 0.40)
	_rebuild_syn_detail(era_int)

## 우측 상세 패널 갱신 (박물관과 동일)
func _rebuild_syn_detail(era_int: int) -> void:
	if _syn_detail_vbox == null: return
	for c in _syn_detail_vbox.get_children():
		_syn_detail_vbox.remove_child(c)
		c.queue_free()

	var tiers:         Array  = GameManager.ERA_SYNERGY_TIERS.get(era_int, [])
	var current_count: int    = GameManager.get_exhibited_era_count(era_int)
	var era_name:      String = ArtifactData.era_label(era_int as ArtifactData.Era)

	var hdr := Label.new()
	hdr.text     = "%s 시대   (%d개 전시 중)" % [era_name, current_count]
	hdr.modulate = Color(0.85, 0.85, 0.85)
	_sf(hdr, 15)
	_syn_detail_vbox.add_child(hdr)
	_syn_detail_vbox.add_child(HSeparator.new())

	for i in tiers.size():
		var tier      := tiers[i] as Dictionary
		var tc        := tier["count"] as int
		var tier_act  := current_count >= tc
		var is_last   := i == tiers.size() - 1

		var title_hbox := HBoxContainer.new()
		title_hbox.add_theme_constant_override("separation", 8)
		_syn_detail_vbox.add_child(title_hbox)

		var icon_lbl := Label.new()
		icon_lbl.text    = "✦" if tier_act else "○"
		icon_lbl.modulate = Color(1.0, 0.85, 0.3) if tier_act else Color(0.35, 0.35, 0.35)
		_sf(icon_lbl, 16)
		title_hbox.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text                = "%s" % tier["name"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.modulate            = Color(1.0, 0.92, 0.45) if tier_act else Color(0.38, 0.38, 0.38)
		_sf(name_lbl, 15)
		title_hbox.add_child(name_lbl)

		var req_lbl := Label.new()
		req_lbl.text     = "%d개" % tc
		req_lbl.modulate = Color(0.7, 0.7, 0.7) if tier_act else Color(0.35, 0.35, 0.35)
		_sf(req_lbl, 13)
		title_hbox.add_child(req_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text          = "    " + tier["desc"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.modulate      = Color(1.0, 0.72, 0.45) if tier_act else Color(0.30, 0.30, 0.30)
		_sf(desc_lbl, 13)
		_syn_detail_vbox.add_child(desc_lbl)

		var status_lbl := Label.new()
		if tier_act:
			status_lbl.text     = "    ✓ 달성"
			status_lbl.modulate = Color(0.45, 1.0, 0.6)
		else:
			status_lbl.text     = "    전시 %d개 더 필요" % (tc - current_count)
			status_lbl.modulate = Color(0.42, 0.42, 0.42)
		_sf(status_lbl, 12)
		_syn_detail_vbox.add_child(status_lbl)

		if not is_last:
			_syn_detail_vbox.add_child(HSeparator.new())

# ── 스킬 이름 조회 헬퍼 (박물관 MenuUI._get_skill_info() 와 동일)
func _get_skill_info(path: String) -> Dictionary:
	var script := load(path) as GDScript
	if script == null:
		return {}
	var inst: Node = script.new()
	var info := {
		"name":      str(inst.get("skill_name"))  if inst.get("skill_name")  != null else "???",
		"cooldown":  float(inst.get("cooldown"))  if inst.get("cooldown")    != null else 0.0,
		"mana_cost": int(inst.get("mana_cost"))   if inst.get("mana_cost")   != null else 0,
	}
	inst.free()
	return info

# ═══════════════════════════════
#  ② 이번 런 아이템
# ═══════════════════════════════
func _build_items() -> void:
	_run_artifacts = GameManager.run_artifacts.duplicate()

	_add_title("인벤토리")

	var cnt_lbl := Label.new()
	cnt_lbl.text    = "획득 유물: %d개" % _run_artifacts.size()
	cnt_lbl.modulate = Color(0.72, 0.72, 0.72)
	_sf(cnt_lbl, 14)
	_content_vbox.add_child(cnt_lbl)

	_content_vbox.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_vbox.add_child(body)

	# 왼쪽 그리드
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

	if _run_artifacts.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text    = "아직 유물을 획득하지\n않았습니다"
		empty_lbl.modulate = Color(0.5, 0.5, 0.5)
		_sf(empty_lbl, 14)
		grid.add_child(empty_lbl)
	else:
		_run_grid_btns.clear()
		for i in _run_artifacts.size():
			var data := _run_artifacts[i] as ArtifactData
			if data == null: continue
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(INV_CELL_SIZE, INV_CELL_SIZE)
			btn.focus_mode          = Control.FOCUS_NONE
			btn.expand_icon         = true
			btn.icon                = data.texture
			btn.pressed.connect(func(): _on_run_item_pressed(i))
			grid.add_child(btn)
			_run_grid_btns.append(btn)

	body.add_child(VSeparator.new())

	# 오른쪽 상세
	var ds := ScrollContainer.new()
	ds.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	ds.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(ds)

	_run_detail_vbox = VBoxContainer.new()
	_run_detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_detail_vbox.add_theme_constant_override("separation", 6)
	ds.add_child(_run_detail_vbox)

	_add_lbl(_run_detail_vbox, "유물을 선택하세요", 14, Color(0.5, 0.5, 0.5))

func _on_run_item_pressed(index: int) -> void:
	if _run_detail_vbox == null: return
	if index < 0 or index >= _run_artifacts.size(): return

	if _run_selected_idx >= 0 and _run_selected_idx < _run_grid_btns.size():
		_run_grid_btns[_run_selected_idx].modulate = Color.WHITE
	_run_selected_idx = index
	_run_grid_btns[index].modulate = Color(0.45, 1.0, 0.6)

	for c in _run_detail_vbox.get_children():
		_run_detail_vbox.remove_child(c)
		c.queue_free()

	var data := _run_artifacts[index] as ArtifactData
	if data == null: return

	if data.texture:
		var img := TextureRect.new()
		img.texture               = data.texture
		img.custom_minimum_size   = Vector2(80, 80)
		img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_run_detail_vbox.add_child(img)

	_add_lbl(_run_detail_vbox, data.artifact_name, 17, Color.WHITE)

	var desc := data.passive_description if data.passive_description != "" else data.description
	if desc != "":
		var d := Label.new()
		d.text          = desc
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.modulate      = Color(0.75, 0.75, 0.75)
		_sf(d, 12)
		_run_detail_vbox.add_child(d)

	_run_detail_vbox.add_child(HSeparator.new())

	# 전시/장착 보너스 간략 표시
	var any_stat := (data.bonus_max_health > 0 or data.bonus_attack > 0 or
			data.bonus_attack_speed > 0 or data.bonus_defense > 0 or data.bonus_move_speed > 0.0)
	if any_stat:
		_add_lbl(_run_detail_vbox, "전시 보너스", 13, Color(1.0, 0.72, 0.45))
		if data.bonus_max_health > 0:   _add_lbl(_run_detail_vbox, "체력      +%d"   % data.total_max_health(),  13, Color(1.0, 0.72, 0.45))
		if data.bonus_attack > 0:       _add_lbl(_run_detail_vbox, "공격력    +%d"   % data.total_attack(),       13, Color(1.0, 0.72, 0.45))
		if data.bonus_defense > 0:      _add_lbl(_run_detail_vbox, "방어력    +%d"   % data.total_defense(),      13, Color(1.0, 0.72, 0.45))
		if data.bonus_move_speed > 0.0: _add_lbl(_run_detail_vbox, "이동속도  +%.1f" % data.total_move_speed(),   13, Color(1.0, 0.72, 0.45))

# ═══════════════════════════════
#  ③ 장착 부적
# ═══════════════════════════════
func _build_talisman() -> void:
	_add_title("장착 부적")

	var equipped := TalismanManager.equipped

	if equipped.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text    = "장착된 부적이 없습니다"
		empty_lbl.modulate = Color(0.5, 0.5, 0.5)
		_sf(empty_lbl, 15)
		_content_vbox.add_child(empty_lbl)
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(list_vbox)

	for i in TalismanManager.MAX_SLOTS:
		var slot_panel := PanelContainer.new()
		var sp_style := StyleBoxFlat.new()
		sp_style.set_corner_radius_all(6)

		if i < equipped.size():
			var td := equipped[i] as TalismanData
			sp_style.bg_color    = td.card_color.darkened(0.60)
			sp_style.border_color = td.card_color
			sp_style.set_border_width_all(2)
			slot_panel.add_theme_stylebox_override("panel", sp_style)
			list_vbox.add_child(slot_panel)

			var inner_margin := MarginContainer.new()
			inner_margin.add_theme_constant_override("margin_left",   14)
			inner_margin.add_theme_constant_override("margin_right",  14)
			inner_margin.add_theme_constant_override("margin_top",    10)
			inner_margin.add_theme_constant_override("margin_bottom", 10)
			slot_panel.add_child(inner_margin)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 16)
			inner_margin.add_child(row)

			# 아이콘
			if td.icon != null:
				var img := TextureRect.new()
				img.texture               = td.icon
				img.custom_minimum_size   = Vector2(72, 72)
				img.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				img.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
				row.add_child(img)

			# 텍스트
			var txt_vbox := VBoxContainer.new()
			txt_vbox.add_theme_constant_override("separation", 5)
			txt_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(txt_vbox)

			var name_hbox := HBoxContainer.new()
			name_hbox.add_theme_constant_override("separation", 8)
			txt_vbox.add_child(name_hbox)

			var slot_tag := Label.new()
			slot_tag.text    = "슬롯 %d" % (i + 1)
			slot_tag.modulate = Color(0.55, 0.55, 0.55)
			_sf(slot_tag, 12)
			name_hbox.add_child(slot_tag)

			var name_lbl := Label.new()
			name_lbl.text    = td.talisman_name
			name_lbl.modulate = td.card_color.lightened(0.35)
			_sf(name_lbl, 18)
			name_hbox.add_child(name_lbl)

			# 방어막 상태 표시
			if td.effect == TalismanData.Effect.SHIELD:
				var shield_lbl := Label.new()
				shield_lbl.text    = "방어막 " + ("활성" if TalismanManager.is_shield_active() else "소진")
				shield_lbl.modulate = Color(1.0, 1.0, 0.4) if TalismanManager.is_shield_active() else Color(0.4, 0.4, 0.4)
				_sf(shield_lbl, 12)
				name_hbox.add_child(shield_lbl)

			if td.description != "":
				var desc_lbl := Label.new()
				desc_lbl.text          = td.description
				desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				desc_lbl.modulate      = Color(0.75, 0.75, 0.75)
				_sf(desc_lbl, 12)
				txt_vbox.add_child(desc_lbl)

			var stat_str := td.get_stat_summary()
			if stat_str.strip_edges() != "":
				var stat_lbl := Label.new()
				stat_lbl.text     = stat_str
				stat_lbl.modulate = Color(1.0, 0.85, 0.3)
				_sf(stat_lbl, 13)
				txt_vbox.add_child(stat_lbl)
		else:
			# 빈 슬롯
			sp_style.bg_color    = Color(0.12, 0.10, 0.08, 0.6)
			sp_style.border_color = Color(0.35, 0.30, 0.18, 0.5)
			sp_style.set_border_width_all(1)
			slot_panel.add_theme_stylebox_override("panel", sp_style)
			list_vbox.add_child(slot_panel)

			var empty_margin := MarginContainer.new()
			empty_margin.add_theme_constant_override("margin_left",   14)
			empty_margin.add_theme_constant_override("margin_right",  14)
			empty_margin.add_theme_constant_override("margin_top",     8)
			empty_margin.add_theme_constant_override("margin_bottom",  8)
			slot_panel.add_child(empty_margin)

			var empty_lbl := Label.new()
			empty_lbl.text    = "슬롯 %d  — 비어있음" % (i + 1)
			empty_lbl.modulate = Color(0.35, 0.35, 0.35)
			_sf(empty_lbl, 14)
			empty_margin.add_child(empty_lbl)

# ───────────────────────────────
#  헬퍼
# ───────────────────────────────
func _add_title(text: String) -> void:
	_add_section_title(_content_vbox, text)

## 박물관 MenuUI._add_section_title() 와 동일
func _add_section_title(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text     = text
	lbl.modulate = Color(0.9, 0.9, 0.9)
	_sf(lbl, 20)
	parent.add_child(lbl)
	parent.add_child(HSeparator.new())

func _add_lbl(parent: Control, text: String, size: int, col: Color) -> void:
	var lbl := Label.new()
	lbl.text          = text
	lbl.modulate      = col
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sf(lbl, size)
	parent.add_child(lbl)

func _sf(node: Control, size: int) -> void:
	node.add_theme_font_override("font",           FONT)
	node.add_theme_font_size_override("font_size", size)
