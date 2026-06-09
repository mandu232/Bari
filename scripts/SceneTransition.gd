extends CanvasLayer
## 씬 전환 연출 — 화이트아웃 + 줌인 (AutoLoad)
## 박물관 → 던전 입장 시 "그림 속으로 빨려 들어가는" 효과

var _white_rect: ColorRect = null
var _is_busy:    bool      = false

func _ready() -> void:
	layer        = 200                       # 모든 UI 위에 렌더링
	process_mode = Node.PROCESS_MODE_ALWAYS  # 씬 전환 중에도 유지

	_white_rect               = ColorRect.new()
	_white_rect.color         = Color.WHITE
	_white_rect.modulate.a    = 0.0
	_white_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_white_rect.anchor_right  = 1.0
	_white_rect.anchor_bottom = 1.0
	add_child(_white_rect)

# ─────────────────────────────────────────────
#  박물관 → 던전: 빨려 들어가기 연출
#  scene_callable: 씬 전환을 수행하는 Callable
#  (예: func(): GameManager.start_dungeon_run())
# ─────────────────────────────────────────────
func enter_dungeon(scene_callable: Callable) -> void:
	if _is_busy:
		return
	_is_busy = true

	var cam := get_tree().get_first_node_in_group("camera") as Camera2D

	# ① 줌인 + 화이트아웃 동시 진행
	var tw := create_tween().set_parallel(true)

	if is_instance_valid(cam):
		# 카메라 zoom 3.0 → 9.0 (가속하며 빨려드는 느낌)
		tw.tween_property(cam, "zoom", Vector2(9.0, 9.0), 0.65) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# 0.25초 딜레이 후 화이트 페이드인 (줌이 어느정도 된 후 터지는 느낌)
	tw.tween_property(_white_rect, "modulate:a", 1.0, 0.40) \
		.set_delay(0.25) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	await tw.finished

	# ② 씬 전환 실행
	scene_callable.call()

	# ③ 새 씬 로드 대기 (2프레임) 후 화이트 페이드아웃
	await get_tree().process_frame
	await get_tree().process_frame

	var tw2 := create_tween()
	tw2.tween_property(_white_rect, "modulate:a", 0.0, 0.50) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw2.finished

	_is_busy = false
