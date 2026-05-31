extends CanvasLayer
class_name MuseumHQUI
## 박물관 본관 관리 UI — 박물관 강화·플레이어 강화 독립 업그레이드

signal closed

# ─── 공통 뷰 ──────────────────────────────────────────────────────────
@onready var _upgrade_view: VBoxContainer = $Root/Panel/Content/UpgradeView
@onready var _max_view:     VBoxContainer = $Root/Panel/Content/MaxView

# ─── 박물관 강화 패널 ─────────────────────────────────────────────────
@onready var _museum_lv_label:    Label  = $Root/Panel/Content/UpgradeView/Cols/MuseumPanel/MuseumVBox/MuseumLvLabel
@onready var _essence_cur:        Label  = $Root/Panel/Content/UpgradeView/Cols/MuseumPanel/MuseumVBox/EssenceRow/EssenceCur
@onready var _essence_arrow:      Label  = $Root/Panel/Content/UpgradeView/Cols/MuseumPanel/MuseumVBox/EssenceRow/EssenceArrow
@onready var _essence_next:       Label  = $Root/Panel/Content/UpgradeView/Cols/MuseumPanel/MuseumVBox/EssenceRow/EssenceNext
@onready var _slots_cur:          Label  = $Root/Panel/Content/UpgradeView/Cols/MuseumPanel/MuseumVBox/SlotsRow/SlotsCur
@onready var _slots_arrow:        Label  = $Root/Panel/Content/UpgradeView/Cols/MuseumPanel/MuseumVBox/SlotsRow/SlotsArrow
@onready var _slots_next:         Label  = $Root/Panel/Content/UpgradeView/Cols/MuseumPanel/MuseumVBox/SlotsRow/SlotsNext
@onready var _museum_cost_label:  Label  = $Root/Panel/Content/UpgradeView/Cols/MuseumPanel/MuseumVBox/MuseumCostLabel
@onready var _museum_max_label:   Label  = $Root/Panel/Content/UpgradeView/Cols/MuseumPanel/MuseumVBox/MuseumMaxLabel
@onready var _museum_upgrade_btn: Button = $Root/Panel/Content/UpgradeView/Cols/MuseumPanel/MuseumVBox/MuseumUpgradeBtn

# ─── 플레이어 강화 패널 ───────────────────────────────────────────────
@onready var _player_lv_label:    Label        = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/PlayerLvLabel
@onready var _health_cur:         Label        = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/HealthRow/HealthCur
@onready var _health_arrow:       Label        = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/HealthRow/HealthArrow
@onready var _health_next:        Label        = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/HealthRow/HealthNext
@onready var _damage_row:         HBoxContainer = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/DamageRow
@onready var _damage_cur:         Label        = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/DamageRow/DamageCur
@onready var _damage_arrow:       Label        = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/DamageRow/DamageArrow
@onready var _damage_next:        Label        = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/DamageRow/DamageNext
@onready var _speed_row:          HBoxContainer = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/SpeedRow
@onready var _speed_cur:          Label        = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/SpeedRow/SpeedCur
@onready var _speed_arrow:        Label        = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/SpeedRow/SpeedArrow
@onready var _speed_next:         Label        = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/SpeedRow/SpeedNext
@onready var _player_cost_label:  Label  = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/PlayerCostLabel
@onready var _player_max_label:   Label  = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/PlayerMaxLabel
@onready var _player_upgrade_btn: Button = $Root/Panel/Content/UpgradeView/Cols/PlayerPanel/PlayerVBox/PlayerUpgradeBtn

# ─── 닫기·최대 레벨 버튼 ─────────────────────────────────────────────
@onready var _close_btn1: Button = $Root/Panel/Content/UpgradeView/CloseButtons/CloseBtn1
@onready var _close_btn2: Button = $Root/Panel/Content/MaxView/MaxButtons/CloseBtn2

# ─── 최대 레벨 뷰 수치 ────────────────────────────────────────────────
@onready var _max_essence_val: Label        = $Root/Panel/Content/MaxView/MaxStatsCols/MaxMuseumVBox/MaxEssenceRow/MaxEssenceVal
@onready var _max_slots_val:   Label        = $Root/Panel/Content/MaxView/MaxStatsCols/MaxMuseumVBox/MaxSlotsRow/MaxSlotsVal
@onready var _max_health_val:  Label        = $Root/Panel/Content/MaxView/MaxStatsCols/MaxPlayerVBox/MaxHealthRow/MaxHealthVal
@onready var _max_damage_row:  HBoxContainer = $Root/Panel/Content/MaxView/MaxStatsCols/MaxPlayerVBox/MaxDamageRow
@onready var _max_damage_val:  Label        = $Root/Panel/Content/MaxView/MaxStatsCols/MaxPlayerVBox/MaxDamageRow/MaxDamageVal
@onready var _max_speed_row:   HBoxContainer = $Root/Panel/Content/MaxView/MaxStatsCols/MaxPlayerVBox/MaxSpeedRow
@onready var _max_speed_val:   Label        = $Root/Panel/Content/MaxView/MaxStatsCols/MaxPlayerVBox/MaxSpeedRow/MaxSpeedVal

# ─── 런타임 ──────────────────────────────────────────────────────────
var _hq: MuseumHQ = null

# ─── 초기화 ──────────────────────────────────────────────────────────
func _ready() -> void:
	_museum_upgrade_btn.pressed.connect(_on_upgrade_museum_pressed)
	_player_upgrade_btn.pressed.connect(_on_upgrade_player_pressed)
	_close_btn1.pressed.connect(_on_close_pressed)
	_close_btn2.pressed.connect(_on_close_pressed)
	_style_button(_museum_upgrade_btn, true)
	_style_button(_player_upgrade_btn, true)
	_style_button(_close_btn1, false)
	_style_button(_close_btn2, false)

func setup(hq: MuseumHQ) -> void:
	_hq     = hq
	visible = false

func open() -> void:
	_refresh()
	visible = true

# ─── 갱신 진입점 ─────────────────────────────────────────────────────
func _refresh() -> void:
	var m_lv   := GameManager.hq_museum_level
	var p_lv   := GameManager.hq_player_level
	var m_done := m_lv >= _hq.MAX_MUSEUM_LEVEL
	var p_done := p_lv >= _hq.MAX_PLAYER_LEVEL

	_upgrade_view.visible = not (m_done and p_done)
	_max_view.visible     = m_done and p_done

	if not (m_done and p_done):
		_refresh_museum_panel(m_lv, m_done)
		_refresh_player_panel(p_lv, p_done)
	else:
		_refresh_max_view(m_lv, p_lv)

# ─── 박물관 패널 갱신 ─────────────────────────────────────────────────
func _refresh_museum_panel(lv: int, is_done: bool) -> void:
	_museum_lv_label.text = "Lv.%d / %d" % [lv, _hq.MAX_MUSEUM_LEVEL]

	if is_done:
		# 최대 레벨: 현재 수치를 금색으로 표시, 화살표·다음값 숨김
		_essence_cur.text = "×%.1f" % _hq.MUSEUM_LEVEL_MULT[lv]
		_essence_cur.add_theme_color_override("font_color", Color(1.0, 0.92, 0.50))
		_essence_arrow.visible = false
		_essence_next.visible  = false
		_slots_cur.text = "%d개" % GameManager.max_dynamic_artifact_slots
		_slots_cur.add_theme_color_override("font_color", Color(1.0, 0.92, 0.50))
		_slots_arrow.visible       = false
		_slots_next.visible        = false
		_museum_cost_label.visible  = false
		_museum_upgrade_btn.visible = false
		_museum_max_label.visible   = true
	else:
		var nxt := lv + 1
		# 현재→다음 수치
		_essence_cur.text = "×%.1f" % _hq.MUSEUM_LEVEL_MULT[lv]
		_essence_cur.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
		_essence_arrow.visible = true
		_essence_next.visible  = true
		_essence_next.text     = "×%.1f" % _hq.MUSEUM_LEVEL_MULT[nxt]
		_slots_cur.text = "%d개" % GameManager.max_dynamic_artifact_slots
		_slots_cur.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
		_slots_arrow.visible = true
		_slots_next.visible  = true
		_slots_next.text     = "%d개" % (GameManager.max_dynamic_artifact_slots + _hq.MUSEUM_LEVEL_SLOTS[nxt])
		_museum_max_label.visible = false
		# 비용·버튼
		var cost   := _hq.MUSEUM_UPGRADE_COST[nxt]
		var afford := GameManager.echo_essence >= cost
		_museum_cost_label.visible = true
		_museum_cost_label.text    = "비용: 영력 %d" % cost
		_museum_cost_label.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.30) if afford else Color(1.0, 0.35, 0.35))
		_museum_upgrade_btn.visible  = true
		_museum_upgrade_btn.text     = "Lv.%d 업그레이드" % nxt if afford else "영력 부족"
		_museum_upgrade_btn.disabled = not afford

# ─── 플레이어 패널 갱신 ───────────────────────────────────────────────
func _refresh_player_panel(lv: int, is_done: bool) -> void:
	_player_lv_label.text = "Lv.%d / %d" % [lv, _hq.MAX_PLAYER_LEVEL]

	var total_dmg := _sum_i(_hq.PLAYER_LEVEL_DAMAGE, lv)
	var total_spd := _sum_f(_hq.PLAYER_LEVEL_SPEED, lv)

	if is_done:
		# 최대 레벨: 금색 현재값만
		_health_cur.text = "+%d" % _sum_i(_hq.PLAYER_LEVEL_HEALTH, lv)
		_health_cur.add_theme_color_override("font_color", Color(1.0, 0.92, 0.50))
		_health_arrow.visible = false
		_health_next.visible  = false

		_damage_row.visible = total_dmg > 0
		_damage_cur.text    = "+%d" % total_dmg
		_damage_cur.add_theme_color_override("font_color", Color(1.0, 0.92, 0.50))
		_damage_arrow.visible = false
		_damage_next.visible  = false

		_speed_row.visible = total_spd > 0.0
		_speed_cur.text    = "+%.1f" % total_spd
		_speed_cur.add_theme_color_override("font_color", Color(1.0, 0.92, 0.50))
		_speed_arrow.visible = false
		_speed_next.visible  = false

		_player_cost_label.visible  = false
		_player_upgrade_btn.visible = false
		_player_max_label.visible   = true
	else:
		var nxt       := lv + 1
		var show_dmg  := total_dmg > 0 or _hq.PLAYER_LEVEL_DAMAGE[nxt] > 0
		var show_spd  := total_spd > 0.0 or _hq.PLAYER_LEVEL_SPEED[nxt] > 0.0

		_health_cur.text = "+%d" % _sum_i(_hq.PLAYER_LEVEL_HEALTH, lv)
		_health_cur.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
		_health_arrow.visible = true
		_health_next.visible  = true
		_health_next.text     = "+%d" % (_sum_i(_hq.PLAYER_LEVEL_HEALTH, lv) + _hq.PLAYER_LEVEL_HEALTH[nxt])

		_damage_row.visible = show_dmg
		_damage_cur.text    = "+%d" % total_dmg
		_damage_cur.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
		_damage_arrow.visible = true
		_damage_next.visible  = true
		_damage_next.text     = "+%d" % (total_dmg + _hq.PLAYER_LEVEL_DAMAGE[nxt])

		_speed_row.visible = show_spd
		_speed_cur.text    = "+%.1f" % total_spd
		_speed_cur.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
		_speed_arrow.visible = true
		_speed_next.visible  = true
		_speed_next.text     = "+%.1f" % (total_spd + _hq.PLAYER_LEVEL_SPEED[nxt])

		_player_max_label.visible = false
		# 비용·버튼
		var cost   := _hq.PLAYER_UPGRADE_COST[nxt]
		var afford := GameManager.echo_essence >= cost
		_player_cost_label.visible = true
		_player_cost_label.text    = "비용: 영력 %d" % cost
		_player_cost_label.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.30) if afford else Color(1.0, 0.35, 0.35))
		_player_upgrade_btn.visible  = true
		_player_upgrade_btn.text     = "Lv.%d 업그레이드" % nxt if afford else "영력 부족"
		_player_upgrade_btn.disabled = not afford

# ─── 최대 레벨 뷰 갱신 ───────────────────────────────────────────────
func _refresh_max_view(m_lv: int, p_lv: int) -> void:
	_max_essence_val.text = "×%.1f" % _hq.MUSEUM_LEVEL_MULT[m_lv]
	_max_slots_val.text   = "%d개"  % GameManager.max_dynamic_artifact_slots
	_max_health_val.text  = "+%d"   % _sum_i(_hq.PLAYER_LEVEL_HEALTH, p_lv)

	var has_dmg := _sum_i(_hq.PLAYER_LEVEL_DAMAGE, p_lv) > 0
	_max_damage_row.visible = has_dmg
	_max_damage_val.text    = "+%d" % _sum_i(_hq.PLAYER_LEVEL_DAMAGE, p_lv)

	var has_spd := _sum_f(_hq.PLAYER_LEVEL_SPEED, p_lv) > 0.0
	_max_speed_row.visible = has_spd
	_max_speed_val.text    = "+%.1f" % _sum_f(_hq.PLAYER_LEVEL_SPEED, p_lv)

# ─── 버튼 스타일 ─────────────────────────────────────────────────────
func _style_button(btn: Button, is_primary: bool) -> void:
	var accent := Color(0.85, 0.65, 0.20) if is_primary else Color(0.55, 0.50, 0.40)
	var normal := StyleBoxFlat.new()
	normal.bg_color              = Color(0.16, 0.12, 0.05, 0.92) if is_primary else Color(0.12, 0.11, 0.09, 0.90)
	normal.border_color          = accent.darkened(0.1)
	normal.border_width_left     = 1
	normal.border_width_right    = 1
	normal.border_width_top      = 1
	normal.border_width_bottom   = 1
	normal.content_margin_left   = 16
	normal.content_margin_right  = 16
	normal.content_margin_top    = 8
	normal.content_margin_bottom = 8
	var hover      := normal.duplicate() as StyleBoxFlat
	hover.bg_color    = Color(0.28, 0.20, 0.07, 0.96) if is_primary else Color(0.22, 0.20, 0.16, 0.96)
	hover.border_color = accent
	var pressed_st := normal.duplicate() as StyleBoxFlat
	pressed_st.bg_color = Color(0.10, 0.08, 0.03, 0.96)
	btn.add_theme_stylebox_override("normal",   normal)
	btn.add_theme_stylebox_override("hover",    hover)
	btn.add_theme_stylebox_override("pressed",  pressed_st)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.add_theme_color_override("font_color",
		Color(1.0, 0.92, 0.50) if is_primary else Color(0.78, 0.76, 0.72))
	btn.add_theme_color_override("font_color_hover",
		Color(1.0, 0.98, 0.70) if is_primary else Color(0.92, 0.90, 0.86))
	btn.add_theme_color_override("font_color_pressed",  Color(0.75, 0.65, 0.28))
	btn.add_theme_color_override("font_color_disabled", Color(0.45, 0.42, 0.35))

# ─── 콜백 ────────────────────────────────────────────────────────────
func _on_upgrade_museum_pressed() -> void:
	_hq.try_upgrade_museum()
	_refresh()

func _on_upgrade_player_pressed() -> void:
	_hq.try_upgrade_player()
	_refresh()

func _on_close_pressed() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

# ─── 통계 합산 헬퍼 ──────────────────────────────────────────────────
func _sum_i(arr: Array, lv: int) -> int:
	var t := 0
	for i in range(1, lv + 1): t += arr[i]
	return t

func _sum_f(arr: Array, lv: int) -> float:
	var t := 0.0
	for i in range(1, lv + 1): t += arr[i]
	return t
