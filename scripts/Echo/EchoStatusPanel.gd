extends Control
class_name EchoStatusPanel
## Echo의 욕구 수치를 보여주는 화면 우측 고정 패널
## Echo._open_status_panel() 이 CanvasLayer 위에 생성합니다.

# ───────────────────────────────
#  레이아웃 상수
# ───────────────────────────────
const PANEL_W:   float = 240.0  # 패널 가로
const ROW_H:     float = 32.0   # 수치 한 행의 높이
const BAR_H:     float = 10.0   # 진행 바 높이
const PAD:       float = 14.0   # 안쪽 여백
const LABEL_W:   float = 52.0   # 수치 이름 영역 폭
const NUM_W:     float = 30.0   # 오른쪽 수치 숫자 영역 폭
const MARGIN:    float = 20.0   # 화면 우측 여백
const HEADER_H:  float = 36.0   # 헤더 영역 높이
const SEP_H:     float = 8.0    # 구분선 아래 여백
const FOOTER_H:  float = 14.0   # 하단 기분·닫기 힌트 영역 높이

# ───────────────────────────────
#  STATE
# ───────────────────────────────
var _echo: Echo = null
var _font: Font = null

# ───────────────────────────────
#  SETUP
# ───────────────────────────────
func setup(echo: Echo) -> void:
	_echo = echo
	_font = load("res://AutoLoad/assets/Font/DungGeunMo.ttf") as Font

	if echo.needs:
		echo.needs.mood_changed.connect(_on_needs_changed.unbind(1))
		for need: EchoNeed in echo.needs.get_all_needs():
			need.value_changed.connect(_on_needs_changed.unbind(3))

	_reposition()
	queue_redraw()

func _on_needs_changed() -> void:
	_reposition()
	queue_redraw()

## 패널 높이 계산 후 화면 우측 중앙에 배치
func _reposition() -> void:
	if _echo == null or _echo.needs == null:
		return
	var needs_count := _echo.needs.get_all_needs().size()
	var panel_h := PAD + HEADER_H + SEP_H + ROW_H * needs_count + FOOTER_H + PAD
	var vp      := get_viewport().get_visible_rect().size
	position    = Vector2(vp.x - PANEL_W - MARGIN, (vp.y - panel_h) * 0.5)
	size        = Vector2(PANEL_W, panel_h)

# ───────────────────────────────
#  DRAW  (Control 좌표 — (0,0) 이 패널 좌상단)
# ───────────────────────────────
func _draw() -> void:
	if _echo == null or _echo.needs == null or _font == null:
		return

	var needs_list: Array = _echo.needs.get_all_needs()
	var panel_h := PAD + HEADER_H + SEP_H + ROW_H * needs_list.size() + FOOTER_H + PAD

	var ox: float = 0.0
	var oy: float = 0.0

	_draw_panel_bg(ox, oy, PANEL_W, panel_h)

	var cy := oy + PAD

	# ── 헤더: 기분 심볼 + Echo 이름
	var echo_name  := _echo.artifact_data.echo_name if _echo.artifact_data else "???"
	var header_str := _mood_symbol(_echo.needs.mood) + "  " + echo_name
	draw_string(_font, Vector2(ox + PAD, cy + 16.0),
				header_str, HORIZONTAL_ALIGNMENT_LEFT,
				PANEL_W - PAD * 2, 17, Color(0.88, 0.93, 1.0))
	cy += HEADER_H

	# ── 구분선
	draw_line(Vector2(ox + PAD, cy),
			  Vector2(ox + PANEL_W - PAD, cy),
			  Color(0.35, 0.55, 1.0, 0.35), 1.5)
	cy += SEP_H

	# ── 수치 행
	for need: EchoNeed in needs_list:
		_draw_need_row(need, ox + PAD, cy)
		cy += ROW_H

	# ── 하단: 현재 기분 + [F] 닫기
	var mood_str   := "기분: " + _mood_label(_echo.needs.mood)
	var mood_color := _mood_color(_echo.needs.mood)
	draw_string(_font, Vector2(ox + PAD, cy + 14.0),
				mood_str, HORIZONTAL_ALIGNMENT_LEFT,
				PANEL_W * 0.60, 14, mood_color)
	draw_string(_font, Vector2(ox + PANEL_W - PAD, cy + 14.0),
				"[F] 닫기", HORIZONTAL_ALIGNMENT_RIGHT,
				70.0, 13, Color(0.50, 0.55, 0.65))

# ─── 배경 & 테두리 ──────────────────────────────────────
func _draw_panel_bg(x: float, y: float, w: float, h: float) -> void:
	draw_rect(Rect2(x + 3, y + 3, w, h),
			  Color(0.0, 0.0, 0.0, 0.35), true)
	draw_rect(Rect2(x, y, w, h),
			  Color(0.07, 0.08, 0.16, 0.93), true)
	draw_rect(Rect2(x, y, w, h),
			  Color(0.35, 0.55, 1.0, 0.50), false, 1.5)
	draw_line(Vector2(x + 1, y + 1), Vector2(x + w - 1, y + 1),
			  Color(0.55, 0.75, 1.0, 0.35), 1.5)

# ─── 수치 한 행 ──────────────────────────────────────────
func _draw_need_row(need: EchoNeed, x: float, y: float) -> void:
	# 이름 레이블
	draw_string(_font, Vector2(x, y + 12.0),
				need.label, HORIZONTAL_ALIGNMENT_LEFT,
				LABEL_W, 14, Color(0.72, 0.76, 0.90))

	# 진행 바 영역
	var bx := x + LABEL_W + 4.0
	var bw := PANEL_W - PAD * 2 - LABEL_W - 4.0 - NUM_W

	# 바 배경
	draw_rect(Rect2(bx, y + 6.0, bw, BAR_H),
			  Color(0.14, 0.14, 0.22, 0.90), true)
	# 바 채움
	var fill := need.get_ratio()
	if fill > 0.001:
		draw_rect(Rect2(bx, y + 6.0, bw * fill, BAR_H),
				  _tier_color(need.get_tier()), true)
	# 바 테두리
	draw_rect(Rect2(bx, y + 6.0, bw, BAR_H),
			  Color(0.25, 0.30, 0.45, 0.60), false, 1.0)

	# 수치 숫자
	draw_string(_font, Vector2(bx + bw + 5.0, y + 12.0),
				"%d" % int(need.value), HORIZONTAL_ALIGNMENT_LEFT,
				NUM_W, 14, Color(0.60, 0.65, 0.78))

# ─── 색상·텍스트 헬퍼 ────────────────────────────────────
func _mood_symbol(mood: StringName) -> String:
	match mood:
		&"평온": return "◆"
		&"우울": return "▼"
		&"한계": return "✕"
		_:       return "●"   # 보통

func _mood_label(mood: StringName) -> String:
	match mood:
		&"평온": return "평온"
		&"우울": return "우울"
		&"한계": return "한계"
		_:       return "보통"

func _mood_color(mood: StringName) -> Color:
	match mood:
		&"평온": return Color(0.35, 0.92, 0.55)   # 초록
		&"우울": return Color(0.96, 0.66, 0.20)   # 주황
		&"한계": return Color(0.96, 0.30, 0.30)   # 빨강
		_:       return Color(0.60, 0.82, 0.96)   # 파랑 (보통)

func _tier_color(tier: StringName) -> Color:
	match tier:
		&"평온", &"넘침", &"활발": return Color(0.28, 0.85, 0.48)   # 초록
		&"보통", &"느긋":          return Color(0.48, 0.72, 0.96)   # 파랑
		&"우울", &"부족", &"처짐": return Color(0.96, 0.65, 0.18)   # 주황
		&"한계", &"멈춤", &"고요": return Color(0.96, 0.28, 0.28)   # 빨강
		_:                         return Color(0.48, 0.72, 0.96)
