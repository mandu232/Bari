extends CanvasLayer
class_name MenuUI
## 책 버튼 클릭 시 표시되는 메인 메뉴 팝업

signal stats_requested
signal doggam_requested

@onready var _stats_btn:  Button = $Panel/VBox/StatsButton
@onready var _doggam_btn: Button = $Panel/VBox/DoggamButton
@onready var _close_btn:  Button = $Panel/VBox/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_stats_btn.pressed.connect(_on_stats_pressed)
	_doggam_btn.pressed.connect(_on_doggam_pressed)
	_close_btn.pressed.connect(close)

func open() -> void:
	show()

func close() -> void:
	hide()

# ───────────────────────────────
#  버튼 콜백
# ───────────────────────────────
func _on_stats_pressed() -> void:
	close()
	stats_requested.emit()

func _on_doggam_pressed() -> void:
	close()
	doggam_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			close()
